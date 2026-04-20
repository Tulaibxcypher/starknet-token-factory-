use crate::interfaces::iverifier::IVerifier;

#[starknet::contract]
pub mod MockVerifier {
    use super::IVerifier;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl MockVerifierImpl of IVerifier<ContractState> {
        fn verify(
            self: @ContractState,
            proof: Array<felt252>,
            public_inputs: Array<felt252>
        ) -> bool {
            // MVP testnet verifier: accept any non-empty proof
            proof.len() > 0
        }
    }
}
