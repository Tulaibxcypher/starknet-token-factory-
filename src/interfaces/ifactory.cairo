use starknet::ContractAddress;
use super::super::types::TokenConfig;

#[starknet::interface]
pub trait IFactory<TState> {
    fn create_token(ref self: TState, config: TokenConfig) -> ContractAddress;
    fn get_token_class_hash(self: @TState) -> starknet::ClassHash;
    fn get_factory_owner(self: @TState) -> ContractAddress;
    fn get_pending_factory_owner(self: @TState) -> ContractAddress;
    fn get_tokens_by_creator(self: @TState, creator: ContractAddress) -> Array<ContractAddress>;
    fn get_tokens_by_creator_paginated(
        self: @TState, creator: ContractAddress, offset: u256, limit: u256
    ) -> Array<ContractAddress>;
    fn get_all_tokens(self: @TState) -> Array<ContractAddress>;
    fn get_all_tokens_paginated(self: @TState, offset: u256, limit: u256) -> Array<ContractAddress>;
    fn get_token_count(self: @TState) -> u256;
    fn is_token_from_factory(self: @TState, token: ContractAddress) -> bool;
    fn transfer_factory_ownership(ref self: TState, new_owner: ContractAddress);
    fn accept_factory_ownership(ref self: TState);
}
