import { task, types } from "hardhat/config";

export default task("market:set-supply-cap", "Sets supply cap on a market")
  .addParam("admin", "Deployer account", "deployer", types.string)
  .addParam("market", "The address of the CToken", undefined, types.string)
  .addParam("maxSupply", "Maximum amount of tokens that can be supplied", undefined, types.string)
  .setAction(async ({ market, maxSupply }, { viem }) => {
    const publicClient = await viem.getPublicClient();
    const cToken = await viem.getContractAt("ICErc20", market);
    const comptroller = await cToken.read.comptroller();
    const pool = await viem.getContractAt("IonicComptroller", comptroller);

    const currentSupplyCap = await pool.read.supplyCaps([cToken.address]);
    console.log(`Current supply cap is ${currentSupplyCap}`);
    const newSupplyCap = BigInt(maxSupply);

    if (currentSupplyCap === newSupplyCap) {
      console.log("Supply cap is already set to this value");
      return;
    }

    const tx = await pool.write._setMarketSupplyCaps([[cToken.address], [newSupplyCap]]);
    await publicClient.waitForTransactionReceipt({ hash: tx });
    console.log("tx: ", tx);
    const newSupplyCapSet = await pool.read.supplyCaps([cToken.address]);
    console.log(`New supply cap set: ${newSupplyCapSet.toString()}`);
  });

task("market:set-supply-cap-whitelist", "Sets supply whitelist on a market")
  .addParam("admin", "Deployer account", "deployer", types.string)
  .addParam("market", "The address of the CToken", undefined, types.string)
  .addParam("account", "Account to be whitelisted / removed from whitelist", undefined, types.string)
  .addOptionalParam("whitelist", "Set whitelist to true ot false", true, types.boolean)
  .setAction(async ({ market, account, whitelist }, { viem }) => {
    const publicClient = await viem.getPublicClient();
    const cToken = await viem.getContractAt("ICErc20", market);
    const comptroller = await cToken.read.comptroller();
    const pool = await viem.getContractAt("IonicComptroller", comptroller);

    const currentSupplyCap = await pool.read.supplyCaps([market]);
    console.log(`Current supply cap is ${currentSupplyCap}`);

    const whitelistStatus = await pool.read.isSupplyCapWhitelisted([market, account]);
    if (whitelistStatus == whitelist) {
      console.log(`Whitelist status is already ${whitelist}`);
      return;
    } else {
      console.log(`Whitelist status is ${whitelistStatus}, setting to ${whitelist}`);
      const tx = await pool.write._supplyCapWhitelist([market, account, whitelist]);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`Whitelist status for ${account} set: ${await pool.read.isSupplyCapWhitelisted([market, account])}`);
    }
  });
