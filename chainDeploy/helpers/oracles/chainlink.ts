import { addTransaction } from "../logging";

import { addUnderlyingsToMpo } from "./utils";
import { Address, encodeFunctionData } from "viem";
import { underlying } from "../utils";
import { ChainlinkFeedBaseCurrency } from "../../../../monorepo/packages/types";
import { ChainlinkDeployFnParams } from "../../types";

export const deployChainlinkOracle = async ({
  viem,
  getNamedAccounts,
  deployments,
  deployConfig,
  assets,
  chainlinkAssets
}: ChainlinkDeployFnParams): Promise<{ cpo: any; chainLinkv2: any }> => {
  const { deployer } = await getNamedAccounts();
  const publicClient = await viem.getPublicClient();
  const walletClient = await viem.getWalletClient(deployer as Address);
  let tx;

  //// Chainlink Oracle

  console.log("deployConfig.stableToken: ", deployConfig.stableToken);
  console.log("deployConfig.nativeTokenUsdChainlinkFeed: ", deployConfig.nativeTokenUsdChainlinkFeed);
  const cpo = await deployments.deploy("ChainlinkPriceOracleV2", {
    from: deployer,
    args: [],
    log: true,
    proxy: {
      execute: {
        init: {
          methodName: "initialize",
          args: [deployConfig.stableToken, deployConfig.nativeTokenUsdChainlinkFeed]
        }
      },
      owner: deployer,
      proxyContract: "OpenZeppelinTransparentProxy"
    },
    waitConfirmations: 1
  });
  if (cpo.transactionHash) await publicClient.waitForTransactionReceipt({ hash: cpo.transactionHash as Address });
  console.log("ChainlinkPriceOracleV2: ", cpo.address);

  const chainLinkv2 = await viem.getContractAt(
    "ChainlinkPriceOracleV2",
    (await deployments.get("ChainlinkPriceOracleV2")).address as Address
  );

  const chainlinkAssetsToChange = [];
  for (const asset of chainlinkAssets) {
    const underlyingAsset = underlying(assets, asset.symbol);
    const currentPriceFeed = await chainLinkv2.read.priceFeeds([underlyingAsset]);
    if (currentPriceFeed !== asset.aggregator) {
      chainlinkAssetsToChange.push(asset);
    }
  }

  const usdBasedFeeds = chainlinkAssetsToChange.filter(
    (asset) => asset.feedBaseCurrency === ChainlinkFeedBaseCurrency.USD
  );
  const ethBasedFeeds = chainlinkAssetsToChange.filter(
    (asset) => asset.feedBaseCurrency === ChainlinkFeedBaseCurrency.ETH
  );

  if (usdBasedFeeds.length > 0) {
    const feedCurrency = ChainlinkFeedBaseCurrency.USD;

    if (((await chainLinkv2.read.owner()) as Address).toLowerCase() === deployer.toLowerCase()) {
      tx = await chainLinkv2.write.setPriceFeeds([
        usdBasedFeeds.map((c) => underlying(assets, c.symbol)),
        usdBasedFeeds.map((c) => c.aggregator),
        feedCurrency
      ]);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`Set ${usdBasedFeeds.length} USD price feeds for ChainlinkPriceOracleV2 at ${tx}`);
    } else {
      const tx = await walletClient.prepareTransactionRequest({
        account: (await chainLinkv2.read.owner()) as Address,
        to: chainLinkv2.address,
        data: encodeFunctionData({
          abi: chainLinkv2.abi,
          functionName: "setPriceFeeds",
          args: [
            usdBasedFeeds.map((c) => underlying(assets, c.symbol)),
            usdBasedFeeds.map((c) => c.aggregator),
            feedCurrency
          ]
        })
      });
      addTransaction({
        to: tx.to,
        value: tx.value ? tx.value.toString() : "0",
        data: null,
        contractMethod: {
          inputs: [
            { internalType: "address[]", name: "underlyings", type: "address[]" },
            { internalType: "address[]", name: "feeds", type: "address[]" },
            { internalType: "uint8", name: "baseCurrency", type: "uint8" }
          ],
          name: "setPriceFeeds",
          payable: false
        },
        contractInputsValues: {
          underlyings: usdBasedFeeds.map((c) => underlying(assets, c.symbol)),
          feeds: usdBasedFeeds.map((c) => c.aggregator),
          baseCurrency: feedCurrency
        }
      });
      console.log(`Logged Transaction to set ${usdBasedFeeds.length} USD price feeds for ChainlinkPriceOracleV2`);
    }
  }
  if (ethBasedFeeds.length > 0) {
    const feedCurrency = ChainlinkFeedBaseCurrency.ETH;
    if (((await chainLinkv2.read.owner()) as Address).toLowerCase() === deployer.toLowerCase()) {
      tx = await chainLinkv2.write.setPriceFeeds([
        ethBasedFeeds.map((c) => underlying(assets, c.symbol)),
        ethBasedFeeds.map((c) => c.aggregator),
        feedCurrency
      ]);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`Set ${ethBasedFeeds.length} native price feeds for ChainlinkPriceOracleV2`);
    } else {
      tx = await walletClient.prepareTransactionRequest({
        account: (await chainLinkv2.read.owner()) as Address,
        to: chainLinkv2.address,
        data: encodeFunctionData({
          abi: chainLinkv2.abi,
          functionName: "setPriceFeeds",
          args: [
            ethBasedFeeds.map((c) => underlying(assets, c.symbol)),
            ethBasedFeeds.map((c) => c.aggregator),
            feedCurrency
          ]
        })
      });
      addTransaction({
        to: tx.to,
        value: tx.value ? tx.value.toString() : "0",
        data: null,
        contractMethod: {
          inputs: [
            { internalType: "address[]", name: "underlyings", type: "address[]" },
            { internalType: "address[]", name: "feeds", type: "address[]" },
            { internalType: "uint8", name: "baseCurrency", type: "uint8" }
          ],
          name: "setPriceFeeds",
          payable: false
        },
        contractInputsValues: {
          underlyings: ethBasedFeeds.map((c) => underlying(assets, c.symbol)),
          feeds: ethBasedFeeds.map((c) => c.aggregator),
          baseCurrency: feedCurrency
        }
      });
      console.log(`Logged Transaction to set ${ethBasedFeeds.length} ETH price feeds for ChainlinkPriceOracleV2`);
    }
  }

  const underlyings = chainlinkAssets.map((c) => underlying(assets, c.symbol));

  const mpo = await viem.getContractAt(
    "MasterPriceOracle",
    (await deployments.get("MasterPriceOracle")).address as Address
  );
  await addUnderlyingsToMpo(mpo as any, underlyings, chainLinkv2.address, deployer, publicClient, walletClient);

  const addressesProvider = await viem.getContractAt(
    "AddressesProvider",
    (await deployments.get("AddressesProvider")).address as Address
  );
  const chainLinkv2Address = await addressesProvider.read.getAddress(["ChainlinkPriceOracleV2"]);
  if (chainLinkv2Address !== chainLinkv2.address) {
    if (((await addressesProvider.read.owner()) as Address).toLowerCase() === deployer.toLowerCase()) {
      tx = await addressesProvider.write.setAddress(["ChainlinkPriceOracleV2", chainLinkv2.address]);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`setAddress ChainlinkPriceOracleV2 at ${tx}`);
    } else {
      tx = await walletClient.prepareTransactionRequest({
        account: (await addressesProvider.read.owner()) as Address,
        to: addressesProvider.address,
        data: encodeFunctionData({
          abi: addressesProvider.abi,
          functionName: "setAddress",
          args: ["ChainlinkPriceOracleV2", chainLinkv2.address]
        })
      });
      addTransaction({
        to: tx.to,
        value: tx.value ? tx.value.toString() : "0",
        data: null,
        contractMethod: {
          inputs: [
            { internalType: "string", name: "id", type: "string" },
            { internalType: "address", name: "newAddress", type: "address" }
          ],
          name: "setAddress",
          payable: false
        },
        contractInputsValues: {
          id: "ChainlinkPriceOracleV2",
          newAddress: chainLinkv2.address
        }
      });
      console.log("Logged Transaction to setAddress ChainlinkPriceOracleV2 on AddressProvider");
    }
  }

  return { cpo: cpo, chainLinkv2: chainLinkv2 };
};
