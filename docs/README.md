# Starknet Token Factory - Build Notes

This folder explains what was done phase-by-phase in plain language.

## Reading Order
1. `phase-0.md` - setup and environment
2. `phase-1.md` - shared types + interfaces
3. `phase-2.md` - token contract core logic
4. `phase-3.md` - factory contract
5. `phase-4.md` - privacy module (MVP)
6. `phase-5.md` - full integration test completion
7. `phase-6.md` - deployment preparation scripts and env hardening

## Current Project State
- Contracts implemented for phases 1 to 4.
- Two-step ownership is implemented across token, factory, and privacy contracts.
- Phase 5 tests are implemented and passing (38/38 current suite).
- Phase 6 scripting baseline is now in progress.
- Mainnet deployment is intentionally postponed until final validation.

## Important Tooling Notes
- Use `snforge test` for tests.
- `scarb test` is not the right primary runner in this setup.
- WSL toolchain is the reliable path for Scarb/snforge commands.
