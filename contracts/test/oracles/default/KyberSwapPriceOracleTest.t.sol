// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { KyberSwapPriceOracle } from "../../../oracles/default/KyberSwapPriceOracle.sol";
import { ConcentratedLiquidityBasePriceOracle } from "../../../oracles/default/ConcentratedLiquidityBasePriceOracle.sol";
import { IPool } from "../../../external/kyber/IPool.sol";
import { IPoolOracle } from "../../../external/kyber/IPoolOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { BaseTest } from "../../config/BaseTest.t.sol";

contract KyberSwapPriceOracleTest is BaseTest {
  KyberSwapPriceOracle oracle;
  MasterPriceOracle mpo;
  address wtoken;
  address wbtc;
  address stable;

  function afterForkSetUp() internal override {
    stable = ap.getAddress("stableToken");
    wtoken = ap.getAddress("wtoken"); // WETH
    wbtc = ap.getAddress("wBTCToken"); // WBTC
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new KyberSwapPriceOracle();

    vm.prank(mpo.admin());
    oracle.initialize(wtoken, asArray(stable));
  }

  function testLineaAssets() public debuggingOnly forkAtBlock(LINEA_MAINNET, 167856) {
    address busd = 0x7d43AABC515C356145049227CeE54B608342c0ad;
    address wmatic = 0x265B25e22bcd7f10a5bD6E6410F10537Cc7567e8;
    address avax = 0x5471ea8f739dd37E9B81Be9c5c77754D8AA953E4;

    address[] memory underlyings = new address[](3);
    ConcentratedLiquidityBasePriceOracle.AssetConfig[]
      memory configs = new ConcentratedLiquidityBasePriceOracle.AssetConfig[](3);

    underlyings[0] = busd; // WMATIC (18 decimals)
    underlyings[1] = wmatic; // WBTC (18 decimals)
    underlyings[2] = avax; // AVAX (18 decimals)

    IPool busdWethPool = IPool(0xe2dF725E44ab983e8513eCfC9c3E13Bc21eA867e);
    IPool wmaticWethPool = IPool(0x0330fdDD733eA64F92B348fF19a2Bb4d29d379D5);
    IPool avaxWethPool = IPool(0x76F12b1B0FF9a53810894F94B31EE2569e0D9BC4);

    IPoolOracle busdWethPoolOracle = IPoolOracle(busdWethPool.poolOracle());
    IPoolOracle wmaticWethPoolOracle = IPoolOracle(wmaticWethPool.poolOracle());
    IPoolOracle avaxWethOracle = IPoolOracle(avaxWethPool.poolOracle());

    busdWethPoolOracle.initializeOracle(uint32(block.timestamp));
    wmaticWethPoolOracle.initializeOracle(uint32(block.timestamp));
    avaxWethOracle.initializeOracle(uint32(block.timestamp));

    vm.warp(block.timestamp + 36000);

    busdWethPoolOracle.increaseObservationCardinalityNext(address(busdWethPool), 3600);
    wmaticWethPoolOracle.increaseObservationCardinalityNext(address(busdWethPool), 3600);
    avaxWethOracle.increaseObservationCardinalityNext(address(busdWethPool), 3600);

    vm.roll(100);

    // BUSD-WETH
    configs[0] = ConcentratedLiquidityBasePriceOracle.AssetConfig(address(busdWethPool), 60, wtoken);
    // WMATIC-WETH
    configs[1] = ConcentratedLiquidityBasePriceOracle.AssetConfig(address(wmaticWethPool), 60, wtoken);
    // AVAX-ETH
    configs[2] = ConcentratedLiquidityBasePriceOracle.AssetConfig(address(avaxWethPool), 600, wtoken);

    uint256 priceUsdc = mpo.price(stable);
    uint256[] memory expPrices = new uint256[](3);
    expPrices[0] = priceUsdc;

    uint256[] memory prices = getPriceFeed(underlyings, configs);

    assertApproxEqRel(prices[0], expPrices[0], 1e17, "!Price Error");
    assertLt(prices[1], prices[0], "!Price Error");
    assertGt(prices[2], prices[1], "!Price Error");
  }

  function getPriceFeed(address[] memory underlyings, ConcentratedLiquidityBasePriceOracle.AssetConfig[] memory configs)
    internal
    returns (uint256[] memory price)
  {
    vm.prank(oracle.owner());
    oracle.setPoolFeeds(underlyings, configs);
    vm.roll(1);

    price = new uint256[](underlyings.length);
    for (uint256 i = 0; i < underlyings.length; i++) {
      vm.prank(address(mpo));
      price[i] = oracle.price(underlyings[i]);
    }
    return price;
  }
}
