# Phase 5 - Testing (Deep Explanation)

## Objective
Validate all token/factory/privacy rules with repeatable automated tests.

## Current progress
- Full integration suites implemented with real deployment + behavior assertions:
  - `tests/token_tests.cairo` -> 14 passing tests
  - `tests/factory_tests.cairo` -> 9 passing tests
  - `tests/privacy_tests.cairo` -> 7 passing tests
- Total: 30 passing tests.

## Current blocker addressed
A test-runner mismatch existed:
- `snforge` binary was 0.58.x
- `snforge_std` dependency was pinned to old 0.27
This mismatch can cause `#[test]` plugin/attribute errors.

## Fix applied
`Scarb.toml` updated:
- `snforge_std = "0.58.1"`

## How to run tests (recommended)
```bash
export PATH="/home/tulaib/.asdf/installs/scarb/2.16.1/bin:$PATH"
cd "/mnt/c/Users/ZEE-TECH/Desktop/Semester 8/starknet_docs/starknet-token-factory"
/home/tulaib/.asdf/installs/starknet-foundry/0.58.1/bin/snforge test
```

## Final verification command
```bash
export PATH="/home/tulaib/.asdf/installs/scarb/2.16.1/bin:/home/tulaib/.local/bin:$PATH"
cd "/mnt/c/Users/ZEE-TECH/Desktop/Semester 8/starknet_docs/starknet-token-factory"
/home/tulaib/.asdf/installs/starknet-foundry/0.58.1/bin/snforge test -x
```

## Outcome
Phase 5 is complete and stable. The suite passes fully and is ready to support Phase 6 deployment work.
