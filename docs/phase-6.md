# Phase 6 - Deployment Preparation (Deep Explanation)

## Objective
Prepare reliable scripts and environment structure for testnet deployment, without touching mainnet yet.

## Delivered in this step
- Node/TypeScript script runtime setup:
  - `package.json`
  - `tsconfig.json`
- Deployment scripting baseline:
  - `scripts/utils.ts`
  - `scripts/declare_token.ts`
  - `scripts/declare_factory.ts`
  - `scripts/deploy_factory.ts`
  - `scripts/create_token.ts`
  - `scripts/interact_token.ts`
- Environment hardening:
  - expanded `.env.example`
  - added `.gitignore` to keep `.env` out of git

## What each script does
- `utils.ts`
  - loads env
  - validates required vars
  - reads compiled artifacts from `target/dev`
  - provides account/provider helpers
  - updates `.env` keys after declare/deploy
- `declare_token.ts`
  - declares `TokenContract`
  - writes `TOKEN_CLASS_HASH` to `.env`
- `declare_factory.ts`
  - declares `FactoryContract`
  - writes `FACTORY_CLASS_HASH` to `.env`
- `deploy_factory.ts`
  - deploys factory with constructor args (`token_class_hash`, `owner`)
  - writes `FACTORY_ADDRESS` to `.env`
- `create_token.ts`
  - calls `factory.create_token(config)` with a safe default config
  - prints transaction + receipt status
- `interact_token.ts`
  - basic post-deploy interaction smoke test (`mint`, `balance_of`)

## Security and workflow notes
- `.env` is now git-ignored.
- Sensitive keys stay in `.env` only.
- Scripts fail fast if required env vars are missing.
- Mainnet is still intentionally deferred.
- Frontend/client allowance guidance: prefer `increase_allowance` / `decrease_allowance` flows; avoid direct `approve` overwrite pattern unless explicitly required.

## Verification in this step
- Script files and project config were created and wired.
- Contract-side regression remained green before Phase 6 work (`snforge test -x` passing).
- Networked script execution is not run in this step because dependencies and wallet/RPC execution are phase-gated.

## Next step
Install JS dependencies and run scripts in strict order:
1. `npm install`
2. `npm run declare:token`
3. `npm run declare:factory`
4. `npm run deploy:factory`
5. `npm run create:token`
6. `npm run interact:token`


sncast --account tulaib invoke \
--network sepolia \
--contract-address 0x0262e98710ff2ae80b4037c6325ef35c1010a90c7c5471cd0428c800e14e86c1 \
--function create_token \
--arguments 'starknet_token_factory::types::TokenConfig {
name: "yayhay",
symbol: "y",
decimals: 18_u8,
owner: 0x03C0Fd85384961B12de1C31FCBB40e9E79b56019F4Bb46AC1C5E239Fa5f298f7,
initial_supply: 10000000000000000000000_u256,
max_mint_cap: 10000000000000000000000_u256,
}'ivacy_enabled: falseet_token_factory::types::WhitelistMode::Disabled,
Success: Invoke completed

Transaction Hash: 0x02227930ecad5b7a9a306dce7068813f0905fec65e236d291d60b447958ba929

To see invocation details, visit:
transaction: https://sepolia.voyager.online/tx/0x02227930ecad5b7a9a306dce7068813f0905fec65e236d291d60b447958ba929
tulaib@DESKTOP-9TIBQ8V:/mnt/c/Users/ZEE-TECH/Desktop/Semester 8/starknet_docs/starknet-token-factory$ 
