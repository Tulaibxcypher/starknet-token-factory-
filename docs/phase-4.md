# Phase 4 - Privacy Module (Deep Explanation)

## Objective
Implement a separate privacy module for shielded operations in MVP form.

## Delivered files
- `contracts/src/interfaces/iprivacy.cairo`
- `contracts/src/privacy.cairo`

## Privacy module capabilities
- Shield flow:
  - move from public balance representation to shielded commitment storage
- Unshield flow:
  - proof check (mock)
  - nullifier one-time spend check
  - release back to public side
- Private transfer flow:
  - spend nullifier + create new commitment with proof gate
- Viewing key model:
  - user registration
  - auditor-only key retrieval
- Pool activation:
  - pool is initialized active in constructor
  - no public admin toggles in current ABI

## MVP note
Proof verification uses placeholder rule (`proof.len() > 0`).
This is intentional until real verifier integration in later hardening.

## Verification
`scarb build` passed.

## Outcome
Privacy layer exists as an independent module and follows separation-of-concerns with token/factory contracts.
Owner-style admin controls are intentionally not exposed in current MVP ABI.
