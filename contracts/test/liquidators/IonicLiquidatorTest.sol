// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

import { IonicLiquidator, ILiquidator } from "../../IonicLiquidator.sol";
import { ICurvePool } from "../../external/curve/ICurvePool.sol";
import { CurveSwapLiquidatorFunder } from "../../liquidators/CurveSwapLiquidatorFunder.sol";
import { UniswapV3LiquidatorFunder } from "../../liquidators/UniswapV3LiquidatorFunder.sol";
import { IonicComptroller } from "../../compound/ComptrollerInterface.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { IFundsConversionStrategy } from "../../liquidators/IFundsConversionStrategy.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";
import "../../external/uniswap/quoter/interfaces/IUniswapV3Quoter.sol";
import { AuthoritiesRegistry } from "../../ionic/AuthoritiesRegistry.sol";
import { LiquidatorsRegistrySecondExtension } from "../../liquidators/registry/LiquidatorsRegistrySecondExtension.sol";
import "../../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { Unitroller } from "../../compound/Unitroller.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";

import { BaseTest } from "../config/BaseTest.t.sol";
import { UpgradesBaseTest } from "../UpgradesBaseTest.sol";

contract MockRedemptionStrategy is IRedemptionStrategy {
  function redeem(
    IERC20Upgradeable,
    uint256,
    bytes memory
  ) external returns (IERC20Upgradeable, uint256) {
    return (IERC20Upgradeable(address(0)), 1);
  }

  function name() public pure returns (string memory) {
    return "MockRedemptionStrategy";
  }
}

contract IonicLiquidatorTest is UpgradesBaseTest {
  ILiquidator liquidator;
  address uniswapRouter;
  address swapRouter;
  IUniswapV3Quoter quoter;
  address usdcWhale;
  address wethWhale;
  address poolAddress;
  address uniV3PooForFlash;
  uint256 usdcMarketIndex;
  uint256 wethMarketIndex;

  AuthoritiesRegistry authRegistry;
  ILiquidatorsRegistry liquidatorsRegistry;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    if (block.chainid == BSC_MAINNET) {
      uniswapRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    } else if (block.chainid == POLYGON_MAINNET) {
      uniswapRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
      swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      quoter = IUniswapV3Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
      usdcWhale = 0x625E7708f30cA75bfd92586e17077590C60eb4cD; // aave reserve
      wethWhale = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;
      poolAddress = 0x22A705DEC988410A959B8b17C8c23E33c121580b; // Retro stables pool
      uniV3PooForFlash = 0xA374094527e1673A86dE625aa59517c5dE346d32; // usdc-wmatic
      usdcMarketIndex = 3;
      wethMarketIndex = 5;
    } else if (block.chainid == MODE_MAINNET) {
      uniswapRouter = 0x5D61c537393cf21893BE619E36fC94cd73C77DD3; // kim router
      //      uniswapRouter = 0xC9Adff795f46105E53be9bbf14221b1C9919EE25; // sup router
      //      swapRouter = 0xC9Adff795f46105E53be9bbf14221b1C9919EE25; // sup router
      swapRouter = 0x5D61c537393cf21893BE619E36fC94cd73C77DD3; // kim router
      //quoter = IUniswapV3Quoter(0x7Fd569b2021850fbA53887dd07736010aCBFc787); // other sup quoter?
      quoter = IUniswapV3Quoter(0x5E6AEbab1AD525f5336Bd12E6847b851531F72ba); // sup quoter
      usdcWhale = 0x34b83A3759ba4c9F99c339604181bf6bBdED4C79; // vault
      wethWhale = 0xF4C85269240C1D447309fA602A90ac23F1CB0Dc0;
      poolAddress = 0xFB3323E24743Caf4ADD0fDCCFB268565c0685556;
      //uniV3PooForFlash = 0x293f2B2c17f8cEa4db346D87Ef5712C9dd0491EF; // kim weth-usdc pool
      uniV3PooForFlash = 0x047CF4b081ee80d2928cb2ce3F3C4964e26eB0B9; // kim usdt-usdc pool
      //      uniV3PooForFlash = 0xf2e9C024F1C0B7a2a4ea11243C2D86A7b38DD72f; // sup univ2 0x34a1E3Db82f669f8cF88135422AfD80e4f70701A
      usdcMarketIndex = 1;
      wethMarketIndex = 0;
      // weth 0x4200000000000000000000000000000000000006
      // usdc 0xd988097fb8612cc24eeC14542bC03424c656005f
    }

    //    vm.prank(ap.owner());
    //    ap.setAddress("IUniswapV2Router02", uniswapRouter);
    vm.prank(ap.owner());
    ap.setAddress("UNISWAP_V3_ROUTER", uniswapRouter);

    authRegistry = AuthoritiesRegistry(ap.getAddress("AuthoritiesRegistry"));
    liquidatorsRegistry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));
    liquidator = IonicLiquidator(payable(ap.getAddress("IonicLiquidator")));
  }

  function upgradeRegistry() internal {
    DiamondBase asBase = DiamondBase(address(liquidatorsRegistry));
    address[] memory exts = asBase._listExtensions();
    LiquidatorsRegistryExtension newExt1 = new LiquidatorsRegistryExtension();
    LiquidatorsRegistrySecondExtension newExt2 = new LiquidatorsRegistrySecondExtension();
    vm.prank(SafeOwnable(address(liquidatorsRegistry)).owner());
    asBase._registerExtension(newExt1, DiamondExtension(exts[0]));
    vm.prank(SafeOwnable(address(liquidatorsRegistry)).owner());
    asBase._registerExtension(newExt2, DiamondExtension(exts[1]));
  }

  function testBsc() public fork(BSC_MAINNET) {
    testUpgrade();
  }

  function testPolygon() public fork(POLYGON_MAINNET) {
    testUpgrade();
  }

  function testUpgrade() internal {
    // in case these slots start to get used, please redeploy the FSL
    // with a larger storage gap to protect the owner variable of OwnableUpgradeable
    // from being overwritten by the IonicLiquidator storage
    for (uint256 i = 40; i < 51; i++) {
      address atSloti = address(uint160(uint256(vm.load(address(liquidator), bytes32(i)))));
      assertEq(
        atSloti,
        address(0),
        "replace the FSL proxy/storage contract with a new one before the owner variable is overwritten"
      );
    }
  }

  function useThisToTestLiquidations() public fork(POLYGON_MAINNET) {
    address borrower = 0xA4F4406D3dc6482dB1397d0ad260fd223C8F37FC;
    address debtMarketAddr = 0x456b363D3dA38d3823Ce2e1955362bBd761B324b;
    address collateralMarketAddr = 0x28D0d45e593764C4cE88ccD1C033d0E2e8cE9aF3;

    ILiquidator.LiquidateToTokensWithFlashSwapVars memory vars;
    vars.borrower = borrower;
    vars.cErc20 = ICErc20(debtMarketAddr);
    vars.cTokenCollateral = ICErc20(collateralMarketAddr);
    vars.repayAmount = 70565471214557927746795;
    vars.flashSwapContract = 0x6e7a5FAFcec6BB1e78bAE2A1F0B612012BF14827;
    vars.minProfitAmount = 0;
    vars.redemptionStrategies = new IRedemptionStrategy[](0);
    vars.strategyData = new bytes[](0);
    vars.debtFundingStrategies = new IFundsConversionStrategy[](1);
    vars.debtFundingStrategiesData = new bytes[](1);

    vars.debtFundingStrategies[0] = IFundsConversionStrategy(0x98110E8482E4e286716AC0671438BDd84C4D838c);
    vars.debtFundingStrategiesData[
        0
      ] = hex"0000000000000000000000002791bca1f2de4661ed88a30c99a7a9449aa84174000000000000000000000000aec757bf73cc1f4609a1459205835dd40b4e3f290000000000000000000000000000000000000000000000000000000000000960";

    // liquidator.safeLiquidateToTokensWithFlashLoan(vars);

    vars.cErc20.comptroller();
  }

  // TODO test with marginal shortfall for liquidation penalty errors
  function _testLiquidatorLiquidate(address contractForFlashSwap) internal {
    IonicComptroller pool = IonicComptroller(poolAddress);
    //    _upgradePoolWithExtension(Unitroller(payable(poolAddress)));
    //upgradeRegistry();

    ICErc20[] memory markets = pool.getAllMarkets();

    ICErc20 usdcMarket = markets[usdcMarketIndex];
    IERC20Upgradeable usdc = IERC20Upgradeable(usdcMarket.underlying());
    ICErc20 wethMarket = markets[wethMarketIndex];
    IERC20Upgradeable weth = IERC20Upgradeable(wethMarket.underlying());
    {
      emit log_named_address("usdc market", address(usdcMarket));
      emit log_named_address("weth market", address(wethMarket));
      emit log_named_address("usdc underlying", usdcMarket.underlying());
      emit log_named_address("weth underlying", wethMarket.underlying());
      vm.prank(pool.admin());
      pool._setBorrowCapForCollateral(address(usdcMarket), address(wethMarket), 1e36);
    }

    {
      vm.prank(pool.admin());
      pool._borrowCapWhitelist(0x2BE717340023C9e14C1Bb12cb3ecBcfd3c3fB038, address(this), true);
    }

    {
      vm.prank(wethWhale);
      weth.transfer(address(this), 0.1e18);

      weth.approve(address(wethMarket), 1e36);
      require(wethMarket.mint(0.1e18) == 0, "mint weth failed");
      pool.enterMarkets(asArray(address(usdcMarket), address(wethMarket)));
    }

    {
      vm.startPrank(usdcWhale);
      usdc.approve(address(usdcMarket), 2e36);
      require(usdcMarket.mint(70e6) == 0, "mint usdc failed");
      vm.stopPrank();
    }

    {
      require(usdcMarket.borrow(50e6) == 0, "borrow usdc failed");

      // the collateral prices change
      BasePriceOracle mpo = pool.oracle();
      uint256 priceCollateral = mpo.getUnderlyingPrice(wethMarket);
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, wethMarket),
        abi.encode(priceCollateral / 10)
      );
    }

    (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData) = liquidatorsRegistry
      .getRedemptionStrategies(weth, usdc);

    uint256 seizedAmount = liquidator.safeLiquidateToTokensWithFlashLoan(
      ILiquidator.LiquidateToTokensWithFlashSwapVars({
        borrower: address(this),
        repayAmount: 10e6,
        cErc20: usdcMarket,
        cTokenCollateral: wethMarket,
        flashSwapContract: contractForFlashSwap,
        minProfitAmount: 6,
        redemptionStrategies: strategies,
        strategyData: strategiesData,
        debtFundingStrategies: new IFundsConversionStrategy[](0),
        debtFundingStrategiesData: new bytes[](0)
      })
    );

    emit log_named_uint("seized amount", seizedAmount);
    require(seizedAmount > 0, "didn't seize any assets");
  }
}
