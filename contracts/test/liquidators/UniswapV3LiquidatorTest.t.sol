// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { IonicUniV3Liquidator, IUniswapV3Pool, ILiquidator } from "../../IonicUniV3Liquidator.sol";
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
  address swapRouter;
  IUniswapV3Quoter quoter;
  address usdcWhale;
  address wethWhale;
  address poolAddress;
  address uniV3PooForFlash;
  uint256 usdcMarketIndex;
  uint256 wethMarketIndex;

  AuthoritiesRegistry authRegistry;
  IonicUniV3Liquidator liquidator;
  ILiquidatorsRegistry liquidatorsRegistry;

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    if (block.chainid == POLYGON_MAINNET) {
      swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      quoter = IUniswapV3Quoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
      usdcWhale = 0x625E7708f30cA75bfd92586e17077590C60eb4cD; // aave reserve
      wethWhale = 0x1eED63EfBA5f81D95bfe37d82C8E736b974F477b;
      poolAddress = 0x22A705DEC988410A959B8b17C8c23E33c121580b; // Retro stables pool
      uniV3PooForFlash = 0xA374094527e1673A86dE625aa59517c5dE346d32; // usdc-wmatic
      usdcMarketIndex = 3;
      wethMarketIndex = 5;
    } else if (block.chainid == MODE_MAINNET) {
      swapRouter = 0xC9Adff795f46105E53be9bbf14221b1C9919EE25;
      quoter = IUniswapV3Quoter(0x7Fd569b2021850fbA53887dd07736010aCBFc787);
      usdcWhale = 0x293f2B2c17f8cEa4db346D87Ef5712C9dd0491EF;
      wethWhale = 0xF4C85269240C1D447309fA602A90ac23F1CB0Dc0;
      poolAddress = 0xFB3323E24743Caf4ADD0fDCCFB268565c0685556;
      uniV3PooForFlash = 0x293f2B2c17f8cEa4db346D87Ef5712C9dd0491EF; // univ2 0x34a1E3Db82f669f8cF88135422AfD80e4f70701A
      usdcMarketIndex = 1;
      wethMarketIndex = 0;
      // weth 0x4200000000000000000000000000000000000006
      // usdc 0xd988097fb8612cc24eeC14542bC03424c656005f
    }

    authRegistry = AuthoritiesRegistry(ap.getAddress("AuthoritiesRegistry"));
    liquidatorsRegistry = ILiquidatorsRegistry(ap.getAddress("LiquidatorsRegistry"));

    //     liquidator = IonicUniV3Liquidator(ap.getAddress("IonicUniV3Liquidator"));
    liquidator = new IonicUniV3Liquidator();
    liquidator.initialize(ap.getAddress("wtoken"), address(quoter));
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
    asBase._registerExtension(newExt1, DiamondExtension(exts[1]));
    vm.prank(SafeOwnable(address(liquidatorsRegistry)).owner());
    asBase._registerExtension(newExt2, DiamondExtension(exts[0]));
  }

  function _setupLiquidatorsRegistry() internal {
    upgradeRegistry();
  }

  function testPolygonUniV3LiquidatorLiquidate() public debuggingOnly fork(POLYGON_MAINNET) {
    _testUniV3LiquidatorLiquidate();
  }

  function testModeUniV3LiquidatorLiquidate() public debuggingOnly fork(MODE_MAINNET) {
    _testUniV3LiquidatorLiquidate();
  }

  function _testUniV3LiquidatorLiquidate() internal {
    IonicComptroller pool = IonicComptroller(poolAddress);
    _upgradePoolWithExtension(Unitroller(payable(poolAddress)));
    upgradeRegistry();

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
      vm.startPrank(liquidatorsRegistry.owner());
      IRedemptionStrategy strategy = new UniswapV3LiquidatorFunder();
      liquidatorsRegistry._setRedemptionStrategy(strategy, weth, usdc);
      vm.stopPrank();
      vm.prank(liquidator.owner());
      liquidator._whitelistRedemptionStrategy(strategy, true);
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
        flashSwapContract: uniV3PooForFlash,
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
