import { getAccount, getProvider, readCasm, readSierra, upsertEnv, waitForTx } from "./utils.js";

async function main(): Promise<void> {
  const provider = getProvider();
  const account = getAccount(provider);

  const sierra = readSierra("FactoryContract");
  const casm = readCasm("FactoryContract");

  const declareResult = await account.declare({
    contract: sierra as any,
    casm: casm as any,
  });

  await waitForTx(provider, declareResult.transaction_hash);
  upsertEnv("FACTORY_CLASS_HASH", declareResult.class_hash);

  console.log(`FACTORY_CLASS_HASH=${declareResult.class_hash}`);
  console.log(`declare tx=${declareResult.transaction_hash}`);
}

main().catch((error) => {
  console.error("declare_factory failed:", error);
  process.exit(1);
});
