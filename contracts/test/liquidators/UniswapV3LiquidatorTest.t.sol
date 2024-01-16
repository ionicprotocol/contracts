// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { IonicUniV3Liquidator, IUniswapV3Pool } from "../../IonicUniV3Liquidator.sol";
import "../../external/uniswap/quoter/interfaces/IUniswapV3Quoter.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";
import "../../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { LiquidatorsRegistrySecondExtension } from "../../liquidators/registry/LiquidatorsRegistrySecondExtension.sol";
import { UniswapV3LiquidatorFunder } from "../../liquidators/UniswapV3LiquidatorFunder.sol";

import { IFundsConversionStrategy } from "../../liquidators/IFundsConversionStrategy.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { IonicComptroller } from "../../compound/ComptrollerInterface.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";
import { Unitroller } from "../../compound/Unitroller.sol";
import { AuthoritiesRegistry } from "../../ionic/AuthoritiesRegistry.sol";
import { PoolRolesAuthority } from "../../ionic/PoolRolesAuthority.sol";

import { BaseTest } from "../config/BaseTest.t.sol";
import { UpgradesBaseTest } from "../UpgradesBaseTest.sol";

contract UniswapV3LiquidatorTest is UpgradesBaseTest {
  address uniswapV3Router = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
  address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
  IUniswapV3Quoter quoter = IUniswapV3Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
  address usdcWhale = 0x625E7708f30cA75bfd92586e17077590C60eb4cD; // aave reserve
  address wethWhale = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;
  address poolAddress = 0x22A705DEC988410A959B8b17C8c23E33c121580b; // Retro stables pool
  address uniV3PooForFlash = 0xA374094527e1673A86dE625aa59517c5dE346d32; // usdc-wmatic
  address uniV3PooForCollateral = 0x167384319B41F7094e62f7506409Eb38079AbfF8; // weth to wmatic

  AuthoritiesRegistry authRegistry;
  IonicUniV3Liquidator liquidator;
  ILiquidatorsRegistry liquidatorsRegistry;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    authRegistry = AuthoritiesRegistry(ap.getAddress("AuthoritiesRegistry"));
    liquidatorsRegistry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));

    liquidator = new IonicUniV3Liquidator();
    liquidator.initialize(ap.getAddress("wtoken"), address(swapRouter), address(quoter));
  }

  function testUniV3LiquidatorInitialized() public fork(POLYGON_MAINNET) {
    emit log_named_address("wtoken", liquidator.W_NATIVE_ADDRESS());
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

  function _setupLiquidatorsRegistry() internal {
    upgradeRegistry();
  }

  function testUniV3LiquidatorLiquidate() public fork(POLYGON_MAINNET) {
    IonicComptroller pool = IonicComptroller(poolAddress);
    _upgradePoolWithExtension(Unitroller(payable(poolAddress)));

    {
      PoolRolesAuthority auth = authRegistry.poolsAuthorities(poolAddress);
      vm.startPrank(auth.owner());
      auth.openPoolSupplierCapabilities(pool);
      auth.openPoolBorrowerCapabilities(pool);
      vm.stopPrank();
    }

    ICErc20[] memory markets = pool.getAllMarkets();

    ICErc20 usdcMarket = markets[3];
    IERC20Upgradeable usdc = IERC20Upgradeable(usdcMarket.underlying());
    ICErc20 wethMarket = markets[5];
    IERC20Upgradeable weth = IERC20Upgradeable(wethMarket.underlying());
    {
      emit log_named_address("market3", address(usdcMarket));
      emit log_named_address("market5", address(wethMarket));
      emit log_named_address("underlying3", usdcMarket.underlying());
      emit log_named_address("underlying5", wethMarket.underlying());
      vm.prank(pool.admin());
      pool._setBorrowCapForCollateral(address(usdcMarket), address(wethMarket), 1e36);
      vm.startPrank(liquidatorsRegistry.owner());
      IRedemptionStrategy strategy = new UniswapV3LiquidatorFunder();
      liquidatorsRegistry._setRedemptionStrategy(strategy, weth, usdc);
      vm.stopPrank();
      vm.prank(liquidator.owner());
      liquidator._whitelistRedemptionStrategy(strategy, true);
    }

    {
      vm.prank(wethWhale);
      weth.transfer(address(this), 10e18);

      weth.approve(address(wethMarket), 1e36);
      require(wethMarket.mint(1e18) == 0, "mint weth failed");
      pool.enterMarkets(asArray(address(usdcMarket), address(wethMarket)));
    }

    {
      vm.startPrank(usdcWhale);
      usdc.approve(address(usdcMarket), 2e36);
      require(usdcMarket.mint(2000e6) == 0, "mint usdc failed");
      vm.stopPrank();
    }

    {
      require(usdcMarket.borrow(200e6) == 0, "borrow usdc failed");

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
      IonicUniV3Liquidator.LiquidateToTokensWithFlashSwapVars({
        borrower: address(this),
        repayAmount: 100e6,
        cErc20: usdcMarket,
        cTokenCollateral: wethMarket,
        flashSwapPool: IUniswapV3Pool(uniV3PooForFlash),
        minProfitAmount: 6,
        redemptionStrategies: strategies,
        strategyData: strategiesData,
        debtFundingStrategies: new IFundsConversionStrategy[](0),
        debtFundingStrategiesData: new bytes[](0)
      })
    );

    require(seizedAmount > 0, "didn't seize any assets");
  }
}
