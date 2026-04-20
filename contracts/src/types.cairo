use starknet::ContractAddress;

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, starknet::Store, PartialEq, Copy, Clone)]
pub enum MintMode {
    Fixed,
    MintOnce,
    UnlimitedWithCap,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, starknet::Store, PartialEq, Copy, Clone)]
pub enum BurnPermission {
    Nobody,
    Self_,
    AdminOnly,
}

#[allow(starknet::store_no_default_variant)]
#[derive(Drop, Serde, starknet::Store, PartialEq, Copy, Clone)]
pub enum WhitelistMode {
    Disabled,
    StrictBoth,
    SenderOnly,
}

#[derive(Drop, Serde)]
pub struct TokenConfig {
    pub name: ByteArray,
    pub symbol: ByteArray,
    pub decimals: u8,
    pub owner: ContractAddress,
    pub initial_supply: u256,
    pub max_mint_cap: u256,
    pub mint_mode: MintMode,
    pub burn_permission: BurnPermission,
    pub whitelist_mode: WhitelistMode,
    pub website: ByteArray,
    pub twitter: ByteArray,
    pub instagram: ByteArray,
    pub image_uri: ByteArray,
    pub urn: ByteArray,
    pub privacy_enabled: bool,
}
