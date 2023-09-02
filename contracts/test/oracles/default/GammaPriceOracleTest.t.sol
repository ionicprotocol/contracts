// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { GammaPoolAlgebraPriceOracle } from "../../../oracles/default/GammaPoolPriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { LiquidityAmounts } from "../../../external/uniswap/LiquidityAmounts.sol";
import { IUniswapV3Pool } from "../../../external/uniswap/IUniswapV3Pool.sol";

import { IHypervisor } from "../../../external/gamma/IHypervisor.sol";

contract GammaPoolPriceOracleTest is BaseTest {
  GammaPoolAlgebraPriceOracle private oracle;
  MasterPriceOracle mpo;
  address wtoken;
  address stable;

  function afterForkSetUp() internal override {
    stable = ap.getAddress("stableToken");
    wtoken = ap.getAddress("wtoken"); // WETH
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    oracle = new GammaPoolAlgebraPriceOracle();
    vm.prank(mpo.admin());
    oracle.initialize(wtoken);
  }

  function testPriceGammaPolygonNow() public fork(POLYGON_MAINNET) {
    {
      uint256 withdrawAmount = 1e18;
      address DAI_GNS_QS_GAMMA_VAULT = 0x7aE7FB44c92B4d41abB6E28494f46a2EB3c2a690; // QS aDAI-GNS (Narrow)
      address DAI_GNS_QS_GAMMA_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // QS Masterchef

      vm.prank(address(mpo));
      uint256 price_DAI_GNS = oracle.price(DAI_GNS_QS_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(DAI_GNS_QS_GAMMA_WHALE, DAI_GNS_QS_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_DAI_GNS, expectedPrice, 1e16, "!aDAI-GNS price");
    }

    {
      uint256 withdrawAmount = 1e6;
      address DAI_USDT_QS_GAMMA_VAULT = 0x45A3A657b834699f5cC902e796c547F826703b79;
      address DAI_USDT_QS_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // QS Masterchef

      vm.prank(address(mpo));
      uint256 price_DAI_USDT = oracle.price(DAI_USDT_QS_GAMMA_VAULT) / (1e18 / withdrawAmount);

      uint256 expectedPrice = priceAtWithdraw(DAI_USDT_QS_WHALE, DAI_USDT_QS_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_DAI_USDT, expectedPrice, 1e16, "!aDAI-USDT price");
    }

    {
      uint256 withdrawAmount = 1e6;
      address WETH_USDT_QS_GAMMA_VAULT = 0x5928f9f61902b139e1c40cBa59077516734ff09f; // QS aWETH-USDT (Narrow)
      address WETH_USDT_QS_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // QS Masterchef

      vm.prank(address(mpo));
      uint256 price_WETH_USDT = oracle.price(WETH_USDT_QS_GAMMA_VAULT) / (1e18 / withdrawAmount);

      uint256 expectedPrice = priceAtWithdraw(WETH_USDT_QS_WHALE, WETH_USDT_QS_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_WETH_USDT, expectedPrice, 5e16, "!aWETH-USDT price");
    }
  }

  function testPriceGammaBscNow() public fork(BSC_MAINNET) {
    uint256 withdrawAmount = 1e18;
    {
      address USDT_WBNB_THENA_GAMMA_VAULT = 0x921C7aC35D9a528440B75137066adb1547289555; // Wide
      address USDT_WBNB_THENA_WHALE = 0x04008Bf76d2BC193858101d932135e09FBfF4779; // thena gauge for aUSDT-WBNB

      vm.prank(address(mpo));
      uint256 price_USDT_WBNB = oracle.price(USDT_WBNB_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(USDT_WBNB_THENA_WHALE, USDT_WBNB_THENA_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_USDT_WBNB, expectedPrice, 1e16, "!aUSDT-WBNB price");
    }

    {
      address USDT_USDC_THENA_GAMMA_VAULT = 0x5EEca990E9B7489665F4B57D27D92c78BC2AfBF2;
      address USDT_USDC_THENA_WHALE = 0x1011530830c914970CAa96a52B9DA1C709Ea48fb; // thena gauge

      vm.prank(address(mpo));
      uint256 price_USDT_USDC = oracle.price(USDT_USDC_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(USDT_USDC_THENA_WHALE, USDT_USDC_THENA_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_USDT_USDC, expectedPrice, 1e16, "!USDT_USDC price");
    }

    {
      address WBTC_WBNB_THENA_GAMMA_VAULT = 0xBd2383816Bab04E46b69801CCa7e92D34aB94D3F; // Wide
      address WBTC_WBNB_THENA_WHALE = 0xb75942D49e7F455C47DebBDCA81DF67244fe7d40; // thena gauge

      vm.prank(address(mpo));
      uint256 price_WBTC_WBNB = oracle.price(WBTC_WBNB_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(WBTC_WBNB_THENA_WHALE, WBTC_WBNB_THENA_GAMMA_VAULT, withdrawAmount);
      assertApproxEqRel(price_WBTC_WBNB, expectedPrice, 1e16, "!WBTC_WBNB price");
    }

    {
      address ANKR_AnkrBNB_WIDE_THENA_GAMMA_VAULT = 0x31257f40e65585cC45fDABEb12002C25bC95eE80; // Wide
      address ANKR_AnkrBNB_WIDE_THENA_WHALE = 0x7E4F069107cf0EE090AF5e4e075dC6Fcc644C61D; // thena gauge

      vm.prank(address(mpo));
      uint256 price_ANKR_AnkrBNB = oracle.price(ANKR_AnkrBNB_WIDE_THENA_GAMMA_VAULT);

      uint256 expectedPrice = priceAtWithdraw(
        ANKR_AnkrBNB_WIDE_THENA_WHALE,
        ANKR_AnkrBNB_WIDE_THENA_GAMMA_VAULT,
        withdrawAmount
      );
      assertApproxEqRel(price_ANKR_AnkrBNB, expectedPrice, 1e16, "!WBTC_WBNB price");
    }
  }

  function priceAtWithdraw(
    address whale,
    address vaultAddress,
    uint256 withdrawAmount
  ) internal returns (uint256) {
    address emptyAddress = address(900202020);
    IHypervisor vault = IHypervisor(vaultAddress);
    ERC20Upgradeable token0 = ERC20Upgradeable(vault.token0());
    ERC20Upgradeable token1 = ERC20Upgradeable(vault.token1());

    uint256 balance0Before = token0.balanceOf(emptyAddress);
    uint256 balance1Before = token1.balanceOf(emptyAddress);

    uint256[4] memory minAmounts;
    vm.prank(whale);
    vault.withdraw(withdrawAmount, emptyAddress, whale, minAmounts);

    uint256 balance0After = token0.balanceOf(emptyAddress);
    uint256 balance1After = token1.balanceOf(emptyAddress);

    uint256 price0 = mpo.price(address(token0));
    uint256 price1 = mpo.price(address(token1));

    uint256 balance0Diff = (balance0After - balance0Before) * 10**(18 - uint256(token0.decimals()));
    uint256 balance1Diff = (balance1After - balance1Before) * 10**(18 - uint256(token1.decimals()));

    return (balance0Diff * price0 + balance1Diff * price1) / 1e18;
  }
}
