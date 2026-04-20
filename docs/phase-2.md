# Phase 2 - Token Contract (Deep Explanation)

## Objective
Implement the core token engine with strict behavior controls.

## Delivered file
- `contracts/src/token.cairo`

## Major capabilities implemented
- ERC-20 style state and methods:
  - balances, allowances, transfers, approvals, total supply
- Owner administration:
  - owner read, pending owner read
  - two-step ownership transfer (`transfer_ownership` -> `accept_ownership`)
  - renounce ownership
- Mint policy modes:
  - Fixed
  - MintOnce
  - UnlimitedWithCap
- Burn permissions:
  - Nobody
  - Self_
  - Anyone
  - AdminOnly
- Whitelist policies:
  - Disabled
  - StrictBoth
  - SenderOnly
  - owner bypass handling
- Metadata management:
  - website, twitter, instagram, image URI, URN
- Privacy flag getter for external tools/frontends
- Custom events for state transitions

## Behavior integrity decisions
- `minted_total` is monotonic and does not reset on burns.
- Mint cap checks are enforced before state write.
- Access checks are explicit for owner-restricted methods.
- Ownership handoff is two-step to reduce misconfiguration/typo risk during admin transfer.
- Constructor rejects zero owner to prevent unmanageable deployments from genesis.
- Allowance safety guidance: default to `increase_allowance` / `decrease_allowance`; keep direct `approve` only for compatibility.

## Verification
`scarb build` passed.

## Outcome
Token contract is functional and policy-driven, ready for factory deployment flow.
