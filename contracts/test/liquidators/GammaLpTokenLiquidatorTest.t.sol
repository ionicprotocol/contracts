// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../config/BaseTest.t.sol";
import { GammaLpTokenLiquidator, GammaAlgebraLpTokenWrapper, GammaUnisapwV3LpTokenWrapper } from "../../liquidators/GammaLpTokenLiquidator.sol";
import { IHypervisor } from "../../external/gamma/IHypervisor.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract GammaLpTokenLiquidatorTest is BaseTest {
  GammaLpTokenLiquidator public liquidator;
  GammaAlgebraLpTokenWrapper aWrapper;
  GammaUnisapwV3LpTokenWrapper uWrapper;

  address uniV3SwapRouter;
  address algebraSwapRouter;
  address uniProxyAlgebra;
  address uniProxyUni;
  address wtoken;

  function afterForkSetUp() internal override {
    liquidator = new GammaLpTokenLiquidator();
    aWrapper = new GammaAlgebraLpTokenWrapper();
    uWrapper = new GammaUnisapwV3LpTokenWrapper();
    wtoken = ap.getAddress("wtoken");
    if (block.chainid == POLYGON_MAINNET) {
      uniProxyAlgebra = 0xA42d55074869491D60Ac05490376B74cF19B00e6;
      uniProxyUni = 0xDC8eE75f52FABF057ae43Bb4B85C55315b57186c;
      uniV3SwapRouter = 0x1891783cb3497Fdad1F25C933225243c2c7c4102; // Retro
      algebraSwapRouter = 0xf5b509bB0909a69B1c207E495f687a596C168E12; // QS
    }
  }

  function testGammaAlgebraLpTokenLiquidator() public fork(POLYGON_MAINNET) {
    uint256 withdrawAmount = 1e18;
    address DAI_GNS_QS_GAMMA_VAULT = 0x7aE7FB44c92B4d41abB6E28494f46a2EB3c2a690; // Wide
    address DAI_GNS_QS_WHALE = 0x20ec0d06F447d550fC6edee42121bc8C1817b97D; // thena gauge for aUSDT-WBNB

    IHypervisor vault = IHypervisor(DAI_GNS_QS_GAMMA_VAULT);
    vm.prank(DAI_GNS_QS_WHALE);
    vault.transfer(address(liquidator), withdrawAmount);

    address outputTokenAddress = ap.getAddress("wtoken"); // WBNB
    bytes memory strategyData = abi.encode(outputTokenAddress, algebraSwapRouter);
    (, uint256 outputAmount) = liquidator.redeem(vault, withdrawAmount, strategyData);

    emit log_named_uint("wbnb redeemed", outputAmount);
    assertGt(outputAmount, 0, "!failed to withdraw and swap");
  }

  function testGammaLpTokenWrapperWbnb() public fork(POLYGON_MAINNET) {
    address WMATIC_WETH_QS_GAMMA_VAULT = 0x02203f2351E7aC6aB5051205172D3f772db7D814;
    IHypervisor vault = IHypervisor(WMATIC_WETH_QS_GAMMA_VAULT);
    address wtokenWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address wethAddress = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;

    vm.prank(wtokenWhale);
    IERC20Upgradeable(wtoken).transfer(address(aWrapper), 1e18);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = aWrapper.redeem(
      IERC20Upgradeable(wtoken),
      1e18,
      abi.encode(algebraSwapRouter, uniProxyAlgebra, vault)
    );

    emit log_named_uint("lp tokens minted", outputAmount);

    assertGt(outputToken.balanceOf(address(aWrapper)), 0, "!wrapped");
    assertEq(IERC20Upgradeable(wtoken).balanceOf(address(aWrapper)), 0, "!unused wtoken");
    assertEq(IERC20Upgradeable(wethAddress).balanceOf(address(aWrapper)), 0, "!unused usdt");
  }

  function testGammaLpTokenWrapperUsdt() public fork(POLYGON_MAINNET) {
    address ETH_USDT_QS_GAMMA_VAULT = 0x5928f9f61902b139e1c40cBa59077516734ff09f; // Wide
    IHypervisor vault = IHypervisor(ETH_USDT_QS_GAMMA_VAULT);
    address usdtAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address usdtWhale = 0x0639556F03714A74a5fEEaF5736a4A64fF70D206;
    IERC20Upgradeable usdt = IERC20Upgradeable(usdtAddress);

    vm.prank(usdtWhale);
    usdt.transfer(address(aWrapper), 1e6);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = aWrapper.redeem(
      usdt,
      1e6,
      abi.encode(algebraSwapRouter, uniProxyAlgebra, vault)
    );

    emit log_named_uint("lp tokens minted", outputAmount);

    assertGt(outputToken.balanceOf(address(aWrapper)), 0, "!wrapped");
    assertEq(IERC20Upgradeable(wtoken).balanceOf(address(aWrapper)), 0, "!unused wtoken");
    assertEq(usdt.balanceOf(address(aWrapper)), 0, "!unused usdt");
  }
}
