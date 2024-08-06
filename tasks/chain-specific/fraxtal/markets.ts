import { task } from "hardhat/config";
import { assets } from "../../../../monorepo/packages/chains/src/fraxtal/assets";
import { assetSymbols } from "../../../../monorepo/packages/types";
import { COMPTROLLER } from ".";

task("markets:deploy:fraxtal:main", "deploy base market").setAction(async (_, { viem, run }) => {
  const assetsToDeploy: string[] = [
    //assetSymbols.WETH,
    assetSymbols.wFRXETH,
    assetSymbols.FRAX,
    assetSymbols.FXS
  ];
  for (const asset of assets.filter((asset) => assetsToDeploy.includes(asset.symbol))) {
    await run("market:deploy", {
      signer: "deployer",
      cf: "0",
      underlying: asset.underlying,
      comptroller: COMPTROLLER,
      symbol: "ion" + asset.symbol,
      name: `Ionic ${asset.name}`
    });
    const pool = await viem.getContractAt("IonicComptroller", COMPTROLLER);
    const cToken = await pool.read.cTokensByUnderlying([asset.underlying]);
    console.log(`Deployed ${asset.symbol} at ${cToken}`);

    if (asset.initialSupplyCap) {
      await run("market:set-supply-cap", {
        market: cToken,
        maxSupply: asset.initialSupplyCap
      });
    }

    if (asset.initialBorrowCap) {
      await run("market:set-borrow-cap", {
        market: cToken,
        maxBorrow: asset.initialBorrowCap
      });
    }
  }
});
