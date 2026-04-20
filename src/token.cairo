use crate::interfaces::itoken::IToken;
use crate::types::{BurnPermission, MintMode, TokenConfig, WhitelistMode};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

#[starknet::contract]
pub mod TokenContract {
    use super::{BurnPermission, ContractAddress, IToken, MintMode, TokenConfig, WhitelistMode};
    use super::{get_block_timestamp, get_caller_address};
    use core::panic_with_felt252;
    const ISRC5_ID: felt252 = 0x01ffc9a7;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };

    #[storage]
    pub struct Storage {
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,

        owner: ContractAddress,
        pending_owner: ContractAddress,
        minted_total: u256,
        max_mint_cap: u256,
        mint_mode: MintMode,
        mint_once_used: bool,
        burn_permission: BurnPermission,
        whitelist_mode: WhitelistMode,
        whitelisted: Map<ContractAddress, bool>,
        supported_interfaces: Map<felt252, bool>,
        website: ByteArray,
        twitter: ByteArray,
        instagram: ByteArray,
        image_uri: ByteArray,
        urn: ByteArray,
        privacy_enabled: bool,
        privacy_module: ContractAddress,
        pending_privacy_module: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Minted: Minted,
        Burned: Burned,
        PrivacyBurned: PrivacyBurned,
        WhitelistUpdated: WhitelistUpdated,
        WhitelistModeChanged: WhitelistModeChanged,
        MetadataUpdated: MetadataUpdated,
        Transfer: Transfer,
        Approval: Approval,
        OwnershipTransferStarted: OwnershipTransferStarted,
        OwnershipTransferred: OwnershipTransferred,
        PrivacyModuleSet: PrivacyModuleSet,
        PrivacyModuleTransferStarted: PrivacyModuleTransferStarted,
        PrivacyModuleTransferred: PrivacyModuleTransferred,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Minted {
        pub recipient: ContractAddress,
        pub amount: u256,
        pub minted_total: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Burned {
        pub from: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyBurned {
        pub initiator: ContractAddress,
        pub account: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WhitelistUpdated {
        pub addr: ContractAddress,
        pub allowed: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WhitelistModeChanged {
        pub new_mode: WhitelistMode,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdated {
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnershipTransferStarted {
        pub previous_owner: ContractAddress,
        pub new_pending_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnershipTransferred {
        pub previous_owner: ContractAddress,
        pub new_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyModuleSet {
        pub module: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyModuleTransferStarted {
        pub previous_module: ContractAddress,
        pub new_pending_module: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PrivacyModuleTransferred {
        pub previous_module: ContractAddress,
        pub new_module: ContractAddress,
    }

    #[constructor]
    pub fn constructor(ref self: ContractState, config: TokenConfig) {
        let zero_addr = self._zero_address();
        assert(config.owner != zero_addr, 'OWNER_ZERO');
        self._register_standard_interfaces();
        self.name.write(config.name);
        self.symbol.write(config.symbol);
        self.decimals.write(config.decimals);
        self.owner.write(config.owner);
        self.pending_owner.write(zero_addr);
        self.max_mint_cap.write(config.max_mint_cap);
        self.mint_mode.write(config.mint_mode);
        self.burn_permission.write(config.burn_permission);
        self.whitelist_mode.write(config.whitelist_mode);
        self.privacy_enabled.write(config.privacy_enabled);
        self.pending_privacy_module.write(zero_addr);

        self.website.write(config.website);
        self.twitter.write(config.twitter);
        self.instagram.write(config.instagram);
        self.image_uri.write(config.image_uri);
        self.urn.write(config.urn);

        if config.mint_mode == MintMode::UnlimitedWithCap {
            assert(config.initial_supply <= config.max_mint_cap, 'INITIAL_SUPPLY_GT_CAP');
        }

        if config.initial_supply > 0 {
            self._mint(config.owner, config.initial_supply);
            self.minted_total.write(config.initial_supply);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _register_interface(ref self: ContractState, interface_id: felt252) {
            self.supported_interfaces.write(interface_id, true);
        }

        fn _register_standard_interfaces(ref self: ContractState) {
            // Register wallet-detected interfaces.
            self._register_interface(ISRC5_ID);
        }

        fn _assert_only_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), 'ONLY_OWNER');
        }

        fn _zero_address(self: @ContractState) -> ContractAddress {
            0.try_into().unwrap()
        }

        fn _check_whitelist(
            self: @ContractState, sender: ContractAddress, recipient: ContractAddress
        ) {
            let mode = self.whitelist_mode.read();
            let owner = self.owner.read();

            if sender == owner || recipient == owner {
                return;
            }

            match mode {
                WhitelistMode::Disabled => {},
                WhitelistMode::StrictBoth => {
                    assert(self.whitelisted.read(sender), 'SENDER_NOT_WL');
                    assert(self.whitelisted.read(recipient), 'RECIPIENT_NOT_WL');
                },
                WhitelistMode::SenderOnly => {
                    if self.whitelisted.read(sender) {
                        assert(self.whitelisted.read(recipient), 'RECIPIENT_NOT_WL');
                    }
                },
            }
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current = self.allowances.read((owner, spender));
            assert(current >= amount, 'INSUFFICIENT_ALLOWANCE');
            self.allowances.write((owner, spender), current - amount);
        }

        fn _transfer(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let zero_addr = self._zero_address();
            assert(from != zero_addr, 'FROM_ZERO');
            assert(to != zero_addr, 'TO_ZERO');

            let from_balance = self.balances.read(from);
            assert(from_balance >= amount, 'INSUFFICIENT_BAL');
            self.balances.write(from, from_balance - amount);

            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);

            self.emit(Event::Transfer(Transfer { from, to, value: amount }));
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let zero_addr = self._zero_address();
            assert(recipient != zero_addr, 'MINT_TO_ZERO');

            let current_supply = self.total_supply.read();
            self.total_supply.write(current_supply + amount);

            let current_balance = self.balances.read(recipient);
            self.balances.write(recipient, current_balance + amount);

            self.emit(
                Event::Transfer(Transfer { from: zero_addr, to: recipient, value: amount })
            );
        }

        fn _burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            let zero_addr = self._zero_address();
            assert(from != zero_addr, 'BURN_FROM_ZERO');

            let balance = self.balances.read(from);
            assert(balance >= amount, 'INSUFFICIENT_BAL');
            self.balances.write(from, balance - amount);

            let supply = self.total_supply.read();
            self.total_supply.write(supply - amount);

            self.emit(Event::Transfer(Transfer { from, to: zero_addr, value: amount }));
            self.emit(Event::Burned(Burned { from, amount }));
        }
    }

    #[abi(embed_v0)]
    impl TokenImpl of IToken<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._check_whitelist(sender, recipient);
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            let spender = get_caller_address();
            self._check_whitelist(sender, recipient);
            self._spend_allowance(sender, spender, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn totalSupply(self: @ContractState) -> u256 {
            self.total_supply()
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn transferFrom(
            ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
        ) -> bool {
            self.transfer_from(sender, recipient, amount)
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self.allowances.write((owner, spender), amount);
            self.emit(Event::Approval(Approval { owner, spender, value: amount }));
            true
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let owner = get_caller_address();
            let current = self.allowances.read((owner, spender));
            let updated = current + added_value;
            self.allowances.write((owner, spender), updated);
            self.emit(Event::Approval(Approval { owner, spender, value: updated }));
            true
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let owner = get_caller_address();
            let current = self.allowances.read((owner, spender));
            assert(current >= subtracted_value, 'ALLOWANCE_UNDERFLOW');
            let updated = current - subtracted_value;
            self.allowances.write((owner, spender), updated);
            self.emit(Event::Approval(Approval { owner, spender, value: updated }));
            true
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let owner = self.owner.read();
            assert(
                caller == owner || caller == self.privacy_module.read(), 'NOT_AUTHORIZED'
            );

            let mode = self.mint_mode.read();
            match mode {
                MintMode::Fixed => {
                    panic_with_felt252('MINT_DISABLED');
                },
                MintMode::MintOnce => {
                    assert(!self.mint_once_used.read(), 'MINT_ONCE_USED');
                    self.mint_once_used.write(true);
                },
                MintMode::UnlimitedWithCap => {
                    let minted = self.minted_total.read();
                    let new_total = minted + amount;
                    assert(new_total <= self.max_mint_cap.read(), 'CAP_EXCEEDED');
                },
            };

            self._mint(recipient, amount);
            let new_minted_total = self.minted_total.read() + amount;
            self.minted_total.write(new_minted_total);

            self.emit(
                Event::Minted(
                    Minted { recipient, amount, minted_total: new_minted_total }
                )
            );
        }

        fn mint_from_privacy(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert(self.privacy_enabled.read(), 'PRIVACY_DISABLED');
            assert(caller == self.privacy_module.read(), 'PRIVACY_ONLY');
            self._mint(recipient, amount);
        }

        fn get_minted_total(self: @ContractState) -> u256 {
            self.minted_total.read()
        }

        fn get_max_mint_cap(self: @ContractState) -> u256 {
            self.max_mint_cap.read()
        }

        fn get_mint_mode(self: @ContractState) -> MintMode {
            self.mint_mode.read()
        }

        fn burn(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let permission = self.burn_permission.read();

            match permission {
                BurnPermission::Nobody => {
                    panic_with_felt252('BURN_DISABLED');
                },
                BurnPermission::Self_ => {
                    self._burn(caller, amount);
                },
                BurnPermission::AdminOnly => {
                    self._assert_only_owner();
                    self._burn(caller, amount);
                },
            };
        }

        fn burn_from(ref self: ContractState, account: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            let permission = self.burn_permission.read();

            match permission {
                BurnPermission::Nobody => {
                    panic_with_felt252('BURN_DISABLED');
                },
                BurnPermission::Self_ => {
                    assert(caller == account, 'SELF_ONLY');
                    self._burn(account, amount);
                },
                BurnPermission::AdminOnly => {
                    let owner = self.owner.read();
                    assert(
                        caller == owner || caller == self.privacy_module.read(), 'NOT_AUTHORIZED'
                    );
                    self._burn(account, amount);
                },
            };
        }

        fn burn_for_privacy(ref self: ContractState, account: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            assert(self.privacy_enabled.read(), 'PRIVACY_DISABLED');
            assert(caller == self.privacy_module.read(), 'PRIVACY_ONLY');
            self._burn(account, amount);
            self.emit(Event::PrivacyBurned(PrivacyBurned { initiator: caller, account, amount }));
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        fn pending_owner(self: @ContractState) -> ContractAddress {
            self.pending_owner.read()
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            self._assert_only_owner();
            let zero_addr = self._zero_address();
            assert(new_owner != zero_addr, 'NEW_OWNER_ZERO');
            assert(new_owner != self.owner.read(), 'ALREADY_OWNER');

            let previous_owner = self.owner.read();
            self.pending_owner.write(new_owner);
            self.emit(
                Event::OwnershipTransferStarted(
                    OwnershipTransferStarted { previous_owner, new_pending_owner: new_owner }
                )
            );
        }

        fn accept_ownership(ref self: ContractState) {
            let caller = get_caller_address();
            let pending = self.pending_owner.read();
            assert(caller == pending, 'NOT_PENDING_OWNER');

            let previous_owner = self.owner.read();
            self.owner.write(caller);
            self.pending_owner.write(self._zero_address());
            self.emit(Event::OwnershipTransferred(OwnershipTransferred { previous_owner, new_owner: caller }));
        }

        fn renounce_ownership(ref self: ContractState) {
            self._assert_only_owner();
            let zero_addr = self._zero_address();

            let previous_owner = self.owner.read();
            self.owner.write(zero_addr);
            self.pending_owner.write(zero_addr);
            self.emit(
                Event::OwnershipTransferred(
                    OwnershipTransferred { previous_owner, new_owner: zero_addr }
                )
            );
        }

        fn get_whitelist_mode(self: @ContractState) -> WhitelistMode {
            self.whitelist_mode.read()
        }

        fn is_whitelisted(self: @ContractState, addr: ContractAddress) -> bool {
            self.whitelisted.read(addr)
        }

        fn set_whitelist(ref self: ContractState, addr: ContractAddress, allowed: bool) {
            self._assert_only_owner();
            self.whitelisted.write(addr, allowed);
            self.emit(Event::WhitelistUpdated(WhitelistUpdated { addr, allowed }));
        }

        fn set_whitelist_batch(ref self: ContractState, addrs: Array<ContractAddress>, allowed: bool) {
            self._assert_only_owner();

            let mut index = 0;
            loop {
                if index == addrs.len() {
                    break;
                }

                let addr = *addrs.at(index);
                self.whitelisted.write(addr, allowed);
                self.emit(Event::WhitelistUpdated(WhitelistUpdated { addr, allowed }));
                index += 1;
            }
        }

        fn set_whitelist_mode(ref self: ContractState, mode: WhitelistMode) {
            self._assert_only_owner();
            self.whitelist_mode.write(mode);
            self.emit(Event::WhitelistModeChanged(WhitelistModeChanged { new_mode: mode }));
        }

        fn get_website(self: @ContractState) -> ByteArray {
            self.website.read()
        }

        fn get_twitter(self: @ContractState) -> ByteArray {
            self.twitter.read()
        }

        fn get_instagram(self: @ContractState) -> ByteArray {
            self.instagram.read()
        }

        fn get_image_uri(self: @ContractState) -> ByteArray {
            self.image_uri.read()
        }

        fn get_urn(self: @ContractState) -> ByteArray {
            self.urn.read()
        }

        fn update_metadata(
            ref self: ContractState,
            website: ByteArray,
            twitter: ByteArray,
            instagram: ByteArray,
            image_uri: ByteArray,
            urn: ByteArray,
        ) {
            self._assert_only_owner();
            self.website.write(website);
            self.twitter.write(twitter);
            self.instagram.write(instagram);
            self.image_uri.write(image_uri);
            self.urn.write(urn);

            self.emit(Event::MetadataUpdated(MetadataUpdated { timestamp: get_block_timestamp() }));
        }

        fn is_privacy_enabled(self: @ContractState) -> bool {
            self.privacy_enabled.read()
        }

        fn set_privacy_module(ref self: ContractState, module: ContractAddress) {
            self._assert_only_owner();
            assert(self.privacy_enabled.read(), 'PRIVACY_DISABLED');
            let zero_addr = self._zero_address();
            assert(module != zero_addr, 'MODULE_ZERO');
            assert(self.privacy_module.read() == zero_addr, 'MODULE_ALREADY_SET');
            self.privacy_module.write(module);
            self.emit(Event::PrivacyModuleSet(PrivacyModuleSet { module }));
        }

        fn transfer_privacy_module(ref self: ContractState, new_module: ContractAddress) {
            self._assert_only_owner();
            assert(self.privacy_enabled.read(), 'PRIVACY_DISABLED');
            let zero_addr = self._zero_address();
            let current = self.privacy_module.read();
            assert(current != zero_addr, 'MODULE_NOT_SET');
            assert(new_module != zero_addr, 'MODULE_ZERO');
            assert(new_module != current, 'ALREADY_MODULE');
            self.pending_privacy_module.write(new_module);
            self.emit(
                Event::PrivacyModuleTransferStarted(
                    PrivacyModuleTransferStarted {
                        previous_module: current, new_pending_module: new_module
                    }
                )
            );
        }

        fn accept_privacy_module(ref self: ContractState) {
            assert(self.privacy_enabled.read(), 'PRIVACY_DISABLED');
            let caller = get_caller_address();
            let pending = self.pending_privacy_module.read();
            assert(caller == pending, 'NOT_PENDING_MODULE');
            let previous_module = self.privacy_module.read();
            self.privacy_module.write(caller);
            self.pending_privacy_module.write(self._zero_address());
            self.emit(
                Event::PrivacyModuleTransferred(
                    PrivacyModuleTransferred { previous_module, new_module: caller }
                )
            );
        }

        fn get_privacy_module(self: @ContractState) -> ContractAddress {
            self.privacy_module.read()
        }

        fn get_pending_privacy_module(self: @ContractState) -> ContractAddress {
            self.pending_privacy_module.read()
        }
    }

    #[external(v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        self.supported_interfaces.read(interface_id)
    }

    #[external(v0)]
    fn set_supported_interface(
        ref self: ContractState, interface_id: felt252, supported: bool
    ) {
        self._assert_only_owner();
        self.supported_interfaces.write(interface_id, supported);
    }
}
