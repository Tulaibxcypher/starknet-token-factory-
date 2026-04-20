import { config as loadEnv } from "dotenv";
import { Account, RpcProvider } from "starknet";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

loadEnv();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, "..");
const ENV_PATH = path.join(PROJECT_ROOT, ".env");
const TARGET_DEV = path.join(PROJECT_ROOT, "target", "dev");

export function requireEnv(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export function getProvider(): RpcProvider {
  return new RpcProvider({
    nodeUrl: requireEnv("STARKNET_RPC_URL"),
  });
}

export function getAccount(provider: RpcProvider): Account {
  return new Account(
    provider,
    requireEnv("DEPLOYER_ADDRESS"),
    requireEnv("DEPLOYER_PRIVATE_KEY"),
  );
}

export function readJson<T>(filePath: string): T {
  if (!existsSync(filePath)) {
    throw new Error(`File not found: ${filePath}`);
  }
  return JSON.parse(readFileSync(filePath, "utf8")) as T;
}

export function getArtifactPaths(contractName: "TokenContract" | "FactoryContract" | "PrivacyContract"): {
  sierraPath: string;
  casmPath: string;
} {
  const prefix = `starknet_token_factory_${contractName}`;
  return {
    sierraPath: path.join(TARGET_DEV, `${prefix}.contract_class.json`),
    casmPath: path.join(TARGET_DEV, `${prefix}.compiled_contract_class.json`),
  };
}

export function readSierra(contractName: "TokenContract" | "FactoryContract" | "PrivacyContract"): unknown {
  const { sierraPath } = getArtifactPaths(contractName);
  return readJson<unknown>(sierraPath);
}

export function readCasm(contractName: "TokenContract" | "FactoryContract" | "PrivacyContract"): unknown {
  const { casmPath } = getArtifactPaths(contractName);
  return readJson<unknown>(casmPath);
}

export function upsertEnv(key: string, value: string): void {
  const nextLine = `${key}=${value}`;
  if (!existsSync(ENV_PATH)) {
    writeFileSync(ENV_PATH, `${nextLine}\n`, "utf8");
    return;
  }

  const current = readFileSync(ENV_PATH, "utf8");
  const pattern = new RegExp(`^${key}=.*$`, "m");
  const next = pattern.test(current)
    ? current.replace(pattern, nextLine)
    : `${current.trimEnd()}\n${nextLine}\n`;

  writeFileSync(ENV_PATH, next, "utf8");
}

export async function waitForTx(provider: RpcProvider, txHash: string): Promise<void> {
  await provider.waitForTransaction(txHash, { retryInterval: 1000 });
}
