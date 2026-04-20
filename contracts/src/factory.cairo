use crate::interfaces::ifactory::IFactory;
use crate::types::TokenConfig;
use starknet::{ClassHash, ContractAddress, get_caller_address};

#[starknet::contract]
pub mod FactoryContract {
    use super::{ClassHash, ContractAddress, IFactory, TokenConfig, get_caller_address};
    use core::panic_with_felt252;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };

    #[storage]
    pub struct Storage {
        token_class_hash: ClassHash,
        token_count: u256,
        all_tokens: Map<u256, ContractAddress>,
        creator_tokens: Map<(ContractAddress, u256), ContractAddress>,
        creator_token_count: Map<ContractAddress, u256>,
        is_factory_token: Map<ContractAddress, bool>,
        factory_owner: ContractAddress,
        pending_factory_owner: ContractAddress,
        salt_counter: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenCreated: TokenCreated,
        TokenClassHashUpdated: TokenClassHashUpdated,
        FactoryOwnershipTransferStarted: FactoryOwnershipTransferStarted,
        FactoryOwnershipTransferred: FactoryOwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenCreated {
        #[key]
        pub creator: ContractAddress,
        #[key]
        pub token: ContractAddress,
        pub name: ByteArray,
        pub symbol: ByteArray,
        pub privacy_enabled: bool,
        pub token_index: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenClassHashUpdated {
        pub old_class_hash: ClassHash,
        pub new_class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FactoryOwnershipTransferStarted {
        pub previous_owner: ContractAddress,
        pub new_pending_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FactoryOwnershipTransferred {
        pub previous_owner: ContractAddress,
        pub new_owner: ContractAddress,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, token_class_hash: ClassHash, owner: ContractAddress) {
        let zero_class_hash: ClassHash = 0.try_into().unwrap();
        let zero_addr: ContractAddress = 0.try_into().unwrap();
        assert(token_class_hash != zero_class_hash, 'CLASS_HASH_ZERO');
        assert(owner != zero_addr, 'OWNER_ZERO');
        self.token_class_hash.write(token_class_hash);
        self.factory_owner.write(owner);
        self.pending_factory_owner.write(zero_addr);
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_owner(self: @ContractState) {
            assert(get_caller_address() == self.factory_owner.read(), 'ONLY_OWNER');
        }

        fn _u256_to_felt_index(self: @ContractState, value: u256) -> felt252 {
            assert(value.high == 0_u128, 'INDEX_TOO_LARGE');
            value.low.into()
        }

    }

    #[abi(embed_v0)]
    impl FactoryImpl of IFactory<ContractState> {
        fn create_token(ref self: ContractState, config: TokenConfig) -> ContractAddress {
            let creator = get_caller_address();
            let class_hash = self.token_class_hash.read();

            let salt_counter = self.salt_counter.read();
            let new_salt_counter = salt_counter + 1;
            self.salt_counter.write(new_salt_counter);
            let salt: felt252 = new_salt_counter.low.into();

            let mut calldata = array![];
            config.serialize(ref calldata);

            let deploy_result = starknet::syscalls::deploy_syscall(
                class_hash, salt, calldata.span(), false
            );

            let token_address = match deploy_result {
                Result::Ok((address, _)) => address,
                Result::Err(_) => {
                    panic_with_felt252('DEPLOY_FAILED');
                },
            };

            let current_token_count = self.token_count.read();
            self.all_tokens.write(current_token_count, token_address);
            self.token_count.write(current_token_count + 1);

            let creator_count = self.creator_token_count.read(creator);
            self.creator_tokens.write((creator, creator_count), token_address);
            self.creator_token_count.write(creator, creator_count + 1);

            self.is_factory_token.write(token_address, true);

            self.emit(
                Event::TokenCreated(
                    TokenCreated {
                        creator,
                        token: token_address,
                        name: config.name,
                        symbol: config.symbol,
                        privacy_enabled: config.privacy_enabled,
                        token_index: current_token_count,
                    }
                )
            );

            token_address
        }

        fn get_token_class_hash(self: @ContractState) -> ClassHash {
            self.token_class_hash.read()
        }

        fn get_factory_owner(self: @ContractState) -> ContractAddress {
            self.factory_owner.read()
        }

        fn get_pending_factory_owner(self: @ContractState) -> ContractAddress {
            self.pending_factory_owner.read()
        }

        fn get_tokens_by_creator(self: @ContractState, creator: ContractAddress) -> Array<ContractAddress> {
            let mut result = array![];
            let creator_count = self.creator_token_count.read(creator);
            let creator_count_felt = self._u256_to_felt_index(creator_count);

            let mut i: felt252 = 0;
            loop {
                if i == creator_count_felt {
                    break;
                }

                let idx: u256 = i.into();
                result.append(self.creator_tokens.read((creator, idx)));
                i += 1;
            };

            result
        }

        fn get_tokens_by_creator_paginated(
            self: @ContractState, creator: ContractAddress, offset: u256, limit: u256
        ) -> Array<ContractAddress> {
            let mut result = array![];
            let creator_count = self.creator_token_count.read(creator);
            assert(creator_count.high == 0_u128, 'INDEX_TOO_LARGE');
            assert(offset.high == 0_u128, 'INDEX_TOO_LARGE');
            assert(limit.high == 0_u128, 'INDEX_TOO_LARGE');
            let count = creator_count.low;
            let start = offset.low;
            let requested = limit.low;

            if start >= count || requested == 0_u128 {
                return result;
            }

            let mut end = start + requested;
            if end > count {
                end = count;
            }

            let mut i: u128 = start;
            loop {
                if i == end {
                    break;
                }
                let idx: u256 = u256 { low: i, high: 0_u128 };
                result.append(self.creator_tokens.read((creator, idx)));
                i += 1;
            };

            result
        }

        fn get_all_tokens(self: @ContractState) -> Array<ContractAddress> {
            let mut result = array![];
            let count = self.token_count.read();
            let count_felt = self._u256_to_felt_index(count);

            let mut i: felt252 = 0;
            loop {
                if i == count_felt {
                    break;
                }

                let idx: u256 = i.into();
                result.append(self.all_tokens.read(idx));
                i += 1;
            };

            result
        }

        fn get_all_tokens_paginated(self: @ContractState, offset: u256, limit: u256) -> Array<ContractAddress> {
            let mut result = array![];
            let count = self.token_count.read();
            assert(count.high == 0_u128, 'INDEX_TOO_LARGE');
            assert(offset.high == 0_u128, 'INDEX_TOO_LARGE');
            assert(limit.high == 0_u128, 'INDEX_TOO_LARGE');
            let total = count.low;
            let start = offset.low;
            let requested = limit.low;

            if start >= total || requested == 0_u128 {
                return result;
            }

            let mut end = start + requested;
            if end > total {
                end = total;
            }

            let mut i: u128 = start;
            loop {
                if i == end {
                    break;
                }
                let idx: u256 = u256 { low: i, high: 0_u128 };
                result.append(self.all_tokens.read(idx));
                i += 1;
            };

            result
        }

        fn get_token_count(self: @ContractState) -> u256 {
            self.token_count.read()
        }

        fn is_token_from_factory(self: @ContractState, token: ContractAddress) -> bool {
            self.is_factory_token.read(token)
        }

        fn transfer_factory_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self._assert_owner();
            let zero_addr: ContractAddress = 0.try_into().unwrap();
            assert(new_owner != zero_addr, 'NEW_OWNER_ZERO');
            assert(new_owner != self.factory_owner.read(), 'ALREADY_OWNER');
            let previous_owner = self.factory_owner.read();
            self.pending_factory_owner.write(new_owner);
            self.emit(
                Event::FactoryOwnershipTransferStarted(
                    FactoryOwnershipTransferStarted {
                        previous_owner, new_pending_owner: new_owner
                    }
                )
            );
        }

        fn accept_factory_ownership(ref self: ContractState) {
            let caller = get_caller_address();
            assert(caller == self.pending_factory_owner.read(), 'NOT_PENDING_OWNER');
            let previous_owner = self.factory_owner.read();
            self.factory_owner.write(caller);
            self.pending_factory_owner.write(0.try_into().unwrap());
            self.emit(
                Event::FactoryOwnershipTransferred(
                    FactoryOwnershipTransferred { previous_owner, new_owner: caller }
                )
            );
        }
    }

    #[external(v0)]
    fn set_token_class_hash(ref self: ContractState, new_class_hash: ClassHash) {
        self._assert_owner();
        let zero_class_hash: ClassHash = 0.try_into().unwrap();
        assert(new_class_hash != zero_class_hash, 'CLASS_HASH_ZERO');
        let old_class_hash = self.token_class_hash.read();
        self.token_class_hash.write(new_class_hash);
        self.emit(
            Event::TokenClassHashUpdated(TokenClassHashUpdated { old_class_hash, new_class_hash })
        );
    }
}
