use starknet::ContractAddress;

#[starknet::interface]
pub trait IPrivacy<TState> {
    fn shield(
        ref self: TState,
        amount: u256,
        commitment: felt252,
        encrypted_viewing_key: felt252,
    );
    fn unshield(
        ref self: TState,
        commitment: felt252,
        nullifier: felt252,
        proof: Array<felt252>,
        recipient: ContractAddress,
        amount: u256,
    );
    fn private_transfer(
        ref self: TState,
        nullifier: felt252,
        new_commitment: felt252,
        proof: Array<felt252>,
    );
    fn register_viewing_key(ref self: TState, encrypted_key: felt252);
    fn get_viewing_key(self: @TState, user: ContractAddress) -> felt252;
    fn get_total_shielded(self: @TState) -> u256;
    fn is_nullifier_spent(self: @TState, nullifier: felt252) -> bool;
}
