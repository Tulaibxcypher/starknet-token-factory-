# Privacy Quickstart (Per Token)

This project already supports a privacy module (`PrivacyContract`) for each token.

## 1) Prepare `.env`

Set at minimum:

- `STARKNET_RPC_URL`
- `DEPLOYER_ADDRESS`
- `DEPLOYER_PRIVATE_KEY`
- `PRIVACY_ENABLED=true` before creating the token

Why `PRIVACY_ENABLED=true` matters:
- `create_token.ts` will use `burn_permission=Anyone` so `shield()` can burn via allowance.

## 2) Build and deploy base contracts

```bash
npm run build:contracts
npm run declare:token
npm run declare:factory
npm run deploy:factory
```

## 3) Create a privacy-enabled token

```bash
npm run create:token
```

Then set `TOKEN_ADDRESS` in `.env` from the `TokenCreated` event.

## 4) Deploy privacy contract for that token

```bash
npm run deploy:privacy
```

This writes:
- `PRIVACY_CLASS_HASH`
- `PRIVACY_ADDRESS`

## 5) Link token -> privacy module

```bash
npm run link:privacy
```

This calls `token.set_privacy_module(PRIVACY_ADDRESS)`.

## 6) User flow (privacy address style)

1. User approves privacy contract to burn:
   - `token.approve(PRIVACY_ADDRESS, amount)`
2. User shields:
   - `privacy.shield(amount, commitment, encrypted_viewing_key)`
3. User transfers privately:
   - `privacy.private_transfer(nullifier, new_commitment, proof)`
4. User unshields:
   - `privacy.unshield(nullifier, proof, recipient, amount)`

## Notes

- Current proof check in `privacy.cairo` is MVP (`proof.len() > 0`), not production ZK verification.
- For real privacy, replace this with a real verifier contract.
