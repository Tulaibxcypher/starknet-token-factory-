import { CallData } from "starknet";
import {
  getAccount,
  getProvider,
  readCasm,
  readSierra,
  requireEnv,
  upsertEnv,
  waitForTx,
} from "./utils.js";

async function main(): Promise<void> {
  const provider = getProvider();
  const account = getAccount(provider);

  const tokenAddress = requireEnv("TOKEN_ADDRESS");
  const auditor = process.env.AUDITOR_ADDRESS?.trim() || requireEnv("DEPLOYER_ADDRESS");
  const verifierAddress = requireEnv("VERIFIER_ADDRESS");
  const merkleRoot = process.env.MERKLE_ROOT?.trim() || "0x0";
  const domainSeparator = process.env.PRIVACY_DOMAIN_SEPARATOR?.trim() || "0x505249564143595f5631"; // "PRIVACY_V1"

  const sierra = readSierra("PrivacyContract");
  const casm = readCasm("PrivacyContract");

  let privacyClassHash = process.env.PRIVACY_CLASS_HASH?.trim();
  let declareTxHash: string | undefined;

  if (!privacyClassHash) {
    try {
      const declareResult = await account.declare({
        contract: sierra as any,
        casm: casm as any,
      });
      await waitForTx(provider, declareResult.transaction_hash);
      privacyClassHash = declareResult.class_hash;
      declareTxHash = declareResult.transaction_hash;
      upsertEnv("PRIVACY_CLASS_HASH", privacyClassHash);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const mismatchMatch = message.match(/class with hash (0x[0-9a-f]+)/i);
      const alreadyDeclaredMatch = message.match(/class hash (0x[0-9a-f]+) is already declared/i);
      const recoveredClassHash = mismatchMatch?.[1] || alreadyDeclaredMatch?.[1];

      if (!recoveredClassHash) {
        throw error;
      }

      privacyClassHash = recoveredClassHash;
      upsertEnv("PRIVACY_CLASS_HASH", privacyClassHash);
      console.warn(
        `declare skipped: using already-declared PRIVACY_CLASS_HASH=${privacyClassHash}`,
      );
    }
  }

  const deployResult = await account.deployContract({
    classHash: privacyClassHash,
    constructorCalldata: CallData.compile({
      token_address: tokenAddress,
      auditor,
      verifier_address: verifierAddress,
      merkle_root: merkleRoot,
      domain_separator: domainSeparator,
    }),
  });
  await waitForTx(provider, deployResult.transaction_hash);

  const contractAddress = Array.isArray(deployResult.contract_address)
    ? deployResult.contract_address[0]
    : deployResult.contract_address;

  if (!contractAddress) {
    throw new Error("Privacy deployment did not return a contract address.");
  }

  upsertEnv("PRIVACY_ADDRESS", contractAddress);

  console.log(`PRIVACY_CLASS_HASH=${privacyClassHash}`);
  console.log(`PRIVACY_ADDRESS=${contractAddress}`);
  console.log(`VERIFIER_ADDRESS=${verifierAddress}`);
  console.log(`MERKLE_ROOT=${merkleRoot}`);
  console.log(`PRIVACY_DOMAIN_SEPARATOR=${domainSeparator}`);
  if (declareTxHash) {
    console.log(`declare tx=${declareTxHash}`);
  }
  console.log(`deploy tx=${deployResult.transaction_hash}`);
}

main().catch((error) => {
  console.error("deploy_privacy failed:", error);
  process.exit(1);
});
