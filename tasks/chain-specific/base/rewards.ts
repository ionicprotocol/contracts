import { task, types } from "hardhat/config";
import { Address, parseEther, zeroAddress } from "viem";

task("market:base:add-rewards-to-existing-flywheel", "Adds rewards to existing flywheel")
.addParam("market", "market address", undefined, types.string)
.addParam("rewardAmount", "the amount of tokens streamed to first epoch", undefined, types.string)
.addParam("reward", "token address of reward token", undefined, types.string)
.setAction(
  async ({market, rewardAmount, reward}, { viem, run, deployments, getNamedAccounts }) => {
    const { deployer } = await getNamedAccounts();
    const publicClient = await viem.getPublicClient();
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
    const ionToken = await viem.getContractAt("EIP20Interface", reward);
    const balance = await ionToken.read.balanceOf([market]);
    if (balance < parseEther(rewardAmount)) {
      await ionToken.write.transfer([market, parseEther(rewardAmount)]);
    }

    // Approving token sepening for fwRewards contract
    const flywheel = await viem.getContractAt(
      "IonicFlywheel",
      (await deployments.get("IonicFlywheel_ION")).address as Address
    );

    const _market = await viem.getContractAt("CErc20RewardsDelegate", market);
    const fwRewards = await flywheel.read.flywheelRewards();
    const rewardToken = await flywheel.read.rewardToken();
    const tx = await _market.write.approve([rewardToken, fwRewards]);
    console.log(`mining tx ${tx}`);
    await publicClient.waitForTransactionReceipt({ hash: tx });
    console.log(`approved flywheel ${flywheel.address} to pull reward tokens from market ${market}`);

    // Adding strategies to flywheel
    const allFlywheelStrategies = (await flywheel.read.getAllStrategies()) as Address[];
    if (!allFlywheelStrategies.map((s) => s.toLowerCase()).includes(market.toLowerCase())) {
      console.log(`Adding strategy ${market} to flywheel ${flywheel.address}`);
      const addTx = await flywheel.write.addStrategyForRewards([market]);
      await publicClient.waitForTransactionReceipt({ hash: addTx });
      console.log(`Added strategy (${market}) to flywheel (${flywheel.address})`);
    } else console.log(`Strategy (${market}) was already added to flywheel (${flywheel.address})`);
  }
);

task("market:base:deploy-flywheel-and-add-rewards", "Sets caps on a market")
.addParam("market", "market address", undefined, types.string)
.addParam("rewardAmount", "the amount of tokens streamed to first epoch", undefined, types.string)
.addParam("reward", "token address of reward token", undefined, types.string)
.addParam("epochDuration", "default duration of epoch", undefined, types.string)
.addParam("name", "name of deployment", undefined, types.string)
.setAction(
  async ({market, rewardAmount, reward, epochDuration, name}, { viem, run, deployments, getNamedAccounts }) => {
    const { deployer } = await getNamedAccounts();
    const publicClient = await viem.getPublicClient();

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
    const ionToken = await viem.getContractAt("EIP20Interface", reward);
    const balance = await ionToken.read.balanceOf([market]);
    if (balance < parseEther(rewardAmount)) {
      await ionToken.write.transfer([market, parseEther(rewardAmount)]);
    }

    // Deploying flywheel 
    let booster = "";
    let flywheelBoosterAddress;
    let contractName;
    const pool = "0x05c9C6417F246600f8f5f49fcA9Ee991bfF73D13";
    if (name.includes("Borrow")) {
      contractName = "IonicFlywheelBorrow";
      booster = "0x0e47b0fF7b5571047bb1A8b18C9444D25516e7F9";
    } else {
      contractName = "IonicFlywheel";
    }
  
    if (booster != "") {
      flywheelBoosterAddress = (await deployments.get(booster)).address as Address;
    } else flywheelBoosterAddress = zeroAddress;



    const _flywheel = await deployments.deploy(`${contractName}_${name}`, {
      contract: contractName,
      from: deployer,
      log: true,
      proxy: {
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [reward, zeroAddress, flywheelBoosterAddress, deployer]
          }
        },
        owner: deployer
      },
      waitConfirmations: 1
    });

    console.log(`Deployed flywheel: ${_flywheel.address}`);
    
    // Deploying flywheel rewards
    const flywheel = await viem.getContractAt(
      `${contractName}`,
      (await deployments.get(`${contractName}_${name}`)).address as Address
    );

    const flywheelRewards = await deployments.deploy(`IonicFlywheelDynamicRewards_${name}`, {
      contract: "IonicFlywheelDynamicRewards",
      from: deployer,
      log: true,
      args: [
        flywheel.address, // flywheel
        epochDuration // epoch duration
      ],
      waitConfirmations: 1
    });
    console.log(`Deployed flywheel rewards: ${flywheelRewards.address}`);

    const txFlywheel = await flywheel.write.setFlywheelRewards([flywheelRewards.address as Address]);
    await publicClient.waitForTransactionReceipt({ hash: txFlywheel });
    console.log(`Set rewards (${flywheelRewards.address}) to flywheel (${flywheel.address})`);

    // Adding strategies to flywheel
    const allFlywheelStrategies = (await flywheel.read.getAllStrategies()) as Address[];
    if (!allFlywheelStrategies.map((s) => s.toLowerCase()).includes(market.toLowerCase())) {
      console.log(`Adding strategy ${market} to flywheel ${flywheel.address}`);
      const addTx = await flywheel.write.addStrategyForRewards([market]);
      await publicClient.waitForTransactionReceipt({ hash: addTx });
      console.log(`Added strategy (${market}) to flywheel (${flywheel.address})`);
    } else console.log(`Strategy (${market}) was already added to flywheel (${flywheel.address})`);

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
    const _market = await viem.getContractAt("CErc20RewardsDelegate", market);
    const fwRewards = await flywheel.read.flywheelRewards();
    const rewardToken = await flywheel.read.rewardToken();
    const tx = await _market.write.approve([rewardToken, fwRewards]);
    console.log(`mining tx ${tx}`);
    await publicClient.waitForTransactionReceipt({ hash: tx });
    console.log(`approved flywheel ${flywheel.address} to pull reward tokens from market ${market}`);
  }
);

task("market:base:add-flywheel-ION-rewards-to-ionbsdETH", "Adds rewards to existing flywheel")
.setAction(
  async (_, { viem, run, deployments, getNamedAccounts }) => {
  const markets = "0x3d9669de9e3e98db41a1cbf6dc23446109945e3c"; // ionbsdETH
  const rewardAmount = "2500"; // epoch will start 3 days so 25000 / 30 * 3
  const ion = "0x3eE5e23eEE121094f1cFc0Ccc79d6C809Ebd22e5";
  await run("market:base:add-rewards-to-existing-flywheel", 
    { 
      markets: markets,
      rewardAmount: rewardAmount,
      reward : ion
    }
  );
});

task("market:base:deploy-flywheel-and-add-ION-rewards-to-ionhyUSD", "Deploys flywheel and adds rewards")
.setAction(
  async (_, { viem, run, deployments, getNamedAccounts }) => {
  const markets = "0x751911bDa88eFcF412326ABE649B7A3b28c4dEDe"; // ionhyUSD
  const rewardAmount = "1500"; // epoch will start 3 days so 15000 / 30 * 3
  const ion = "0x3eE5e23eEE121094f1cFc0Ccc79d6C809Ebd22e5";
  const name = "ION"; // For borrow flywheel use Borrow_ION for supply flywheel just ION
  // NOTE: Make sure that epoch duration for supply and borrow are not the same
  const epochDuration = 2588400; // 30*(24*60*60)-60*60 29days 23 hours
  await run("market:base:deploy-flywheel-and-add-rewards", 
    { 
      markets: markets,
      rewardAmount: rewardAmount,
      reward : ion,
      epochDuration : epochDuration,
      name : name
    }
  );
});