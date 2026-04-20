import { CairoCustomEnum, Contract, type Abi } from "starknet";
import { getAccount, readSierra, requireEnv, waitForTx } from "./utils.js";
import { RpcProvider } from "starknet";

type TokenConfig = {
  name: string;
  symbol: string;
  decimals: number;
  owner: string;
  initial_supply: { low: string; high: string };
  max_mint_cap: { low: string; high: string };
  mint_mode: CairoCustomEnum;
  burn_permission: CairoCustomEnum;
  whitelist_mode: CairoCustomEnum;
  website: string;
  twitter: string;
  instagram: string;
  image_uri: string;
  urn: string;
  privacy_enabled: boolean;
};

function toU256(value: bigint): { low: string; high: string } {
  const lowMask = (1n << 128n) - 1n;
  const low = value & lowMask;
  const high = value >> 128n;
  return { low: `0x${low.toString(16)}`, high: `0x${high.toString(16)}` };
}

function parseSupplyUnits(raw: string | undefined): bigint {
  if (!raw) return 1_000n;
  return BigInt(raw);
}

function buildDefaultConfig(owner: string): TokenConfig {
  const tokenName = process.env.TOKEN_NAME?.trim() || "Factory Token";
  const tokenSymbol = process.env.TOKEN_SYMBOL?.trim() || "FTK";
  const supplyUnits = parseSupplyUnits(process.env.TOKEN_INITIAL_SUPPLY_UNITS);
  const capUnits = parseSupplyUnits(process.env.TOKEN_MAX_CAP_UNITS) || supplyUnits * 10n;
  const decimals = Number(process.env.TOKEN_DECIMALS?.trim() || "18");
  const scale = 10n ** BigInt(decimals);
  const initialSupply = supplyUnits * scale;
  const maxCap = capUnits * scale;

  // Default to privacy-enabled to avoid accidentally creating non-privacy tokens.
  const privacyEnabled = (process.env.PRIVACY_ENABLED?.trim() || "true").toLowerCase() === "true";
  const burnPermission = new CairoCustomEnum({ Self_: {} });

  return {
    name: tokenName,
    symbol: tokenSymbol,
    decimals,
    owner,
    initial_supply: toU256(initialSupply),
    max_mint_cap: toU256(maxCap),
    mint_mode: new CairoCustomEnum({ UnlimitedWithCap: {} }),
    burn_permission: burnPermission,
    whitelist_mode: new CairoCustomEnum({ Disabled: {} }),
    website: "https://example.com",
    twitter: "@factory_token",
    instagram: "@factory_token",
    image_uri: "ipfs://replace-with-real-image-uri",
    urn: "urn:starknet:factory-token:v1",
    privacy_enabled: privacyEnabled,
  };
}

function getRpcCandidates(): string[] {
  const primary = process.env.STARKNET_RPC_URL?.trim();
  const fallback = process.env.STARKNET_RPC_FALLBACK_URL?.trim();
  const alchemyDemo = "https://starknet-sepolia.g.alchemy.com/starknet/version/rpc/v0_8/demo";
  return Array.from(new Set([primary, fallback, alchemyDemo].filter(Boolean) as string[]));
}

async function runWithRpc(nodeUrl: string): Promise<void> {
  const provider = new RpcProvider({ nodeUrl });
  const account = getAccount(provider);
  const factoryAddress = requireEnv("FACTORY_ADDRESS");
  const owner = process.env.TOKEN_OWNER?.trim() || requireEnv("DEPLOYER_ADDRESS");

  const sierra = readSierra("FactoryContract");
  const abi = (sierra as { abi: Abi }).abi;
  const factory = new Contract(abi, factoryAddress, account);

  const config = buildDefaultConfig(owner);
  console.log(`create_token config: name=${config.name} symbol=${config.symbol} privacy_enabled=${config.privacy_enabled}`);
  const callResult = await factory.create_token(config);
  await waitForTx(provider, callResult.transaction_hash);

  const receipt = await provider.getTransactionReceipt(callResult.transaction_hash);
  const executionStatus =
    "execution_status" in receipt ? String(receipt.execution_status) : "unknown";
  console.log(`create token tx=${callResult.transaction_hash}`);
  console.log("receipt status:", executionStatus);
  console.log(
    "Token address should be read from TokenCreated event in this receipt (factory-emitted event).",
  );
}

async function main(): Promise<void> {
  const candidates = getRpcCandidates();
  if (candidates.length === 0) {
    throw new Error("No RPC URL found. Set STARKNET_RPC_URL in .env.");
  }

  let lastError: unknown;
  for (const nodeUrl of candidates) {
    try {
      console.log(`Trying RPC: ${nodeUrl}`);
      await runWithRpc(nodeUrl);
      return;
    } catch (error) {
      lastError = error;
      const message = error instanceof Error ? error.message : String(error);
      const shouldRetry = message.includes("fetch failed");
      if (!shouldRetry) {
        throw error;
      }
      console.warn(`RPC failed: ${nodeUrl}`);
    }
  }

  throw lastError;
}

main().catch((error) => {
  console.error("create_token failed:", error);
  process.exit(1);
});
