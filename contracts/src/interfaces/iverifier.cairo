#[starknet::interface]
pub trait IVerifier<TState> {
    fn verify(
        self: @TState,
        proof: Array<felt252>,
        public_inputs: Array<felt252>
    ) -> bool;
}
