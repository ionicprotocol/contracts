import { Address, encodeFunctionData, GetContractReturnType, WalletClient } from "viem";

import { addTransaction } from "../logging";
import { pythPriceOracleAbi } from "../../../generated";

import { addUnderlyingsToMpo } from "./utils";
import { PythAsset, PythDeployFnParams } from "../../types";

export const deployPythPriceOracle = async ({
  viem,
  getNamedAccounts,
  deployments,
  pythAddress,
  usdToken,
  pythAssets,
  nativeTokenUsdFeed
}: PythDeployFnParams): Promise<{ pythOracle: GetContractReturnType<typeof pythPriceOracleAbi, WalletClient> }> => {
  const { deployer } = await getNamedAccounts();
  const publicClient = await viem.getPublicClient();
  const walletClient = await viem.getWalletClient(deployer as Address);

  const mpo = await viem.getContractAt(
    "MasterPriceOracle",
    (await deployments.get("MasterPriceOracle")).address as Address
  );

  //// Pyth Oracle
  const pyth = await deployments.deploy("PythPriceOracle", {
    from: deployer,
    args: [],
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [pythAddress, nativeTokenUsdFeed, usdToken]
        },
        onUpgrade: {
          methodName: "reinitialize",
          args: [pythAddress, nativeTokenUsdFeed, usdToken]
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    },
    waitConfirmations: 1
  });

  if (pyth.transactionHash) publicClient.waitForTransactionReceipt({ hash: pyth.transactionHash as Address });
  console.log("PythPriceOracle: ", pyth.address);

  const pythOracle = await viem.getContractAt(
    "PythPriceOracle",
    (await deployments.get("PythPriceOracle")).address as Address
  );

  const pythAssetsToChange: PythAsset[] = [];
  for (const pythAsset of pythAssets) {
    const currentPriceFeed = await pythOracle.read.priceFeedIds([pythAsset.underlying]);
    if (currentPriceFeed !== pythAsset.feed) {
      pythAssetsToChange.push(pythAsset);
    }
  }
  if (pythAssetsToChange.length > 0) {
    if (((await pythOracle.read.owner()) as Address).toLowerCase() === deployer.toLowerCase()) {
      const tx = await pythOracle.write.setPriceFeeds([
        pythAssetsToChange.map((f) => f.underlying),
        pythAssetsToChange.map((f) => f.feed)
      ]);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`Set ${pythAssetsToChange.length} price feeds for PythPriceOracle at ${tx}`);
    } else {
      const tx = await walletClient.prepareTransactionRequest({
        account: (await pythOracle.read.owner()) as Address,
        to: pythOracle.address,
        data: encodeFunctionData({
          abi: pythOracle.abi,
          functionName: "setPriceFeeds",
          args: [pythAssetsToChange.map((f) => f.underlying), pythAssetsToChange.map((f) => f.feed)]
        })
      });
      addTransaction({
        to: tx.to,
        value: tx.value ? tx.value.toString() : "0",
        data: null,
        contractMethod: {
          inputs: [
            { internalType: "address[]", name: "underlyings", type: "address[]" },
            { internalType: "bytes32[]", name: "feeds", type: "bytes32[]" }
          ],
          name: "setPriceFeeds",
          payable: false
        },
        contractInputsValues: {
          underlyings: pythAssetsToChange.map((f) => f.underlying),
          feeds: pythAssetsToChange.map((f) => f.feed)
        }
      });
      console.log(`Logged Transaction to set ${pythAssetsToChange.length} price feeds for PythPriceOracle `);
    }
  }

  const underlyings = pythAssets.map((f) => f.underlying);
  await addUnderlyingsToMpo(mpo as any, underlyings, pythOracle.address, deployer, publicClient, walletClient);

  return { pythOracle: pythOracle as any };
};
