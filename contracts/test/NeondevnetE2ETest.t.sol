// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { WithPool } from "./helpers/WithPool.sol";
import { BaseTest } from "./config/BaseTest.t.sol";

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FuseFlywheelDynamicRewards } from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { IFundsConversionStrategy } from "../liquidators/IFundsConversionStrategy.sol";
import { IUniswapV2Router02 } from "../external/uniswap/IUniswapV2Router02.sol";
import { IonicComptroller } from "../compound/ComptrollerInterface.sol";
import { PoolLensSecondary } from "../PoolLensSecondary.sol";
import { UniswapLpTokenLiquidator } from "../liquidators/UniswapLpTokenLiquidator.sol";
import { IUniswapV2Pair } from "../external/uniswap/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "../external/uniswap/IUniswapV2Factory.sol";
import { PoolLens } from "../PoolLens.sol";
import { IonicLiquidator } from "../IonicLiquidator.sol";
import { CErc20 } from "../compound/CToken.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { AuthoritiesRegistry } from "../ionic/AuthoritiesRegistry.sol";
import { PoolRolesAuthority } from "../ionic/PoolRolesAuthority.sol";

contract MockWNeon is MockERC20 {
  constructor() MockERC20("test", "test", 18) {}

  function deposit() external payable {}
}

contract NeondevnetE2ETest is WithPool {
  address mpo;
  address moraRouter = 0x491FFC6eE42FEfB4Edab9BA7D5F3e639959E081B;
  address moraToken = 0x6dcDD1620Ce77B595E6490701416f6Dbf20D2f67; // MORA
  address wtoken = 0xf1041596da0499c3438e3B1Eb7b95354C6Aed1f5;
  address wWbtc = 0x6fbF8F06Ebce724272813327255937e7D1E72298;
  address moraUsdc = 0x6Ab1F83c0429A1322D7ECDFdDf54CE6D179d911f;

  struct LiquidationData {
    address[] cTokens;
    uint256 oraclePrice;
    PoolLens.PoolAsset[] assetsData;
    PoolLens.PoolAsset[] assetsDataAfter;
    IRedemptionStrategy[] strategies;
    UniswapLpTokenLiquidator lpLiquidator;
    address[] swapToken0Path;
    address[] swapToken1Path;
    bytes[] abis;
    ICErc20[] allMarkets;
    IonicLiquidator liquidator;
    MockERC20 erc20;
    MockWNeon asset;
    IFundsConversionStrategy[] fundingStrategies;
    bytes[] data;
    uint256 price2;
  }

  function afterForkSetUp() internal override {
    mpo = ap.getAddress("MasterPriceOracle");
    super.setUpWithPool(
      MasterPriceOracle(mpo),
      ERC20Upgradeable(moraToken) // MORA
    );
    deal(address(underlyingToken), address(this), 10e18);
    deal(wtoken, address(this), 10e18);
    setUpPool("neon-test", false, 0.1e18, 1.1e18);
  }

  function testNeonDeployCErc20Delegate() public fork(NEON_MAINNET) {
    vm.roll(1);
    deployCErc20Delegate(address(underlyingToken), "cUnderlyingToken", "CUT", 0.9e18);
    deployCErc20Delegate(wtoken, "cWToken", "wtoken", 0.9e18);

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20 cToken = allMarkets[0];
    ICErc20 cWToken = allMarkets[1];

    assertEq(cToken.name(), "cUnderlyingToken");
    assertEq(cWToken.name(), "cWToken");

    underlyingToken.approve(address(cToken), 1e36);
    ERC20Upgradeable(wtoken).approve(address(cWToken), 1e36);

    address[] memory cTokens = new address[](2);
    cTokens[0] = address(cToken);
    cTokens[1] = address(cWToken);
    comptroller.enterMarkets(cTokens);

    vm.roll(1);
    cToken.mint(10e18);
    assertEq(cToken.totalSupply(), 10e18 * 5);
    assertEq(underlyingToken.balanceOf(address(cToken)), 10e18);

    cWToken.mint(10e18);
    assertEq(cWToken.totalSupply(), 10e18 * 5);
    assertEq(ERC20Upgradeable(wtoken).balanceOf(address(cWToken)), 10e18);

    cWToken.borrow(1000);
    assertEq(cWToken.totalBorrows(), 1000);
    assertEq(ERC20Upgradeable(wtoken).balanceOf(address(this)), 1000);
  }

  function testNeonGetPoolAssetsData() public fork(NEON_MAINNET) {
    vm.roll(1);
    deployCErc20Delegate(address(underlyingToken), "cUnderlyingToken", "CUT", 0.9e18);

    ICErc20[] memory allMarkets = comptroller.getAllMarkets();
    ICErc20 cToken = allMarkets[allMarkets.length - 1];
    assertEq(cToken.name(), "cUnderlyingToken");
    underlyingToken.approve(address(cToken), 1e36);
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(cToken);
    comptroller.enterMarkets(cTokens);

    cToken.mint(10e18);

    PoolLens.PoolAsset[] memory assets = poolLens.getPoolAssetsWithData(IonicComptroller(address(comptroller)));

    assertEq(assets[0].supplyBalance, 10e18);
  }

  function testNeonCErc20Liquidation() public fork(NEON_MAINNET) {
    LiquidationData memory vars;
    vm.roll(1);
    vars.erc20 = MockERC20(moraToken); // MORA
    vars.asset = MockWNeon(wtoken); // WNEON

    deployCErc20Delegate(address(vars.erc20), "MORA", "MoraSwap", 0.9e18);
    deployCErc20Delegate(address(vars.asset), "WNEON", "Wrapped Neon", 0.9e18);
    ionicAdmin.authoritiesRegistry().reconfigureAuthority(address(comptroller));

    vars.allMarkets = comptroller.getAllMarkets();

    ICErc20 cToken = vars.allMarkets[0];
    ICErc20 cWNeonToken = vars.allMarkets[1];

    vars.cTokens = new address[](1);

    // setting up liquidator
    vars.liquidator = new IonicLiquidator();
    vars.liquidator.initialize(
      wtoken, // wneon
      moraRouter, // moraswap router
      30
    );

    address accountOne = address(1);
    address accountTwo = address(2);
    {
      address comptrollerAddress = address(comptroller);
      AuthoritiesRegistry ar = ionicAdmin.authoritiesRegistry();
      PoolRolesAuthority poolAuth = ar.poolsAuthorities(comptrollerAddress);
      ar.setUserRole(comptrollerAddress, accountOne, poolAuth.BORROWER_ROLE(), true);
      ar.setUserRole(comptrollerAddress, accountTwo, poolAuth.BORROWER_ROLE(), true);
      ar.setUserRole(comptrollerAddress, address(vars.liquidator), poolAuth.LIQUIDATOR_ROLE(), true);
    }

    PoolLensSecondary secondary = new PoolLensSecondary();
    secondary.initialize(poolDirectory);

    // Accounts pre supply
    deal(address(underlyingToken), accountTwo, 10000e18);
    deal(address(vars.asset), accountOne, 10000e18);

    // Account One Supply
    vm.startPrank(accountOne);
    vars.asset.approve(address(cWNeonToken), 1e36);
    require(cWNeonToken.mint(1e19) == 0, "failed to mint cWNeonToken");
    vars.cTokens[0] = address(cWNeonToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    // Account Two Supply
    vm.startPrank(accountTwo);
    underlyingToken.approve(address(cToken), 1e36);
    require(cToken.mint(10e18) == 0, "failed to mint cToken");
    vars.cTokens[0] = address(cToken);
    comptroller.enterMarkets(vars.cTokens);
    vm.stopPrank();

    assertEq(cToken.totalSupply(), 10e18 * 5, "!ctoken total supply");
    assertEq(cWNeonToken.totalSupply(), 1e19 * 5, "!cWNeonToken total supply");

    // Account One Borrow
    vm.startPrank(accountOne);
    require(cToken.borrow(1e16) == 0, "failed to borrow");
    vm.stopPrank();
    assertEq(cToken.totalBorrows(), 1e16, "!ctoken total borrows");

    vars.price2 = priceOracle.getUnderlyingPrice(ICErc20(address(cWNeonToken)));
    vm.mockCall(
      mpo,
      abi.encodeWithSelector(priceOracle.getUnderlyingPrice.selector, ICErc20(address(cWNeonToken))),
      abi.encode(vars.price2 / 10000)
    );

    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);
    vars.fundingStrategies = new IFundsConversionStrategy[](0);
    vars.data = new bytes[](0);

    vm.startPrank(accountOne);
    PoolLens.PoolAsset[] memory assetsData = poolLens.getPoolAssetsWithData(IonicComptroller(address(comptroller)));
    uint256 neonBalance = cWNeonToken.balanceOf(accountOne);

    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(moraRouter);
    address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(address(underlyingToken), wtoken);
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(pairAddress);

    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      IonicLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        4e13,
        ICErc20(address(cToken)),
        ICErc20(address(cWNeonToken)),
        flashSwapPair,
        0,
        uniswapRouter,
        uniswapRouter,
        vars.strategies,
        vars.abis,
        vars.fundingStrategies,
        vars.data
      )
    );

    PoolLens.PoolAsset[] memory assetsDataAfter = poolLens.getPoolAssetsWithData(
      IonicComptroller(address(comptroller))
    );

    uint256 neonBalanceAfter = cWNeonToken.balanceOf(accountOne);

    assertGt(neonBalance, neonBalanceAfter, "!balance after > before");
    assertGt(assetsData[1].supplyBalance, assetsDataAfter[1].supplyBalance, "!supply balance after > before");

    vm.stopPrank();
  }
}