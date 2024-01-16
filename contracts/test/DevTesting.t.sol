// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import { IonicComptroller } from "../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";

contract DevTesting is BaseTest {
  function testMarketAddress() public fork(MODE_MAINNET) {
    IonicComptroller pool = IonicComptroller(0xFB3323E24743Caf4ADD0fDCCFB268565c0685556);

    ICErc20[] memory markets = pool.getAllMarkets();
    emit log_named_address("first market", address(markets[0]));
  }
}
