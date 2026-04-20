use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address
};
use starknet::ContractAddress;
use starknet_token_factory::interfaces::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
use starknet_token_factory::interfaces::itoken::{ITokenDispatcher, ITokenDispatcherTrait};
use starknet_token_factory::types::{BurnPermission, MintMode, TokenConfig, WhitelistMode};

fn setup_factory() -> (IFactoryDispatcher, starknet::ClassHash) {
    let token_declare = declare("TokenContract").unwrap();
    let token_class_hash = *token_declare.contract_class().class_hash;

    let factory_class = declare("FactoryContract").unwrap().contract_class();
    let owner: ContractAddress = 111.try_into().unwrap();

    let mut constructor_calldata = array![];
    Serde::<starknet::ClassHash>::serialize(@token_class_hash, ref constructor_calldata);
    Serde::<ContractAddress>::serialize(@owner, ref constructor_calldata);

    let (factory_address, _) = factory_class.deploy(@constructor_calldata).unwrap();
    (IFactoryDispatcher { contract_address: factory_address }, token_class_hash)
}

// Why: Enforces two-step factory ownership handoff safety.
#[test]
fn test_factory_two_step_ownership_transfer_works() {
    let (factory, _) = setup_factory();
    let current_owner: ContractAddress = 111.try_into().unwrap();
    let new_owner: ContractAddress = 112.try_into().unwrap();
    let zero: ContractAddress = 0.try_into().unwrap();

    assert(factory.get_factory_owner() == current_owner, 'FACTORY_OWNER_BAD');
    assert(factory.get_pending_factory_owner() == zero, 'PENDING_NOT_ZERO');

    start_cheat_caller_address(factory.contract_address, current_owner);
    factory.transfer_factory_ownership(new_owner);
    stop_cheat_caller_address(factory.contract_address);

    assert(factory.get_factory_owner() == current_owner, 'OWNER_CHANGED_TOO_EARLY');
    assert(factory.get_pending_factory_owner() == new_owner, 'PENDING_NOT_SET');

    start_cheat_caller_address(factory.contract_address, new_owner);
    factory.accept_factory_ownership();
    stop_cheat_caller_address(factory.contract_address);

    assert(factory.get_factory_owner() == new_owner, 'OWNER_NOT_UPDATED');
    assert(factory.get_pending_factory_owner() == zero, 'PENDING_NOT_CLEARED');
}

// Why: Prevents bricking factory at deploy-time with unusable zero class hash.
#[test]
fn test_factory_constructor_rejects_zero_class_hash() {
    let factory_class = declare("FactoryContract").unwrap().contract_class();
    let owner: ContractAddress = 111.try_into().unwrap();
    let zero_class_hash: starknet::ClassHash = 0.try_into().unwrap();

    let mut constructor_calldata = array![];
    Serde::<starknet::ClassHash>::serialize(@zero_class_hash, ref constructor_calldata);
    Serde::<ContractAddress>::serialize(@owner, ref constructor_calldata);

    let deploy_result = factory_class.deploy(@constructor_calldata);
    assert(deploy_result.is_err(), 'EXPECTED_DEPLOY_FAIL');
}

fn build_token_config(name: ByteArray, symbol: ByteArray, privacy_enabled: bool) -> TokenConfig {
    TokenConfig {
        name,
        symbol,
        decimals: 18,
        owner: 222.try_into().unwrap(),
        initial_supply: 1_000,
        max_mint_cap: 1_000_000,
        mint_mode: MintMode::UnlimitedWithCap,
        burn_permission: BurnPermission::Self_,
        whitelist_mode: WhitelistMode::Disabled,
        website: "https://example.com",
        twitter: "https://x.com/example",
        instagram: "https://instagram.com/example",
        image_uri: "ipfs://image",
        urn: "urn:example:token",
        privacy_enabled,
    }
}

// Why: Proves that factory deployment + create_token path actually works end-to-end.
#[test]
fn test_factory_deploys_token_at_unique_address() {
    let (factory, _) = setup_factory();
    let config = build_token_config("Factory Token A", "FTA", false);
    let token_address = factory.create_token(config);
    let zero_address: ContractAddress = 0.try_into().unwrap();
    assert(token_address != zero_address, 'TOKEN_ZERO_ADDR');
}

// Why: Guards against accidental deterministic-collision bugs in factory salt generation.
#[test]
fn test_factory_two_identical_configs_produce_different_addresses() {
    let (factory, _) = setup_factory();
    let token_a = factory.create_token(build_token_config("Repeated", "RPT", true));
    let token_b = factory.create_token(build_token_config("Repeated", "RPT", true));
    assert(token_a != token_b, 'TOKEN_ADDR_COLLISION');
}

// Why: Ensures global registry grows correctly after each create_token call.
#[test]
fn test_factory_token_count_increments() {
    let (factory, _) = setup_factory();
    assert(factory.get_token_count() == 0, 'COUNT_NOT_ZERO');

    let token_1 = build_token_config("One", "ONE", false);
    let token_2 = build_token_config("Two", "TWO", true);
    factory.create_token(token_1);
    factory.create_token(token_2);

    assert(factory.get_token_count() == 2, 'COUNT_NOT_TWO');
}

// Why: Verifies all_tokens registry keeps insertion order and exact deployed addresses.
#[test]
fn test_factory_get_all_tokens_returns_correct_list() {
    let (factory, _) = setup_factory();

    let token_1 = factory.create_token(build_token_config("A", "A", false));
    let token_2 = factory.create_token(build_token_config("B", "B", false));
    let token_3 = factory.create_token(build_token_config("C", "C", true));

    let all_tokens = factory.get_all_tokens();
    assert(all_tokens.len() == 3, 'ALL_TOKENS_LEN_BAD');
    assert(*all_tokens.at(0) == token_1, 'ALL_TOKENS_IDX0_BAD');
    assert(*all_tokens.at(1) == token_2, 'ALL_TOKENS_IDX1_BAD');
    assert(*all_tokens.at(2) == token_3, 'ALL_TOKENS_IDX2_BAD');
}

// Why: Ensures global pagination returns the correct slice and respects offset/limit.
#[test]
fn test_factory_get_all_tokens_paginated_returns_correct_slice() {
    let (factory, _) = setup_factory();

    let token_1 = factory.create_token(build_token_config("A", "A", false));
    let token_2 = factory.create_token(build_token_config("B", "B", false));
    let token_3 = factory.create_token(build_token_config("C", "C", true));

    let page = factory.get_all_tokens_paginated(1, 2);
    assert(page.len() == 2, 'PAGE_LEN_BAD');
    assert(*page.at(0) == token_2, 'PAGE_IDX0_BAD');
    assert(*page.at(1) == token_3, 'PAGE_IDX1_BAD');
    assert(*page.at(0) != token_1, 'PAGE_OFFSET_IGNORED');
}

// Why: Ensures pagination returns empty when offset is beyond registry length.
#[test]
fn test_factory_get_all_tokens_paginated_offset_out_of_range_returns_empty() {
    let (factory, _) = setup_factory();
    factory.create_token(build_token_config("A", "A", false));
    let page = factory.get_all_tokens_paginated(10, 2);
    assert(page.len() == 0, 'EXPECTED_EMPTY_PAGE');
}

// Why: Ensures creator-scoped pagination slices correctly and safely clamps at end.
#[test]
fn test_factory_get_tokens_by_creator_paginated_returns_correct_slice() {
    let (factory, _) = setup_factory();
    let creator: ContractAddress = 445.try_into().unwrap();
    start_cheat_caller_address(factory.contract_address, creator);
    let token_1 = factory.create_token(build_token_config("C1", "C1", false));
    let token_2 = factory.create_token(build_token_config("C2", "C2", false));
    let token_3 = factory.create_token(build_token_config("C3", "C3", false));
    stop_cheat_caller_address(factory.contract_address);

    let page = factory.get_tokens_by_creator_paginated(creator, 1, 5);
    assert(page.len() == 2, 'CREATOR_PAGE_LEN_BAD');
    assert(*page.at(0) == token_2, 'CREATOR_PAGE_IDX0_BAD');
    assert(*page.at(1) == token_3, 'CREATOR_PAGE_IDX1_BAD');
    assert(*page.at(0) != token_1, 'CREATOR_PAGE_OFFSET_IGNORED');
}

// Why: Ensures per-creator indexing remains consistent for dashboard/filter use-cases.
#[test]
fn test_factory_stores_creator_to_token_mapping() {
    let (factory, _) = setup_factory();
    let creator: ContractAddress = 444.try_into().unwrap();
    start_cheat_caller_address(factory.contract_address, creator);

    let token_1 = factory.create_token(build_token_config("Creator 1", "C1", false));
    let token_2 = factory.create_token(build_token_config("Creator 2", "C2", true));

    stop_cheat_caller_address(factory.contract_address);

    let creator_tokens = factory.get_tokens_by_creator(creator);

    assert(creator_tokens.len() == 2, 'CREATOR_LIST_LEN_BAD');
    assert(*creator_tokens.at(0) == token_1, 'CREATOR_LIST_IDX0_BAD');
    assert(*creator_tokens.at(1) == token_2, 'CREATOR_LIST_IDX1_BAD');
}

// Why: Protects the trusted-token gate by verifying only factory-created addresses are flagged.
#[test]
fn test_factory_is_factory_token_returns_true_for_created_token() {
    let (factory, _) = setup_factory();
    let token = factory.create_token(build_token_config("FromFactory", "FF", false));
    assert(factory.is_token_from_factory(token), 'SHOULD_BE_FACTORY_TOKEN');
}

// Why: Ensures arbitrary external addresses cannot spoof "factory token" membership.
#[test]
fn test_factory_is_factory_token_returns_false_for_external_address() {
    let (factory, _) = setup_factory();
    let external_address: ContractAddress = 987654.try_into().unwrap();
    assert(!factory.is_token_from_factory(external_address), 'FALSE_POSITIVE_FACTORY_TOKEN');
}

// Why: Confirms constructor-set token class hash is stored and queryable by clients.
#[test]
fn test_factory_returns_configured_token_class_hash() {
    let (factory, token_class_hash) = setup_factory();
    let stored = factory.get_token_class_hash();
    assert(stored == token_class_hash, 'CLASS_HASH_MISMATCH');
}

// Why: Validates factory creates token instances with intended metadata visible on token ABI.
#[test]
fn test_factory_created_token_exposes_expected_metadata() {
    let (factory, _) = setup_factory();
    let config = build_token_config("MetadataToken", "MDT", true);
    let token_address = factory.create_token(config);
    let token = ITokenDispatcher { contract_address: token_address };

    assert(token.name() == "MetadataToken", 'BAD_NAME');
    assert(token.symbol() == "MDT", 'BAD_SYMBOL');
    assert(token.is_privacy_enabled(), 'BAD_PRIVACY_FLAG');
}
