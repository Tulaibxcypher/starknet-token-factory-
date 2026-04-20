import { CallData } from "starknet";
import { getAccount, getProvider, requireEnv, upsertEnv, waitForTx } from "./utils.js";

async function main(): Promise<void> {
  const provider = getProvider();
  const account = getAccount(provider);

  const factoryClassHash = requireEnv("FACTORY_CLASS_HASH");
  const tokenClassHash = requireEnv("TOKEN_CLASS_HASH");
  const owner = requireEnv("DEPLOYER_ADDRESS");

  const deployResult = await account.deployContract({
    classHash: factoryClassHash,
    constructorCalldata: CallData.compile({
      token_class_hash: tokenClassHash,
      owner,
    }),
  });

  await waitForTx(provider, deployResult.transaction_hash);

  const contractAddress = Array.isArray(deployResult.contract_address)
    ? deployResult.contract_address[0]
    : deployResult.contract_address;

  if (!contractAddress) {
    throw new Error("Factory deployment did not return a contract address.");
  }

  upsertEnv("FACTORY_ADDRESS", contractAddress);
  console.log(`FACTORY_ADDRESS=${contractAddress}`);
  console.log(`deploy tx=${deployResult.transaction_hash}`);
}

main().catch((error) => {
  console.error("deploy_factory failed:", error);
  process.exit(1);
});
