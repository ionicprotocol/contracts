// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";

import { AnkrRatioPriceOracle } from "../../oracles/default/AnkrRatioPriceOracle.sol";

contract AnkrRatioPriceOracleTest is BaseTest {
  address public ankrRatioPriceOracle;
  AnkrRatioPriceOracle public oracle;

  address public mpo;

  address ankrEth;

  function afterForkSetUp() internal override {
    mpo = ap.getAddress("MasterPriceOracle");

    oracle = new AnkrRatioPriceOracle();
    oracle.initialize();

    if (block.chainid == MODE_MAINNET) {
      ankrEth = 0x12D8CE035c5DE3Ce39B1fDD4C1d5a745EAbA3b8C;
    }

    oracle.setStakedAndOriginalAssets(asArray(ankrEth), asArray(ap.getAddress("wtoken")));
  }

  function testPrintAnkrPricesMode() public debuggingOnly fork(MODE_MAINNET) {
    vm.startPrank(mpo);
    emit log_named_uint("ankrETH price (18 dec)", oracle.price(ankrEth));
    vm.stopPrank();
  }
}
