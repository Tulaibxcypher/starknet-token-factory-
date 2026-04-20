use starknet::ContractAddress;
use super::super::types::{MintMode, WhitelistMode};

#[starknet::interface]
pub trait IToken<TState> {
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn totalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn transferFrom(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(ref self: TState, spender: ContractAddress, added_value: u256) -> bool;
    fn decrease_allowance(ref self: TState, spender: ContractAddress, subtracted_value: u256) -> bool;

    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn mint_from_privacy(ref self: TState, recipient: ContractAddress, amount: u256);
    fn get_minted_total(self: @TState) -> u256;
    fn get_max_mint_cap(self: @TState) -> u256;
    fn get_mint_mode(self: @TState) -> MintMode;

    fn burn(ref self: TState, amount: u256);
    fn burn_from(ref self: TState, account: ContractAddress, amount: u256);
    fn burn_for_privacy(ref self: TState, account: ContractAddress, amount: u256);

    fn owner(self: @TState) -> ContractAddress;
    fn pending_owner(self: @TState) -> ContractAddress;
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
    fn accept_ownership(ref self: TState);
    fn renounce_ownership(ref self: TState);

    fn get_whitelist_mode(self: @TState) -> WhitelistMode;
    fn is_whitelisted(self: @TState, addr: ContractAddress) -> bool;
    fn set_whitelist(ref self: TState, addr: ContractAddress, allowed: bool);
    fn set_whitelist_batch(ref self: TState, addrs: Array<ContractAddress>, allowed: bool);
    fn set_whitelist_mode(ref self: TState, mode: WhitelistMode);

    fn get_website(self: @TState) -> ByteArray;
    fn get_twitter(self: @TState) -> ByteArray;
    fn get_instagram(self: @TState) -> ByteArray;
    fn get_image_uri(self: @TState) -> ByteArray;
    fn get_urn(self: @TState) -> ByteArray;
    fn update_metadata(
        ref self: TState,
        website: ByteArray,
        twitter: ByteArray,
        instagram: ByteArray,
        image_uri: ByteArray,
        urn: ByteArray,
    );

    fn is_privacy_enabled(self: @TState) -> bool;
    fn set_privacy_module(ref self: TState, module: ContractAddress);
    fn transfer_privacy_module(ref self: TState, new_module: ContractAddress);
    fn accept_privacy_module(ref self: TState);
    fn get_privacy_module(self: @TState) -> ContractAddress;
    fn get_pending_privacy_module(self: @TState) -> ContractAddress;
}
