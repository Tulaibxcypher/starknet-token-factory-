# Phase 0 - Environment Setup (Deep Explanation)

## Objective
Create a stable development base so every later phase can be built and tested without environment-related blockers.

## What was created
- Project structure aligned with the guide:
  - `contracts/src` and `contracts/src/interfaces`
  - `scripts`
  - `tests`
  - `artifacts`
- Base files:
  - `Scarb.toml`
  - `.env.example`
  - `.env`
  - `README.md`
- Workspace guide copy was kept for single-source planning.

## Why `src` link exists
Scarb expects `src/` by default. The guide expects `contracts/src/`.
To satisfy both, a link was created: `src -> contracts/src`.
This keeps your guide structure while allowing builds to work normally.

## Tool verification done
- Node runtime checked and valid.
- Scarb and sncast located and validated in WSL.

## Outcome
Environment is build-ready and reproducible.
No phase logic was written here; only foundation and tooling reliability were established.
