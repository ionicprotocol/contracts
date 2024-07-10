// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { API3PriceOracle } from "../../../oracles/default/API3PriceOracle.sol";
import { IProxy } from "../../../external/api3/IProxy.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";

contract API3PriceOracleTest is BaseTest {
  API3PriceOracle private oracle;
  MasterPriceOracle mpo;
  address sDAI;
  address DAI;
  address NATIVE_TOKEN_USD_PRICE_FEED;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new API3PriceOracle();
    if (block.chainid == MODE_MAINNET) {
      // ETH-USD
      NATIVE_TOKEN_USD_PRICE_FEED = 0xa47Fd122b11CdD7aad7c3e8B740FB91D83Ce43D1;
    } else {
      revert("Unsupported chain");
    }
  }

  function setUpMode() public {
    vm.prank(mpo.admin());
    oracle.initialize(DAI, NATIVE_TOKEN_USD_PRICE_FEED);

    address[] memory underlyings = new address[](1);
    address[] memory proxies = new address[](1);

    sDAI = 0xd988097fb8612cc24eeC14542bC03424c656005f; // use USDC for testing

    underlyings[0] = sDAI;

    proxies[0] = 0xE6d4E2C4bfa192CBD8885002402CE81140983EDE;

    vm.prank(oracle.owner());
    oracle.setPriceFeeds(underlyings, proxies);

    BasePriceOracle[] memory oracles = new BasePriceOracle[](1);
    oracles[0] = oracle;

    vm.prank(mpo.admin());
    mpo.add(underlyings, oracles);
  }

  function testAPI3PriceOracleMode() public forkAtBlock(MODE_MAINNET, 9908914) {
    setUpMode();
    vm.startPrank(address(mpo));
    uint256 api3sDaiPrice = oracle.price(sDAI);
    // uint256 api3DaiPrice = oracle.price(DAI);
    emit log_named_uint("sdai", api3sDaiPrice);
    vm.stopPrank();
  }
}
