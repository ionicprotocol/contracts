// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import { IonicComptroller } from "../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import "../external/uniswap/quoter/interfaces/IUniswapV3Quoter.sol";
import { ISwapRouter } from "../external/uniswap/ISwapRouter.sol";
import "../external/uniswap/IUniswapV3FlashCallback.sol";

contract DevTesting is BaseTest {
  function testMarketAddress() public fork(MODE_MAINNET) {
    IonicComptroller pool = IonicComptroller(0xFB3323E24743Caf4ADD0fDCCFB268565c0685556);

    ICErc20[] memory markets = pool.getAllMarkets();
    emit log_named_uint("markets total", markets.length);

    emit log_named_address("first market", address(markets[0]));
    emit log_named_address("sec market", address(markets[1]));
  }

  // mode mainnet assets
  address WETH = 0x4200000000000000000000000000000000000006;
  address USDC = 0xd988097fb8612cc24eeC14542bC03424c656005f;
  address USDT = 0xf0F161fDA2712DB8b566946122a5af183995e2eD;
  address WBTC = 0xcDd475325D6F564d27247D1DddBb0DAc6fA0a5CF;
  address UNI = 0x3e7eF8f50246f725885102E8238CBba33F276747;
  address SNX = 0x9e5AAC1Ba1a2e6aEd6b32689DFcF62A509Ca96f3;
  address LINK = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
  address DAI = 0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea;
  address BAL = 0xD08a2917653d4E460893203471f0000826fb4034;
  address AAVE = 0x7c6b91D9Be155A6Db01f749217d76fF02A7227F2;

  function testAssetsDecimals() public fork(MODE_MAINNET) {
    emit log_named_uint("WETH decimals", ERC20(WETH).decimals());
    emit log_named_uint("USDC decimals", ERC20(USDC).decimals());
    emit log_named_uint("USDT decimals", ERC20(USDT).decimals());
    emit log_named_uint("WBTC decimals", ERC20(WBTC).decimals());
    emit log_named_uint("UNI decimals", ERC20(UNI).decimals());
    emit log_named_uint("SNX decimals", ERC20(SNX).decimals());
    emit log_named_uint("LINK decimals", ERC20(LINK).decimals());
    emit log_named_uint("DAI decimals", ERC20(DAI).decimals());
    emit log_named_uint("BAL decimals", ERC20(BAL).decimals());
    emit log_named_uint("AAVE decimals", ERC20(AAVE).decimals());
  }

  function testModeUniswap() public fork(MODE_MAINNET) {
    address quoterAddr = 0x7Fd569b2021850fbA53887dd07736010aCBFc787;

//    IUniswapV3Quoter quoter = IUniswapV3Quoter(quoterAddr);
//    quoter.quoteExactOutputSingle(
//      USDC,
//      WETH,
//      30,
//      1e8,
//      0
//    );

    IUniswapV3FlashCallback(quoterAddr).uniswapV3FlashCallback(1, 1, "");
  }
}
