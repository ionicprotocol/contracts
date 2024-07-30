import { task } from "hardhat/config";
import { assets as modeAssets } from "../../chains/mode/assets";

task("market:set-cf:mode:main", "Sets caps on a market").setAction(async (_, { viem, run }) => {
  const COMPTROLLER = "0xfb3323e24743caf4add0fdccfb268565c0685556";
  for (const asset of modeAssets) {
    const pool = await viem.getContractAt("IonicComptroller", COMPTROLLER);
    const cToken = await pool.read.cTokensByUnderlying([asset.underlying]);
    console.log("cToken: ", cToken, asset.symbol);

    if (asset.initialCf) {
      await run("market:set:ltv", {
        marketAddress: cToken,
        ltv: asset.initialCf
      });
    }
  }
});
