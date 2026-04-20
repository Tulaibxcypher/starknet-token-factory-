import { Contract, type Abi } from "starknet";
import { getAccount, getProvider, readSierra, requireEnv, waitForTx } from "./utils.js";

function normalizeAddress(value: string): string {
  const trimmed = value.trim().toLowerCase();
  if (trimmed.startsWith("0x")) {
    return `0x${BigInt(trimmed).toString(16)}`;
  }
  return `0x${BigInt(trimmed).toString(16)}`;
}

async function main(): Promise<void> {
  const provider = getProvider();
  const account = getAccount(provider);

  const tokenAddress = requireEnv("TOKEN_ADDRESS");
  const privacyAddress = requireEnv("PRIVACY_ADDRESS");

  const sierra = readSierra("TokenContract");
  const abi = (sierra as { abi: Abi }).abi;
  const token = new Contract(abi, tokenAddress, account);

  const owner = await token.owner();
  const deployer = requireEnv("DEPLOYER_ADDRESS");
  const ownerNormalized = normalizeAddress(owner.toString());
  const deployerNormalized = normalizeAddress(deployer);
  if (ownerNormalized !== deployerNormalized) {
    throw new Error(
      `Deployer is not token owner. token.owner=${ownerNormalized} deployer=${deployerNormalized}`,
    );
  }

  const tx = await token.set_privacy_module(privacyAddress);
  await waitForTx(provider, tx.transaction_hash);

  console.log(`set_privacy_module tx=${tx.transaction_hash}`);
  console.log(`token=${tokenAddress}`);
  console.log(`privacy_module=${privacyAddress}`);
}

main().catch((error) => {
  console.error("link_privacy failed:", error);
  process.exit(1);
});
