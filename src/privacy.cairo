use crate::interfaces::iprivacy::IPrivacy;
use crate::interfaces::itoken::{ITokenDispatcher, ITokenDispatcherTrait};
use crate::interfaces::iverifier::{IVerifierDispatcher, IVerifierDispatcherTrait};
use starknet::{ContractAddress, get_caller_address};

#[starknet::contract]
pub mod PrivacyContract {
    use super::{
        ContractAddress, IPrivacy, ITokenDispatcher, ITokenDispatcherTrait, IVerifierDispatcher,
        IVerifierDispatcherTrait, get_caller_address
    };
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };

    #[storage]
    pub struct Storage {
        token_address: ContractAddress,
        auditor: ContractAddress,
        verifier_address: ContractAddress,
        merkle_root: felt252,
        domain_separator: felt252,
        shielded_commitments: Map<felt252, bool>,
        spent_commitments: Map<felt252, bool>,
        nullifiers: Map<felt252, bool>,
        viewing_keys: Map<ContractAddress, felt252>,
        total_shielded: u256,
        pool_active: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Shielded: Shielded,
        Unshielded: Unshielded,
        PrivateTransfer: PrivateTransfer,
        PrivacyModuleSet: PrivacyModuleSet,
        MerkleRootUpdated: MerkleRootUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Shielded {
        pub commitment: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unshielded {
        pub commitment: felt252,
        pub nullifier: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivateTransfer {
        pub new_commitment: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyModuleSet {
        pub module: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MerkleRootUpdated {
        pub old_root: felt252,
        pub new_root: felt252,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState,
        token_address: ContractAddress,
        auditor: ContractAddress,
        verifier_address: ContractAddress,
        merkle_root: felt252,
        domain_separator: felt252,
    ) {
        let zero_addr: ContractAddress = 0.try_into().unwrap();
        assert(token_address != zero_addr, 'TOKEN_ZERO');
        assert(auditor != zero_addr, 'AUDITOR_ZERO');
        assert(verifier_address != zero_addr, 'VERIFIER_ZERO');
        self.token_address.write(token_address);
        self.auditor.write(auditor);
        self.verifier_address.write(verifier_address);
        self.merkle_root.write(merkle_root);
        self.domain_separator.write(domain_separator);
        self.pool_active.write(true);
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_only_auditor(self: @ContractState) {
            assert(get_caller_address() == self.auditor.read(), 'AUDITOR_ONLY');
        }

        fn _verify_proof(
            self: @ContractState, proof: Array<felt252>, public_inputs: Array<felt252>
        ) -> bool {
            let verifier = IVerifierDispatcher { contract_address: self.verifier_address.read() };
            verifier.verify(proof, public_inputs)
        }
    }

    #[abi(embed_v0)]
    impl PrivacyImpl of IPrivacy<ContractState> {
        fn shield(
            ref self: ContractState, amount: u256, commitment: felt252, encrypted_viewing_key: felt252
        ) {
            assert(self.pool_active.read(), 'POOL_NOT_ACTIVE');
            assert(amount > 0, 'ZERO_AMOUNT');
            assert(!self.shielded_commitments.read(commitment), 'COMMITMENT_EXISTS');
            let caller = get_caller_address();
            let token = ITokenDispatcher { contract_address: self.token_address.read() };
            token.burn_for_privacy(caller, amount);
            self.shielded_commitments.write(commitment, true);
            self.viewing_keys.write(caller, encrypted_viewing_key);
            self.total_shielded.write(self.total_shielded.read() + amount);
            self.emit(Event::Shielded(Shielded { commitment }));
        }

        fn unshield(
            ref self: ContractState,
            commitment: felt252,
            nullifier: felt252,
            proof: Array<felt252>,
            recipient: ContractAddress,
            amount: u256,
        ) {
            assert(self.pool_active.read(), 'POOL_NOT_ACTIVE');
            assert(amount > 0, 'ZERO_AMOUNT');
            assert(self.shielded_commitments.read(commitment), 'COMMITMENT_UNKNOWN');
            assert(!self.spent_commitments.read(commitment), 'COMMITMENT_SPENT');
            assert(!self.nullifiers.read(nullifier), 'NULLIFIER_SPENT');

            let mut public_inputs = array![];
            public_inputs.append(commitment);
            let recipient_felt: felt252 = recipient.into();
            public_inputs.append(nullifier);
            public_inputs.append(self.merkle_root.read());
            public_inputs.append(recipient_felt);
            public_inputs.append(amount.low.into());
            public_inputs.append(amount.high.into());
            public_inputs.append(self.domain_separator.read());
            assert(self._verify_proof(proof, public_inputs), 'INVALID_PROOF');

            let shielded_total = self.total_shielded.read();
            assert(shielded_total >= amount, 'INSUFFICIENT_SHIELDED');
            self.spent_commitments.write(commitment, true);
            self.nullifiers.write(nullifier, true);
            self.total_shielded.write(shielded_total - amount);
            let token = ITokenDispatcher { contract_address: self.token_address.read() };
            token.mint_from_privacy(recipient, amount);
            self.emit(Event::Unshielded(Unshielded { commitment, nullifier }));
        }

        fn private_transfer(
            ref self: ContractState,
            nullifier: felt252,
            new_commitment: felt252,
            proof: Array<felt252>,
        ) {
            assert(self.pool_active.read(), 'POOL_NOT_ACTIVE');
            assert(!self.nullifiers.read(nullifier), 'NULLIFIER_SPENT');
            assert(!self.shielded_commitments.read(new_commitment), 'COMMITMENT_EXISTS');

            let mut public_inputs = array![];
            public_inputs.append(nullifier);
            public_inputs.append(new_commitment);
            public_inputs.append(self.merkle_root.read());
            public_inputs.append(self.domain_separator.read());
            assert(self._verify_proof(proof, public_inputs), 'INVALID_PROOF');

            self.nullifiers.write(nullifier, true);
            self.shielded_commitments.write(new_commitment, true);
            self.emit(Event::PrivateTransfer(PrivateTransfer { new_commitment }));
        }

        fn register_viewing_key(ref self: ContractState, encrypted_key: felt252) {
            let caller = get_caller_address();
            self.viewing_keys.write(caller, encrypted_key);
        }

        fn get_viewing_key(self: @ContractState, user: ContractAddress) -> felt252 {
            self._assert_only_auditor();
            self.viewing_keys.read(user)
        }

        fn get_total_shielded(self: @ContractState) -> u256 {
            self.total_shielded.read()
        }

        fn is_nullifier_spent(self: @ContractState, nullifier: felt252) -> bool {
            self.nullifiers.read(nullifier)
        }
    }

    #[external(v0)]
    fn set_merkle_root(ref self: ContractState, new_root: felt252) {
        self._assert_only_auditor();
        let old_root = self.merkle_root.read();
        self.merkle_root.write(new_root);
        self.emit(Event::MerkleRootUpdated(MerkleRootUpdated { old_root, new_root }));
    }

    #[external(v0)]
    fn get_merkle_root(self: @ContractState) -> felt252 {
        self.merkle_root.read()
    }

    #[external(v0)]
    fn get_domain_separator(self: @ContractState) -> felt252 {
        self.domain_separator.read()
    }
}
