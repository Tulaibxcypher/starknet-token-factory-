import { Contract, type Abi } from "starknet";
import { getAccount, getProvider, readSierra, requireEnv, waitForTx } from "./utils.js";

function normalizeAddress(value: string): string {
  const trimmed = value.trim().toLowerCase();
  if (trimmed.startsWith("0x")) {
    return `0x${BigInt(trimmed).toString(16)}`;
  }
  return `0x${BigInt(trimmed).toString(16)}`;
}

function toU256(value: bigint): { low: string; high: string } {
  const lowMask = (1n << 128n) - 1n;
  const low = value & lowMask;
  const high = value >> 128n;
  return { low: `0x${low.toString(16)}`, high: `0x${high.toString(16)}` };
}

async function main(): Promise<void> {
  const provider = getProvider();
  const account = getAccount(provider);

  const tokenAddress = requireEnv("TOKEN_ADDRESS");
  const sierra = readSierra("TokenContract");
  const abi = (sierra as { abi: Abi }).abi;
  const token = new Contract(abi, tokenAddress, account);

  const deployer = requireEnv("DEPLOYER_ADDRESS");
  const mintTo = process.env.MINT_TO?.trim() || deployer;
  const decimals = Number(process.env.TOKEN_DECIMALS?.trim() || "18");
  const mintUnits = BigInt(process.env.MINT_AMOUNT_UNITS?.trim() || "100");
  const mintAmount = toU256(mintUnits * 10n ** BigInt(decimals));

  const tokenOwner = await token.owner();
  const tokenOwnerNormalized = normalizeAddress(tokenOwner.toString());
  const deployerNormalized = normalizeAddress(deployer);
  if (tokenOwnerNormalized !== deployerNormalized) {
    throw new Error(
      `Deployer is not token owner. token.owner=${tokenOwnerNormalized} deployer=${deployerNormalized}`,
    );
  }

  const mintTx = await token.mint(mintTo, mintAmount);
  await waitForTx(provider, mintTx.transaction_hash);
  console.log(`mint tx=${mintTx.transaction_hash}`);

  const balance = await token.balance_of(mintTo);
  console.log(`balance(${mintTo}):`, balance.toString());
}

main().catch((error) => {
  console.error("interact_token failed:", error);
  process.exit(1);
});
