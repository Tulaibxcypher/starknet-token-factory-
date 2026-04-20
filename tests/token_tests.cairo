use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address
};
use core::integer::u256;
use starknet::ContractAddress;
use starknet_token_factory::interfaces::itoken::{ITokenDispatcher, ITokenDispatcherTrait};
use starknet_token_factory::types::{BurnPermission, MintMode, TokenConfig, WhitelistMode};

fn as_u256(v: u128) -> u256 {
    u256 { low: v, high: 0_u128 }
}

fn deploy_token(
    mint_mode: MintMode,
    burn_permission: BurnPermission,
    whitelist_mode: WhitelistMode,
    initial_supply: u256,
    max_mint_cap: u256,
    privacy_enabled: bool,
) -> (ITokenDispatcher, ContractAddress) {
    let owner: ContractAddress = 500.try_into().unwrap();
    let token_class = declare("TokenContract").unwrap().contract_class();
    let config = TokenConfig {
        name: "Demo Token",
        symbol: "DMT",
        decimals: 18,
        owner,
        initial_supply,
        max_mint_cap,
        mint_mode,
        burn_permission,
        whitelist_mode,
        website: "https://example.com",
        twitter: "https://x.com/demo",
        instagram: "https://instagram.com/demo",
        image_uri: "ipfs://demo-image",
        urn: "urn:demo:token",
        privacy_enabled,
    };

    let mut constructor_calldata = array![];
    config.serialize(ref constructor_calldata);
    let (token_address, _) = token_class.deploy(@constructor_calldata).unwrap();
    (ITokenDispatcher { contract_address: token_address }, owner)
}

// Why: Validates constructor metadata/state was persisted correctly.
#[test]
fn test_token_constructor_stores_core_metadata() {
    let (token, owner) = deploy_token(
        MintMode::UnlimitedWithCap, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(1_000), as_u256(1_000_000), true
    );

    assert(token.name() == "Demo Token", 'BAD_NAME');
    assert(token.symbol() == "DMT", 'BAD_SYMBOL');
    assert(token.decimals() == 18, 'BAD_DECIMALS');
    assert(token.owner() == owner, 'BAD_OWNER');
    assert(token.total_supply() == as_u256(1_000), 'BAD_SUPPLY');
    assert(token.balance_of(owner) == as_u256(1_000), 'OWNER_BAL_BAD');
    assert(token.is_privacy_enabled(), 'PRIVACY_FLAG_BAD');
}

// Why: Enforces constructor cap invariant when unlimited-with-cap mode is selected.
#[test]
fn test_constructor_rejects_initial_supply_over_cap_in_unlimited_mode() {
    let owner: ContractAddress = 500.try_into().unwrap();
    let token_class = declare("TokenContract").unwrap().contract_class();
    let config = TokenConfig {
        name: "Demo Token",
        symbol: "DMT",
        decimals: 18,
        owner,
        initial_supply: as_u256(101),
        max_mint_cap: as_u256(100),
        mint_mode: MintMode::UnlimitedWithCap,
        burn_permission: BurnPermission::Self_,
        whitelist_mode: WhitelistMode::Disabled,
        website: "https://example.com",
        twitter: "https://x.com/demo",
        instagram: "https://instagram.com/demo",
        image_uri: "ipfs://demo-image",
        urn: "urn:demo:token",
        privacy_enabled: false,
    };

    let mut constructor_calldata = array![];
    config.serialize(ref constructor_calldata);
    let deploy_result = token_class.deploy(@constructor_calldata);
    assert(deploy_result.is_err(), 'EXPECTED_DEPLOY_FAIL');
}

// Why: Ensures fixed mint mode permanently blocks post-deploy minting.
#[test]
#[should_panic(expected: ('MINT_DISABLED',))]
fn test_fixed_mode_rejects_post_deploy_mint() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(100), as_u256(1000), false
    );
    start_cheat_caller_address(token.contract_address, owner);
    token.mint(owner, as_u256(1));
}

// Why: Ensures MintOnce allows exactly one owner mint and updates accounting.
#[test]
fn test_mintonce_mode_first_mint_succeeds() {
    let (token, owner) = deploy_token(
        MintMode::MintOnce, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(10_000), false
    );

    start_cheat_caller_address(token.contract_address, owner);
    token.mint(owner, as_u256(200));
    stop_cheat_caller_address(token.contract_address);

    assert(token.total_supply() == as_u256(200), 'SUPPLY_AFTER_MINT_BAD');
    assert(token.get_minted_total() == as_u256(200), 'MINTED_TOTAL_BAD');
}

// Why: Prevents repeated inflation when MintOnce has already been consumed.
#[test]
#[should_panic(expected: ('MINT_ONCE_USED',))]
fn test_mintonce_mode_second_mint_fails() {
    let (token, owner) = deploy_token(
        MintMode::MintOnce, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(10_000), false
    );

    start_cheat_caller_address(token.contract_address, owner);
    token.mint(owner, as_u256(100));
    token.mint(owner, as_u256(1));
}

// Why: Enforces mint-cap ceiling in unlimited-with-cap mode.
#[test]
#[should_panic(expected: ('CAP_EXCEEDED',))]
fn test_unlimited_cap_mint_over_cap_fails() {
    let (token, owner) = deploy_token(
        MintMode::UnlimitedWithCap, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(100), false
    );

    start_cheat_caller_address(token.contract_address, owner);
    token.mint(owner, as_u256(70));
    token.mint(owner, as_u256(31));
}

// Why: Ensures only owner can mint regardless of mode.
#[test]
#[should_panic(expected: ('ONLY_OWNER',))]
fn test_mint_non_owner_fails() {
    let (token, _owner) = deploy_token(
        MintMode::UnlimitedWithCap, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(1000), false
    );
    let attacker: ContractAddress = 909.try_into().unwrap();
    start_cheat_caller_address(token.contract_address, attacker);
    token.mint(attacker, as_u256(1));
}

// Why: Provides safer allowance update path without replacing full allowance atomically.
#[test]
fn test_increase_allowance_updates_value() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let spender: ContractAddress = 710.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(spender, as_u256(10));
    token.increase_allowance(spender, as_u256(15));
    stop_cheat_caller_address(token.contract_address);

    assert(token.allowance(owner, spender) == as_u256(25), 'ALLOWANCE_NOT_INCREASED');
}

// Why: Allows decrementing allowance safely while preserving expected remaining amount.
#[test]
fn test_decrease_allowance_updates_value() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let spender: ContractAddress = 711.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(spender, as_u256(20));
    token.decrease_allowance(spender, as_u256(7));
    stop_cheat_caller_address(token.contract_address);

    assert(token.allowance(owner, spender) == as_u256(13), 'ALLOWANCE_NOT_DECREASED');
}

// Why: Prevents underflow and accidental wrap when decreasing below zero.
#[test]
#[should_panic(expected: ('ALLOWANCE_UNDERFLOW',))]
fn test_decrease_allowance_underflow_fails() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let spender: ContractAddress = 712.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(spender, as_u256(5));
    token.decrease_allowance(spender, as_u256(6));
}

// Why: Confirms self-burn permission reduces holder balance and total supply.
#[test]
fn test_self_burn_reduces_balance_and_supply() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(500), as_u256(500), false
    );

    start_cheat_caller_address(token.contract_address, owner);
    token.burn(as_u256(120));
    stop_cheat_caller_address(token.contract_address);

    assert(token.balance_of(owner) == as_u256(380), 'BALANCE_AFTER_BURN_BAD');
    assert(token.total_supply() == as_u256(380), 'SUPPLY_AFTER_BURN_BAD');
}

// Why: Ensures admin-only burn permission allows owner-initiated burn.
#[test]
fn test_admin_only_burn_by_owner_succeeds() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::AdminOnly, WhitelistMode::Disabled, as_u256(300), as_u256(300), false
    );

    start_cheat_caller_address(token.contract_address, owner);
    token.burn(as_u256(100));
    stop_cheat_caller_address(token.contract_address);

    assert(token.balance_of(owner) == as_u256(200), 'ADMIN_BURN_BAL_BAD');
    assert(token.total_supply() == as_u256(200), 'ADMIN_BURN_SUPPLY_BAD');
}

// Why: Validates strict-both whitelist guard blocks unapproved sender.
#[test]
#[should_panic(expected: ('SENDER_NOT_WL',))]
fn test_strict_both_sender_not_whitelisted_fails() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::StrictBoth, as_u256(200), as_u256(200), false
    );
    let recipient: ContractAddress = 880.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.set_whitelist(recipient, true);
    stop_cheat_caller_address(token.contract_address);

    let sender: ContractAddress = 881.try_into().unwrap();
    start_cheat_caller_address(token.contract_address, sender);
    token.transfer(recipient, as_u256(10));
}

// Why: Confirms strict-both mode permits transfer when both endpoints are whitelisted.
#[test]
fn test_strict_both_both_whitelisted_succeeds() {
    let (token, owner) = deploy_token(
        MintMode::UnlimitedWithCap, BurnPermission::Self_, WhitelistMode::StrictBoth, as_u256(0), as_u256(1_000), false
    );
    let sender: ContractAddress = 882.try_into().unwrap();
    let recipient: ContractAddress = 883.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.mint(sender, as_u256(100));
    token.set_whitelist(sender, true);
    token.set_whitelist(recipient, true);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(token.contract_address, sender);
    let ok = token.transfer(recipient, as_u256(25));
    stop_cheat_caller_address(token.contract_address);

    assert(ok, 'TRANSFER_RETURN_FALSE');
    assert(token.balance_of(recipient) == as_u256(25), 'RECIPIENT_BAL_BAD');
}

// Why: Ensures ownership transfer updates authorization source of truth.
#[test]
fn test_transfer_ownership_works() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let new_owner: ContractAddress = 990.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.transfer_ownership(new_owner);
    stop_cheat_caller_address(token.contract_address);

    assert(token.owner() == owner, 'OWNER_CHANGED_TOO_EARLY');
    assert(token.pending_owner() == new_owner, 'PENDING_OWNER_NOT_SET');

    start_cheat_caller_address(token.contract_address, new_owner);
    token.accept_ownership();
    stop_cheat_caller_address(token.contract_address);

    assert(token.owner() == new_owner, 'OWNER_NOT_UPDATED');
    assert(token.pending_owner() == 0.try_into().unwrap(), 'PENDING_OWNER_NOT_CLEARED');
}

// Why: Prevents unauthorized control takeover by non-owner callers.
#[test]
#[should_panic(expected: ('ONLY_OWNER',))]
fn test_transfer_ownership_non_owner_fails() {
    let (token, _owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let attacker: ContractAddress = 991.try_into().unwrap();
    let next_owner: ContractAddress = 992.try_into().unwrap();
    start_cheat_caller_address(token.contract_address, attacker);
    token.transfer_ownership(next_owner);
}

// Why: Prevents ownership hijack by requiring only pending owner to accept.
#[test]
#[should_panic(expected: ('NOT_PENDING_OWNER',))]
fn test_accept_ownership_non_pending_owner_fails() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let next_owner: ContractAddress = 992.try_into().unwrap();
    let attacker: ContractAddress = 993.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.transfer_ownership(next_owner);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(token.contract_address, attacker);
    token.accept_ownership();
}

// Why: Ensures renounce flow writes zero address and disables owner-only powers.
#[test]
fn test_renounce_ownership_sets_zero_address() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.renounce_ownership();
    stop_cheat_caller_address(token.contract_address);

    assert(token.owner() == zero, 'OWNER_NOT_ZERO');
}

// Why: Prevents linking privacy module on tokens that were deployed with privacy disabled.
#[test]
#[should_panic(expected: ('PRIVACY_DISABLED',))]
fn test_set_privacy_module_rejects_when_privacy_disabled() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), false
    );
    let module: ContractAddress = 1111.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.set_privacy_module(module);
}

// Why: Prevents zero-address misconfiguration that can brick privacy flow.
#[test]
#[should_panic(expected: ('MODULE_ZERO',))]
fn test_set_privacy_module_rejects_zero_address() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), true
    );
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.set_privacy_module(zero);
}

// Why: Makes privacy module immutable after first set to avoid accidental or malicious relinking.
#[test]
#[should_panic(expected: ('MODULE_ALREADY_SET',))]
fn test_set_privacy_module_one_time_only() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), true
    );
    let module_a: ContractAddress = 1201.try_into().unwrap();
    let module_b: ContractAddress = 1202.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.set_privacy_module(module_a);
    token.set_privacy_module(module_b);
}

// Why: Enforces two-step privacy-module transfer to avoid accidental relinking.
#[test]
fn test_transfer_privacy_module_two_step_works() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), true
    );
    let module_a: ContractAddress = 1301.try_into().unwrap();
    let module_b: ContractAddress = 1302.try_into().unwrap();
    let zero: ContractAddress = 0.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.set_privacy_module(module_a);
    token.transfer_privacy_module(module_b);
    stop_cheat_caller_address(token.contract_address);

    assert(token.get_privacy_module() == module_a, 'MODULE_CHANGED_TOO_EARLY');
    assert(token.get_pending_privacy_module() == module_b, 'PENDING_MODULE_BAD');

    start_cheat_caller_address(token.contract_address, module_b);
    token.accept_privacy_module();
    stop_cheat_caller_address(token.contract_address);

    assert(token.get_privacy_module() == module_b, 'MODULE_NOT_UPDATED');
    assert(token.get_pending_privacy_module() == zero, 'PENDING_NOT_CLEARED');
}

// Why: Prevents non-pending module from accepting privacy-module ownership.
#[test]
#[should_panic(expected: ('NOT_PENDING_MODULE',))]
fn test_accept_privacy_module_non_pending_fails() {
    let (token, owner) = deploy_token(
        MintMode::Fixed, BurnPermission::Self_, WhitelistMode::Disabled, as_u256(0), as_u256(0), true
    );
    let module_a: ContractAddress = 1401.try_into().unwrap();
    let module_b: ContractAddress = 1402.try_into().unwrap();
    let attacker: ContractAddress = 1403.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.set_privacy_module(module_a);
    token.transfer_privacy_module(module_b);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(token.contract_address, attacker);
    token.accept_privacy_module();
}
