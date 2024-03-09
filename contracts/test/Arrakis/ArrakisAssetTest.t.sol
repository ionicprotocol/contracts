// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ArrakisTestConfigStorage } from "./ArrakisTestConfig.sol";
import { AbstractAssetTest } from "../abstracts/AbstractAssetTest.sol";
import { AbstractERC4626Test } from "../abstracts/AbstractERC4626Test.sol";
import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";
import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import "./ArrakisERC4626Test.sol";

contract ArrakisAssetTest is AbstractAssetTest {
  MasterPriceOracle masterPriceOracle;

  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    masterPriceOracle = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    test = AbstractERC4626Test(address(new ArrakisERC4626Test()));
    testConfigStorage = ITestConfigStorage(address(new ArrakisTestConfigStorage()));
  }

  function setUpTestContract(bytes calldata testConfig) public override {
    (address asset, address pool) = abi.decode(testConfig, (address, address));

    test.setUpWithPool(masterPriceOracle, ERC20Upgradeable(asset));

    test._setUp(MockERC20(asset).symbol(), testConfig);
  }

  function testInitializedValues() public override {
    if (shouldRunForChain(block.chainid)) {
      for (uint8 i; i < testConfigStorage.getTestConfigLength(); i++) {
        bytes memory testConfig = testConfigStorage.getTestConfig(i);

        this.setUpTestContract(testConfig);

        (address asset, ) = abi.decode(testConfig, (address, address));

        test.testInitializedValues(MockERC20(asset).name(), MockERC20(asset).symbol());
      }
    }
  }

  function testDepositWithIncreasedVaultValue() public override {
    this.runTest(test.testDepositWithIncreasedVaultValue);
  }

  function testDepositWithDecreasedVaultValue() public override {
    this.runTest(test.testDepositWithDecreasedVaultValue);
  }

  function testWithdrawWithIncreasedVaultValue() public override {
    this.runTest(test.testWithdrawWithIncreasedVaultValue);
  }

  function testWithdrawWithDecreasedVaultValue() public override {
    this.runTest(test.testWithdrawWithDecreasedVaultValue);
  }

  function testAccumulatingRewardsOnDeposit() public {
    this.runTest(ArrakisERC4626Test(address(test)).testAccumulatingRewardsOnDeposit);
  }

  function testAccumulatingRewardsOnWithdrawal() public {
    this.runTest(ArrakisERC4626Test(address(test)).testAccumulatingRewardsOnWithdrawal);
  }

  function testClaimRewards() public {
    this.runTest(ArrakisERC4626Test(address(test)).testClaimRewards);
  }
}
