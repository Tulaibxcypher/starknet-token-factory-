# Phase 3 - Factory Contract (Deep Explanation)

## Objective
Add a contract factory that deploys token instances and keeps an on-chain registry.

## Delivered file
- `contracts/src/factory.cairo`

## Core features implemented
- Stored token class hash and factory owner.
- Unique deployment salt counter.
- `create_token(config)` deploy pipeline:
  1. read class hash
  2. increment salt
  3. serialize config
  4. call deploy syscall
  5. save token in global and per-creator maps
  6. increment counters
  7. emit `TokenCreated`
- Query helpers:
  - get class hash
  - get all tokens
  - get tokens by creator
  - get token count
  - verify if address was factory-created
- Owner upgrade function for class hash updates.
- Two-step factory ownership transfer for admin safety:
  - `transfer_factory_ownership(new_owner)`
  - `accept_factory_ownership()` by pending owner

## Architecture rule respected
Factory contains deployment/registry logic only.
It does not contain token policy logic (mint/burn/whitelist/privacy internals).

## Verification
`scarb build` passed.

## Outcome
System now supports repeatable token deployment through a single on-chain entry point.
Factory admin control now uses explicit two-step handoff to avoid accidental ownership loss.
