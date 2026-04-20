use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address
};
use starknet::ContractAddress;
use starknet_token_factory::interfaces::iprivacy::{IPrivacyDispatcher, IPrivacyDispatcherTrait};
use starknet_token_factory::interfaces::itoken::{ITokenDispatcher, ITokenDispatcherTrait};
use starknet_token_factory::types::{BurnPermission, MintMode, TokenConfig, WhitelistMode};

fn setup_privacy() -> (IPrivacyDispatcher, ITokenDispatcher, ContractAddress, ContractAddress) {
    let owner: ContractAddress = 101.try_into().unwrap();
    let auditor: ContractAddress = 202.try_into().unwrap();
    let merkle_root: felt252 = 0x1234;
    let domain_separator: felt252 = 0x505249564143595f5631;

    let token_class = declare("TokenContract").unwrap().contract_class();
    let token_config = TokenConfig {
        name: "Privacy Token",
        symbol: "PVT",
        decimals: 18,
        owner,
        initial_supply: 1_000,
        max_mint_cap: 10_000,
        mint_mode: MintMode::UnlimitedWithCap,
        burn_permission: BurnPermission::Self_,
        whitelist_mode: WhitelistMode::Disabled,
        website: "https://example.com",
        twitter: "https://x.com/example",
        instagram: "https://instagram.com/example",
        image_uri: "ipfs://image",
        urn: "urn:privacy:test",
        privacy_enabled: true,
    };
    let mut token_constructor_calldata = array![];
    token_config.serialize(ref token_constructor_calldata);
    let (token_address, _) = token_class.deploy(@token_constructor_calldata).unwrap();
    let token = ITokenDispatcher { contract_address: token_address };

    let verifier_class = declare("MockVerifier").unwrap().contract_class();
    let verifier_calldata = array![];
    let (verifier_address, _) = verifier_class.deploy(@verifier_calldata).unwrap();

    let privacy_class = declare("PrivacyContract").unwrap().contract_class();
    let mut constructor_calldata = array![];
    Serde::<ContractAddress>::serialize(@token_address, ref constructor_calldata);
    Serde::<ContractAddress>::serialize(@auditor, ref constructor_calldata);
    Serde::<ContractAddress>::serialize(@verifier_address, ref constructor_calldata);
    Serde::<felt252>::serialize(@merkle_root, ref constructor_calldata);
    Serde::<felt252>::serialize(@domain_separator, ref constructor_calldata);
    let (privacy_address, _) = privacy_class.deploy(@constructor_calldata).unwrap();
    let privacy = IPrivacyDispatcher { contract_address: privacy_address };

    start_cheat_caller_address(token.contract_address, owner);
    token.set_privacy_module(privacy_address);
    stop_cheat_caller_address(token.contract_address);

    (privacy, token, owner, auditor)
}

fn single_word_proof(word: felt252) -> Array<felt252> {
    let mut proof = array![];
    proof.append(word);
    proof
}

#[test]
fn test_shield_records_commitment_and_updates_total() {
    let (privacy, token, owner, _) = setup_privacy();

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(privacy.contract_address, 40);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(privacy.contract_address, owner);
    privacy.shield(40, 1111, 9999);
    stop_cheat_caller_address(privacy.contract_address);

    assert(privacy.get_total_shielded() == 40, 'TOTAL_SHIELDED_BAD');
}

#[test]
fn test_unshield_marks_nullifier_and_reduces_total() {
    let (privacy, token, owner, _) = setup_privacy();
    let recipient: ContractAddress = 305.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(privacy.contract_address, 70);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(privacy.contract_address, owner);
    privacy.shield(70, 2222, 8888);
    stop_cheat_caller_address(privacy.contract_address);

    privacy.unshield(2222, 12345, single_word_proof(1), recipient, 30);

    assert(privacy.is_nullifier_spent(12345), 'NULLIFIER_NOT_MARKED');
    assert(privacy.get_total_shielded() == 40, 'TOTAL_NOT_REDUCED');
}

#[test]
#[should_panic(expected: ('NULLIFIER_SPENT',))]
fn test_unshield_rejects_spent_nullifier() {
    let (privacy, token, owner, _) = setup_privacy();
    let recipient: ContractAddress = 307.try_into().unwrap();

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(privacy.contract_address, 60);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(privacy.contract_address, owner);
    privacy.shield(60, 3333, 7777);
    stop_cheat_caller_address(privacy.contract_address);

    let nullifier: felt252 = 4444;
    privacy.unshield(3333, nullifier, single_word_proof(1), recipient, 20);
    privacy.unshield(3333, nullifier, single_word_proof(1), recipient, 10);
}

#[test]
fn test_private_transfer_marks_nullifier_and_creates_commitment() {
    let (privacy, token, owner, _) = setup_privacy();
    let nullifier: felt252 = 5555;

    start_cheat_caller_address(token.contract_address, owner);
    token.approve(privacy.contract_address, 10);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(privacy.contract_address, owner);
    privacy.shield(10, 5554, 1234);
    stop_cheat_caller_address(privacy.contract_address);

    privacy.private_transfer(nullifier, 6666, single_word_proof(1));
    assert(privacy.is_nullifier_spent(nullifier), 'PT_NULLIFIER_NOT_SPENT');
}

#[test]
fn test_register_viewing_key_updates_registry() {
    let (privacy, _, _, auditor) = setup_privacy();
    let user: ContractAddress = 808.try_into().unwrap();
    let key_hash: felt252 = 919191;

    start_cheat_caller_address(privacy.contract_address, user);
    privacy.register_viewing_key(key_hash);
    stop_cheat_caller_address(privacy.contract_address);

    start_cheat_caller_address(privacy.contract_address, auditor);
    let stored = privacy.get_viewing_key(user);
    stop_cheat_caller_address(privacy.contract_address);

    assert(stored == key_hash, 'VIEWING_KEY_BAD');
}

#[test]
#[should_panic(expected: ('AUDITOR_ONLY',))]
fn test_get_viewing_key_auditor_only() {
    let (privacy, _, _, _) = setup_privacy();
    let user: ContractAddress = 909.try_into().unwrap();
    let attacker: ContractAddress = 910.try_into().unwrap();

    start_cheat_caller_address(privacy.contract_address, user);
    privacy.register_viewing_key(123456);
    stop_cheat_caller_address(privacy.contract_address);

    start_cheat_caller_address(privacy.contract_address, attacker);
    privacy.get_viewing_key(user);
}

#[test]
fn test_shield_allows_non_owner_when_approved() {
    let (privacy, token, owner, _) = setup_privacy();
    let user: ContractAddress = 12345.try_into().unwrap();

    // Fund a non-owner account so we can prove policy (not balance) is the blocker.
    start_cheat_caller_address(token.contract_address, owner);
    token.transfer(user, 25);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(token.contract_address, user);
    token.approve(privacy.contract_address, 25);
    stop_cheat_caller_address(token.contract_address);

    start_cheat_caller_address(privacy.contract_address, user);
    privacy.shield(25, 99991, 77777);
    stop_cheat_caller_address(privacy.contract_address);

    assert(privacy.get_total_shielded() == 25, 'NON_OWNER_SHIELD_FAILED');
}
