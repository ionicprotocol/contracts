import { task } from "hardhat/config";
import { Address, parseEther } from "viem";
import { assets as baseAssets } from "../../../../monorepo/packages/chains/src/base/assets";
import { assetSymbols } from "../../../../monorepo/packages/types";
import { COMPTROLLER } from ".";

task("market:base:add-rewards-to-existing-flywheel", "Sets caps on a market").setAction(
  async (_, { viem, run, deployments, getNamedAccounts }) => {
    const { deployer } = await getNamedAccounts();
    const publicClient = await viem.getPublicClient();

    const ionbsdETH = "0x3d9669de9e3e98db41a1cbf6dc23446109945e3c";
    const bsdETH = "0xCb327b99fF831bF8223cCEd12B1338FF3aA322Ff";
    const ioneUSD = "0x9c2a4f9c5471fd36be3bbd8437a33935107215a1";
    const eUSD = "0xCfA3Ef56d303AE4fAabA0592388F19d7C3399FB4";
    const hyUSD = "0xCc7FF230365bD730eE4B352cC2492CEdAC49383e"
    const ionhyUSD = "0x751911bDa88eFcF412326ABE649B7A3b28c4dEDe"
    const ION = "0x3eE5e23eEE121094f1cFc0Ccc79d6C809Ebd22e5";
    const RSR = "0xab36452dbac151be02b16ca17d8919826072f64a";
    const pool = "0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13";
    const comptrollerAddress = "0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13";
    const markets = `${eUSD}`;
    const reward = "35000";

    /*
    // Upgrade markets to the new implementation
    console.log(`Upgrading market: ${ionhyUSD} to CErc20RewardsDelegate`);
    await run("market:upgrade", {
      comptroller,
      underlying: hyUSD,
      implementationAddress: (await deployments.get("CErc20RewardsDelegate")).address,
      signer: deployer
    });

    const publicClient = await viem.getPublicClient();
    const { implementationAddress, comptroller: comptrollerAddress, underlying, signer: namedSigner } = taskArgs;

    const comptroller = await viem.getContractAt("IonicComptroller", comptrollerAddress as Address);

    const allMarkets = await comptroller.read.getAllMarkets();

    const cTokenInstances = await Promise.all(
      allMarkets.map(async (marketAddress) => {
        return await viem.getContractAt("ICErc20PluginRewards", marketAddress);
      })
    );

    let cTokenInstance;
    for (let index = 0; index < cTokenInstances.length; index++) {
      const thisUnderlying = await cTokenInstances[index].read.underlying();
      if (!cTokenInstance && thisUnderlying.toLowerCase() === hyUSD.toLowerCase()) {
        cTokenInstance = cTokenInstances[index];
      }
    }
    if (!cTokenInstance) {
      throw Error(`No market corresponds to this underlying: ${hyUSD}`);
    }

    const implementationData = "0x";
    const implementationAddress = (await deployments.get("CErc20RewardsDelegate")).address;
    console.log(`Setting implementation to ${implementationAddress}`);
    const setImplementationTx = await cTokenInstance.write._setImplementationSafe([
      implementationAddress,
      implementationData
    ]);

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: setImplementationTx
    });
    if (receipt.status !== "success") {
      throw `Failed set implementation to ${implementationAddress}`;
    }
    console.log(
      `Implementation successfully set to ${implementationAddress}: ${setImplementationTx}`
    );
    */

    // Sending tokens
    const ionToken = await viem.getContractAt("EIP20Interface", ION);
    const balance = await ionToken.read.balanceOf([ioneUSD]);
    if (balance < parseEther(reward)) {
      await ionToken.write.transfer([ioneUSD, parseEther(reward)]);
    }

    // Approving token sepening for fwRewards contract
    const flywheel = await viem.getContractAt(
      "IonicFlywheelBorrow",
      (await deployments.get("IonicFlywheelBorrow_Borrow_ION")).address as Address
    );

    const marketAddresses: Address[] = taskArgs.markets.split(",");
    for (const marketAddress of marketAddresses) {
      const market = await viem.getContractAt("CErc20RewardsDelegate", marketAddress);
      const fwRewards = await flywheel.read.flywheelRewards();
      const rewardToken = await flywheel.read.rewardToken();
      const tx = await market.write.approve([rewardToken, fwRewards]);
      console.log(`mining tx ${tx}`);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`approved flywheel ${flywheel.address} to pull reward tokens from market ${marketAddress}`);
    }
    
    // Adding strategies to flywheel
    const strategyAddresses = markets.split(",");
    const allFlywheelStrategies = (await flywheel.read.getAllStrategies()) as Address[];
    for (const strategy of strategyAddresses) {
      if (!allFlywheelStrategies.map((s) => s.toLowerCase()).includes(strategy.toLowerCase())) {
        console.log(`Adding strategy ${strategy} to flywheel ${flywheel.address}`);
        const addTx = await flywheel.write.addStrategyForRewards([strategy]);
        await publicClient.waitForTransactionReceipt({ hash: addTx });
        console.log(`Added strategy (${strategy}) to flywheel (${flywheel.address})`);
      } else console.log(`Strategy (${strategy}) was already added to flywheel (${flywheel.address})`);
    }
  }
);

task("market:base:deploy-flywheel-and-add-rewards", "Sets caps on a market").setAction(
  async (_, { viem, run, deployments, getNamedAccounts }) => {
    const { deployer } = await getNamedAccounts();
    const publicClient = await viem.getPublicClient();

    const ionbsdETH = "0x3d9669de9e3e98db41a1cbf6dc23446109945e3c";
    const bsdETH = "0xCb327b99fF831bF8223cCEd12B1338FF3aA322Ff";
    const ioneUSD = "0x9c2a4f9c5471fd36be3bbd8437a33935107215a1";
    const eUSD = "0xCfA3Ef56d303AE4fAabA0592388F19d7C3399FB4";
    const hyUSD = "0xCc7FF230365bD730eE4B352cC2492CEdAC49383e"
    const ionhyUSD = "0x751911bDa88eFcF412326ABE649B7A3b28c4dEDe"
    const ION = "0x3eE5e23eEE121094f1cFc0Ccc79d6C809Ebd22e5";
    const RSR = "0xab36452dbac151be02b16ca17d8919826072f64a";
    const pool = "0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13";
    const comptrollerAddress = "0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13";
    const markets = `${hyUSD}`;
    const reward = "3750";

    /*
    // Upgrade markets to the new implementation
    console.log(`Upgrading market: ${ionhyUSD} to CErc20RewardsDelegate`);
    await run("market:upgrade", {
      comptroller,
      underlying: hyUSD,
      implementationAddress: (await deployments.get("CErc20RewardsDelegate")).address,
      signer: deployer
    });

    const publicClient = await viem.getPublicClient();
    const { implementationAddress, comptroller: comptrollerAddress, underlying, signer: namedSigner } = taskArgs;

    const comptroller = await viem.getContractAt("IonicComptroller", comptrollerAddress as Address);

    const allMarkets = await comptroller.read.getAllMarkets();

    const cTokenInstances = await Promise.all(
      allMarkets.map(async (marketAddress) => {
        return await viem.getContractAt("ICErc20PluginRewards", marketAddress);
      })
    );

    let cTokenInstance;
    for (let index = 0; index < cTokenInstances.length; index++) {
      const thisUnderlying = await cTokenInstances[index].read.underlying();
      if (!cTokenInstance && thisUnderlying.toLowerCase() === hyUSD.toLowerCase()) {
        cTokenInstance = cTokenInstances[index];
      }
    }
    if (!cTokenInstance) {
      throw Error(`No market corresponds to this underlying: ${hyUSD}`);
    }

    const implementationData = "0x";
    const implementationAddress = (await deployments.get("CErc20RewardsDelegate")).address;
    console.log(`Setting implementation to ${implementationAddress}`);
    const setImplementationTx = await cTokenInstance.write._setImplementationSafe([
      implementationAddress,
      implementationData
    ]);

    const receipt = await publicClient.waitForTransactionReceipt({
      hash: setImplementationTx
    });
    if (receipt.status !== "success") {
      throw `Failed set implementation to ${implementationAddress}`;
    }
    console.log(
      `Implementation successfully set to ${implementationAddress}: ${setImplementationTx}`
    );
    */

    // Sending tokens
    const ionToken = await viem.getContractAt("EIP20Interface", ION);
    const balance = await ionToken.read.balanceOf([ionhyUSD]);
    if (balance < parseEther(reward)) {
      await ionToken.write.transfer([ionhyUSD, parseEther(reward)]);
    }

    // Deploying flywheel 
    let name = "ION";
    let booster = "";
    let rewardToken = ION;
    let epochDuration = 2588400; //30*(24*60*60)-60*60 29days 23 hours
    let flywheelBoosterAddress;
    let contractName;

    if (booster != "") {
      flywheelBoosterAddress = (await deployments.get(booster)).address as Address;
    } else flywheelBoosterAddress = zeroAddress;

    if (name.includes("Borrow")) {
      contractName = "IonicFlywheelBorrow";
    } else contractName = "IonicFlywheel";

    const flywheel = await deployments.deploy(`${contractName}_${name}`, {
      contract: contractName,
      from: deployer,
      log: true,
      proxy: {
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [rewardToken, zeroAddress, flywheelBoosterAddress, deployer]
          }
        },
        owner: deployer
      },
      waitConfirmations: 1
    });

    console.log(`Deployed flywheel: ${flywheel.address}`);
    
    // Deploying flywheel rewards
    const rewards = await deployments.deploy(`IonicFlywheelDynamicRewards_${name}`, {
      contract: "IonicFlywheelDynamicRewards",
      from: deployer,
      log: true,
      args: [
        flywheel.address, // flywheel
        epochDuration // epoch duration
      ],
      waitConfirmations: 1
    });
    console.log(`Deployed flywheel rewards: ${rewards.address}`);

    const tx = await flywheel.write.setFlywheelRewards([rewards.address as Address]);
    await publicClient.waitForTransactionReceipt({ hash: tx });
    console.log(`Set rewards (${rewards.address}) to flywheel (${flywheel.address})`);

    // Adding strategies to flywheel
    const strategyAddresses = strategies.split(",");
    const allFlywheelStrategies = (await flywheel.read.getAllStrategies()) as Address[];
    for (const strategy of strategyAddresses) {
      if (!allFlywheelStrategies.map((s) => s.toLowerCase()).includes(strategy.toLowerCase())) {
        console.log(`Adding strategy ${strategy} to flywheel ${flywheel.address}`);
        const addTx = await flywheel.write.addStrategyForRewards([strategy]);
        await publicClient.waitForTransactionReceipt({ hash: addTx });

        console.log(`Added strategy (${strategy}) to flywheel (${flywheel.address})`);
      } else console.log(`Strategy (${strategy}) was already added to flywheel (${flywheel.address})`);
    }

    // Adding flywheel to comptroller
    const comptroller = await viem.getContractAt("IonicComptroller", pool);
    const rewardsDistributors = (await comptroller.read.getRewardsDistributors()) as Address[];
    if (!rewardsDistributors.map((s) => s.toLowerCase()).includes(flywheel.address.toLowerCase())) {
      const addTx = await comptroller.write._addRewardsDistributor([flywheel.address]);
      await publicClient.waitForTransactionReceipt({ hash: addTx });
      console.log({ addTx });
    } else {
      console.log(`Flywheel ${flywheel.address} already added to pool ${pool}`);
    }
    console.log(`Added flywheel (${flywheel.address}) to pool (${pool})`);

    // Approving token sepening for fwRewards contract
    const marketAddresses: Address[] = taskArgs.markets.split(",");
    for (const marketAddress of marketAddresses) {
      const market = await viem.getContractAt("CErc20RewardsDelegate", marketAddress);
      const fwRewards = await flywheel.read.flywheelRewards();
      const rewardToken = await flywheel.read.rewardToken();
      const tx = await market.write.approve([rewardToken, fwRewards]);
      console.log(`mining tx ${tx}`);
      await publicClient.waitForTransactionReceipt({ hash: tx });
      console.log(`approved flywheel ${flywheel.address} to pull reward tokens from market ${marketAddress}`);
    }
  }
);