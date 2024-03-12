// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ITestConfigStorage } from "../abstracts/ITestConfigStorage.sol";

struct CurveTestConfig {
  address gauge;
  address asset;
  address[] rewardsToken;
}

contract CurveTestConfigStorage is ITestConfigStorage {
  CurveTestConfig[] internal testConfigs;
  address[] internal tempRewardsToken;

  constructor() {
    // Matic/stMatic
    tempRewardsToken.push(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978); // LDO
    testConfigs.push(
      CurveTestConfig(
        0xCE5F24B7A95e9cBa7df4B54E911B4A3Dc8CDAf6f, // CRV Gauge
        0x7f90122BF0700F9E7e1F688fe926940E8839F353, // USDC/USDT LpToken
        tempRewardsToken
      )
    );
  }

  function getTestConfig(uint256 i) public view returns (bytes memory) {
    return abi.encode(testConfigs[i].gauge, testConfigs[i].asset, testConfigs[i].rewardsToken);
  }

  function getTestConfigLength() public view returns (uint256) {
    return testConfigs.length;
  }
}
