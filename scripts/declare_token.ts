import { getAccount, getProvider, readCasm, readSierra, upsertEnv, waitForTx } from "./utils.js";

async function main(): Promise<void> {
  const provider = getProvider();
  const account = getAccount(provider);

  const sierra = readSierra("TokenContract");
  const casm = readCasm("TokenContract");

  const declareResult = await account.declare({
    contract: sierra as any,
    casm: casm as any,
  });

  await waitForTx(provider, declareResult.transaction_hash);
  upsertEnv("TOKEN_CLASS_HASH", declareResult.class_hash);

  console.log(`TOKEN_CLASS_HASH=${declareResult.class_hash}`);
  console.log(`declare tx=${declareResult.transaction_hash}`);
}

main().catch((error) => {
  console.error("declare_token failed:", error);
  process.exit(1);
});
