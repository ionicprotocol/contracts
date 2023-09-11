// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MarketsTest, BaseTest } from "./config/MarketsTest.t.sol";
import { DiamondBase, DiamondExtension } from "../ionic/DiamondExtension.sol";

import { LeveredPosition } from "../ionic/levered/LeveredPosition.sol";
import { LeveredPositionFactory, IFeeDistributor } from "../ionic/levered/LeveredPositionFactory.sol";
import { JarvisLiquidatorFunder } from "../liquidators/JarvisLiquidatorFunder.sol";
import { BalancerSwapLiquidator } from "../liquidators/BalancerSwapLiquidator.sol";
import { AlgebraSwapLiquidator } from "../liquidators/AlgebraSwapLiquidator.sol";
import { SolidlyLpTokenLiquidator, SolidlyLpTokenWrapper } from "../liquidators/SolidlyLpTokenLiquidator.sol";
import { SolidlySwapLiquidator } from "../liquidators/SolidlySwapLiquidator.sol";

import { CurveLpTokenLiquidatorNoRegistry } from "../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import { LeveredPositionFactoryFirstExtension } from "../ionic/levered/LeveredPositionFactoryFirstExtension.sol";
import { LeveredPositionFactorySecondExtension } from "../ionic/levered/LeveredPositionFactorySecondExtension.sol";
import { ILeveredPositionFactory } from "../ionic/levered/ILeveredPositionFactory.sol";
import { LeveredPositionsLens } from "../ionic/levered/LeveredPositionsLens.sol";
import { LiquidatorsRegistry } from "../liquidators/registry/LiquidatorsRegistry.sol";
import { LiquidatorsRegistryExtension } from "../liquidators/registry/LiquidatorsRegistryExtension.sol";
import { LiquidatorsRegistrySecondExtension } from "../liquidators/registry/LiquidatorsRegistrySecondExtension.sol";
import { ILiquidatorsRegistry } from "../liquidators/registry/ILiquidatorsRegistry.sol";
import { IRedemptionStrategy } from "../liquidators/IRedemptionStrategy.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";
import { IonicComptroller } from "../compound/ComptrollerInterface.sol";
import { ComptrollerFirstExtension } from "../compound/ComptrollerFirstExtension.sol";
import { SafeOwnable } from "../ionic/SafeOwnable.sol";
import { PoolRolesAuthority } from "../ionic/PoolRolesAuthority.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract LeveredPositionLensTest is BaseTest {
  LeveredPositionsLens lens;
  ILeveredPositionFactory factory;

  function afterForkSetUp() internal override {
    factory = ILeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    lens = LeveredPositionsLens(ap.getAddress("LeveredPositionsLens"));
    //    lens = new LeveredPositionsLens();
    //    lens.initialize(factory);
  }

  function testLPLens() public debuggingOnly fork(BSC_CHAPEL) {
    _testLPLens();
  }

  function _testLPLens() internal {
    address[] memory positions;
    bool[] memory closed;
    (positions, closed) = factory.getPositionsByAccount(0xb6c11605e971ab46B9BE4fDC48C9650A257075db);

    //    address[] memory accounts = factory.getAccountsWithOpenPositions();
    //    for (uint256 i = 0; i < accounts.length; i++) {
    //      (positions, closed) = factory.getPositionsByAccount(accounts[i]);
    //      if (positions.length > 0) break;
    //    }

    uint256[] memory apys = new uint256[](positions.length);
    LeveredPosition[] memory pos = new LeveredPosition[](positions.length);
    for (uint256 j = 0; j < positions.length; j++) {
      apys[j] = 1e17;

      if (address(0) == positions[j]) revert("zero pos address");
      pos[j] = LeveredPosition(positions[j]);
    }

    LeveredPositionsLens.PositionInfo[] memory infos = lens.getPositionsInfo(pos, apys);

    for (uint256 k = 0; k < infos.length; k++) {
      emit log_named_address("address", address(pos[k]));
      emit log_named_uint("positionSupplyAmount", infos[k].positionSupplyAmount);
      emit log_named_uint("positionValue", infos[k].positionValue);
      emit log_named_uint("debtAmount", infos[k].debtAmount);
      emit log_named_uint("debtValue", infos[k].debtValue);
      emit log_named_uint("equityValue", infos[k].equityValue);
      emit log_named_uint("equityAmount", infos[k].equityAmount);
      emit log_named_int("currentApy", infos[k].currentApy);
      emit log_named_uint("debtRatio", infos[k].debtRatio);
      emit log_named_uint("liquidationThreshold", infos[k].liquidationThreshold);
      emit log_named_uint("safetyBuffer", infos[k].safetyBuffer);

      emit log("");
    }
  }
}

contract LeveredPositionFactoryTest is BaseTest {
  ILeveredPositionFactory factory;
  LeveredPositionsLens lens;

  function afterForkSetUp() internal override {
    factory = ILeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    lens = LeveredPositionsLens(ap.getAddress("LeveredPositionsLens"));
  }

  function testChapelNetApy() public debuggingOnly fork(BSC_CHAPEL) {
    ICErc20 _stableMarket = ICErc20(address(1)); // DAI

    uint256 borrowRate = 5.2e16; // 5.2%
    vm.mockCall(
      address(_stableMarket),
      abi.encodeWithSelector(_stableMarket.borrowRatePerBlock.selector),
      abi.encode(borrowRate / factory.blocksPerYear())
    );

    {
      // upgrade the factory
      LeveredPositionFactoryFirstExtension newExt1 = new LeveredPositionFactoryFirstExtension();
      LeveredPositionFactorySecondExtension newExt2 = new LeveredPositionFactorySecondExtension();

      vm.startPrank(factory.owner());
      DiamondBase asBase = DiamondBase(address(factory));
      address[] memory oldExts = asBase._listExtensions();
      if (oldExts.length == 1) {
        asBase._registerExtension(newExt1, DiamondExtension(oldExts[0]));
        asBase._registerExtension(newExt2, DiamondExtension(address(0)));
      } else if (oldExts.length == 2) {
        asBase._registerExtension(newExt1, DiamondExtension(oldExts[0]));
        asBase._registerExtension(newExt2, DiamondExtension(oldExts[1]));
      }
      vm.stopPrank();
    }

    uint256 _borrowRate = _stableMarket.borrowRatePerBlock() * factory.blocksPerYear();
    emit log_named_uint("_borrowRate", _borrowRate);

    int256 netApy = lens.getNetAPY(
      2.7e16, // 2.7%
      1e18, // supply amount
      ICErc20(address(0)), // BOMB
      _stableMarket,
      2e18 // ratio
    );

    emit log_named_int("net apy", netApy);

    // boosted APY = 2x 2.7% = 5.4 % of the equity
    // borrow APR = 5.2%
    // diff = 5.4 - 5.2 = 0.2%
    assertApproxEqRel(netApy, 0.2e16, 1e12, "!net apy");
  }
}

abstract contract LeveredPositionTest is MarketsTest {
  ICErc20 collateralMarket;
  ICErc20 stableMarket;
  ILeveredPositionFactory factory;
  ILiquidatorsRegistry registry;
  LeveredPosition position;
  LeveredPositionsLens lens;

  uint256 minLevRatio;
  uint256 maxLevRatio;

  function afterForkSetUp() internal virtual override {
    super.afterForkSetUp();

    factory = ILeveredPositionFactory(ap.getAddress("LeveredPositionFactory"));
    registry = factory.liquidatorsRegistry();
    //    {
    //      // upgrade the factory
    //      LeveredPositionFactoryFirstExtension newExt1 = new LeveredPositionFactoryFirstExtension();
    //      LeveredPositionFactorySecondExtension newExt2 = new LeveredPositionFactorySecondExtension();
    //
    //      vm.startPrank(factory.owner());
    //      DiamondBase asBase = DiamondBase(address(factory));
    //      address[] memory oldExts = asBase._listExtensions();
    //
    //      if (oldExts.length == 1) {
    //        asBase._registerExtension(newExt1, DiamondExtension(oldExts[0]));
    //        asBase._registerExtension(newExt2, DiamondExtension(address(0)));
    //      } else if (oldExts.length == 2) {
    //        asBase._registerExtension(newExt1, DiamondExtension(oldExts[0]));
    //        asBase._registerExtension(newExt2, DiamondExtension(oldExts[1]));
    //      }
    //      vm.stopPrank();
    //    }

    lens = LeveredPositionsLens(ap.getAddress("LeveredPositionsLens"));
  }

  function upgradeRegistry() internal {
    DiamondBase asBase = DiamondBase(address(registry));
    address[] memory exts = asBase._listExtensions();
    LiquidatorsRegistryExtension newExt1 = new LiquidatorsRegistryExtension();
    LiquidatorsRegistrySecondExtension newExt2 = new LiquidatorsRegistrySecondExtension();
    vm.prank(SafeOwnable(address(registry)).owner());
    asBase._registerExtension(newExt1, DiamondExtension(exts[0]));
    vm.prank(SafeOwnable(address(registry)).owner());
    asBase._registerExtension(newExt2, DiamondExtension(exts[1]));
  }

  function upgradePoolAndMarkets() internal {
    _upgradeExistingPool(address(collateralMarket.comptroller()));
    _upgradeMarket(collateralMarket);
    _upgradeMarket(stableMarket);
  }

  function _unpauseMarkets(address collat, address stable) internal {
    ComptrollerFirstExtension asExtension = ComptrollerFirstExtension(address(ICErc20(stable).comptroller()));
    vm.startPrank(asExtension.admin());
    asExtension._setMintPaused(ICErc20(collat), false);
    asExtension._setMintPaused(ICErc20(stable), false);
    asExtension._setBorrowPaused(ICErc20(stable), false);
    vm.stopPrank();
  }

  function _configurePairAndLiquidator(
    address _collat,
    address _stable,
    IRedemptionStrategy _liquidator
  ) internal {
    _configurePair(_collat, _stable);
    _configureTwoWayLiquidator(_collat, _stable, _liquidator);
  }

  function _configurePair(address _collat, address _stable) internal {
    collateralMarket = ICErc20(_collat);
    stableMarket = ICErc20(_stable);

    //upgradePoolAndMarkets();
    //_unpauseMarkets(_collat, _stable);
    vm.prank(factory.owner());
    factory._setPairWhitelisted(collateralMarket, stableMarket, true);
  }

  function _whitelistTestUser(address user) internal {
    address pool = address(collateralMarket.comptroller());
    PoolRolesAuthority pra = ffd.authoritiesRegistry().poolsAuthorities(pool);

    vm.startPrank(pra.owner());
    pra.setUserRole(user, pra.BORROWER_ROLE(), true);
    vm.stopPrank();
  }

  function _configureTwoWayLiquidator(
    address inputMarket,
    address outputMarket,
    IRedemptionStrategy strategy
  ) internal {
    IERC20Upgradeable inputToken = underlying(inputMarket);
    IERC20Upgradeable outputToken = underlying(outputMarket);
    vm.startPrank(registry.owner());
    registry._setRedemptionStrategy(strategy, inputToken, outputToken);
    registry._setRedemptionStrategy(strategy, outputToken, inputToken);
    vm.stopPrank();
  }

  function underlying(address market) internal view returns (IERC20Upgradeable) {
    return IERC20Upgradeable(ICErc20(market).underlying());
  }

  struct Liquidator {
    IERC20Upgradeable inputToken;
    IERC20Upgradeable outputToken;
    IRedemptionStrategy strategy;
  }

  function _configureMultipleLiquidators(Liquidator[] memory liquidators) internal {
    IRedemptionStrategy[] memory strategies = new IRedemptionStrategy[](liquidators.length);
    IERC20Upgradeable[] memory inputTokens = new IERC20Upgradeable[](liquidators.length);
    IERC20Upgradeable[] memory outputTokens = new IERC20Upgradeable[](liquidators.length);
    for (uint256 i = 0; i < liquidators.length; i++) {
      strategies[i] = liquidators[i].strategy;
      inputTokens[i] = liquidators[i].inputToken;
      outputTokens[i] = liquidators[i].outputToken;
    }
    vm.startPrank(registry.owner());
    registry._setRedemptionStrategies(strategies, inputTokens, outputTokens);
    vm.stopPrank();
  }

  function _fundMarketAndSelf(ICErc20 market, address whale) internal {
    IERC20Upgradeable token = IERC20Upgradeable(market.underlying());

    if (whale == address(0)) {
      whale = address(911);
      //vm.deal(address(token), whale, 100e18);
    }

    uint256 allTokens = token.balanceOf(whale);
    vm.prank(whale);
    token.transfer(address(this), allTokens / 20);

    if (market.getCash() < allTokens / 2) {
      _whitelistTestUser(whale);
      vm.startPrank(whale);
      token.approve(address(market), allTokens / 2);
      market.mint(allTokens / 2);
      vm.stopPrank();
    }
  }

  function _openLeveredPosition(address _positionOwner, uint256 _depositAmount)
    internal
    returns (
      LeveredPosition _position,
      uint256 _maxRatio,
      uint256 _minRatio
    )
  {
    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    collateralToken.transfer(_positionOwner, _depositAmount);

    vm.startPrank(_positionOwner);
    collateralToken.approve(address(factory), _depositAmount);
    _position = factory.createAndFundPosition(collateralMarket, stableMarket, collateralToken, _depositAmount);
    vm.stopPrank();

    _maxRatio = _position.getMaxLeverageRatio();
    emit log_named_uint("max ratio", _maxRatio);
    _minRatio = _position.getMinLeverageRatio();
    emit log_named_uint("min ratio", _minRatio);

    assertGt(_maxRatio, _minRatio, "max ratio <= min ratio");
  }

  function testOpenLeveredPosition() public virtual whenForking {
    assertApproxEqRel(position.getCurrentLeverageRatio(), 1e18, 4e16, "initial leverage ratio should be 1.0 (1e18)");
  }

  function testAnyLeverageRatio(uint64 ratioDiff) public debuggingOnly whenForking {
    // ratioDiff is between 0 and 2^64 ~= 18.446e18
    uint256 targetLeverageRatio = 1e18 + uint256(ratioDiff);
    emit log_named_uint("fuzz max ratio", maxLevRatio);
    emit log_named_uint("fuzz min ratio", minLevRatio);
    emit log_named_uint("target ratio", targetLeverageRatio);
    vm.assume(targetLeverageRatio < maxLevRatio);
    vm.assume(minLevRatio < targetLeverageRatio);

    uint256 borrowedAssetPrice = stableMarket.comptroller().oracle().getUnderlyingPrice(stableMarket);
    (uint256 sd, uint256 bd) = position.getSupplyAmountDelta(targetLeverageRatio);
    emit log_named_uint("borrows delta val", (bd * borrowedAssetPrice) / 1e18);
    emit log_named_uint("min borrow value", ffd.getMinBorrowEth(stableMarket));

    uint256 equityAmount = position.getEquityAmount();
    emit log_named_uint("equity amount", equityAmount);

    uint256 currentLeverageRatio = position.getCurrentLeverageRatio();
    emit log_named_uint("current ratio", currentLeverageRatio);

    uint256 leverageRatioRealized = position.adjustLeverageRatio(targetLeverageRatio);
    emit log_named_uint("equity amount", position.getEquityAmount());
    assertApproxEqRel(leverageRatioRealized, targetLeverageRatio, 4e16, "target ratio not matching");
  }

  function testMinMaxLeverageRatio() public whenForking {
    assertGt(maxLevRatio, minLevRatio, "max ratio <= min ratio");

    // attempting to adjust to minLevRatio - 0.01 should fail
    vm.expectRevert(abi.encodeWithSelector(LeveredPosition.BorrowStableFailed.selector, 0x3fa));
    position.adjustLeverageRatio((minLevRatio + 1e18) / 2);
    // just testing
    position.adjustLeverageRatio(maxLevRatio);
    // but adjusting to the minLevRatio + 0.01 should succeed
    position.adjustLeverageRatio(minLevRatio + 0.01e18);
  }

  function testMaxLeverageRatio() public whenForking {
    uint256 _equityAmount = position.getEquityAmount();
    uint256 rate = lens.getBorrowRateAtRatio(collateralMarket, stableMarket, _equityAmount, maxLevRatio);
    emit log_named_uint("borrow rate at max ratio", rate);

    position.adjustLeverageRatio(maxLevRatio);
    assertApproxEqRel(position.getCurrentLeverageRatio(), maxLevRatio, 4e16, "target max ratio not matching");
  }

  function testRewardsAccruedClaimed() public whenForking {
    address[] memory flywheels = position.pool().getRewardsDistributors();
    if (flywheels.length > 0) {
      vm.warp(block.timestamp + 60 * 60 * 24);
      vm.roll(block.number + 10000);

      (ERC20[] memory rewardTokens, uint256[] memory amounts) = position.getAccruedRewards();

      ERC20 rewardToken;
      bool atLeastOneAccrued = false;
      for (uint256 i = 0; i < amounts.length; i++) {
        atLeastOneAccrued = amounts[i] > 0;
        if (atLeastOneAccrued) {
          rewardToken = rewardTokens[i];
          emit log_named_address("accrued from reward token", address(rewardTokens[i]));
          break;
        }
      }

      assertEq(atLeastOneAccrued, true, "!should have accrued at least one reward token");

      if (atLeastOneAccrued) {
        uint256 rewardsBalanceBefore = rewardToken.balanceOf(address(this));
        position.claimRewards();
        uint256 rewardsBalanceAfter = rewardToken.balanceOf(address(this));
        assertGt(rewardsBalanceAfter - rewardsBalanceBefore, 0, "should have claimed some rewards");
      }
    } else {
      emit log("no flywheels/rewards for the pair pool");
    }
  }

  function testLeverMaxDown() public whenForking {
    IERC20Upgradeable stableAsset = IERC20Upgradeable(stableMarket.underlying());
    IERC20Upgradeable collateralAsset = IERC20Upgradeable(collateralMarket.underlying());
    uint256 startingEquity = position.getEquityAmount();

    uint256 leverageRatioRealized = position.adjustLeverageRatio(maxLevRatio);
    assertApproxEqRel(leverageRatioRealized, maxLevRatio, 4e16, "target ratio not matching");

    // decrease the ratio in 10 equal steps
    uint256 ratioDiffStep = (maxLevRatio - 1e18) / 9;
    while (leverageRatioRealized > 1e18) {
      uint256 targetLeverDownRatio = leverageRatioRealized - ratioDiffStep;
      if (targetLeverDownRatio < minLevRatio) targetLeverDownRatio = 1e18;
      leverageRatioRealized = position.adjustLeverageRatio(targetLeverDownRatio);
      assertApproxEqRel(leverageRatioRealized, targetLeverDownRatio, 3e16, "target lever down ratio not matching");
    }

    uint256 withdrawAmount = position.closePosition();
    emit log_named_uint("withdraw amount", withdrawAmount);
    assertApproxEqRel(startingEquity, withdrawAmount, 5e16, "!withdraw amount");

    assertEq(position.getEquityAmount(), 0, "!nonzero equity amount");
    assertEq(position.getCurrentLeverageRatio(), 0, "!nonzero leverage ratio");
  }
}

contract WMaticStMaticLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 200e18;

    address wmaticMarket = 0x4017cd39950d1297BBd9713D939bC5d9c6F2Be53;
    address stmaticMarket = 0xc1B068007114dC0F14f322Ef201491717f3e52cD;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address stmaticWhale = 0x52997D5abC01e9BFDd29cccB183ffc60F6d6bF8c;

    BalancerSwapLiquidator balancerSwapLiquidator = new BalancerSwapLiquidator();
    _configurePairAndLiquidator(wmaticMarket, stmaticMarket, balancerSwapLiquidator);
    _fundMarketAndSelf(ICErc20(wmaticMarket), wmaticWhale);
    _fundMarketAndSelf(ICErc20(stmaticMarket), stmaticWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract JbrlBusdLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 2000e18;

    address jbrlMarket = 0x82A3103bc306293227B756f7554AfAeE82F8ab7a;
    address busdMarket = 0xa7213deB44f570646Ea955771Cc7f39B58841363;
    address jbrlWhale = 0xBe9E8Ec25866B21bA34e97b9393BCabBcB4A5C86;

    vm.startPrank(ap.owner());
    ap.setJarvisPool(
      ICErc20(jbrlMarket).underlying(), // syntheticToken
      ICErc20(busdMarket).underlying(), // collateralToken
      0x0fD8170Dc284CD558325029f6AEc1538c7d99f49, // liquidityPool
      60 * 40 // expirationTime
    );
    vm.stopPrank();

    JarvisLiquidatorFunder liquidator = new JarvisLiquidatorFunder();
    _configurePairAndLiquidator(jbrlMarket, busdMarket, liquidator);
    _fundMarketAndSelf(ICErc20(jbrlMarket), jbrlWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract WmaticMaticXLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    upgradeRegistry();

    uint256 depositAmount = 500e18;

    address wmaticMarket = 0xCb8D7c2690536d3444Da3d207f62A939483c8A93;
    address maticxMarket = 0x6ebdbEe1a509247B4A3ac3b73a43bd434C52C7c2;
    address wmaticWhale = 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97;
    address maticxWhale = 0x72f0275444F2aF8dBf13F78D54A8D3aD7b6E68db;

    _configurePair(wmaticMarket, maticxMarket);
    _fundMarketAndSelf(ICErc20(wmaticMarket), wmaticWhale);
    _fundMarketAndSelf(ICErc20(maticxMarket), maticxWhale);

    // call amountOutAndSlippageOfSwap to cache the slippage
    {
      IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
      IERC20Upgradeable stableToken = IERC20Upgradeable(stableMarket.underlying());

      vm.startPrank(wmaticWhale);
      collateralToken.approve(address(registry), 1e36);
      registry.amountOutAndSlippageOfSwap(collateralToken, 100e18, stableToken);
      vm.stopPrank();
      vm.startPrank(maticxWhale);
      stableToken.approve(address(registry), 1e36);
      registry.amountOutAndSlippageOfSwap(stableToken, 100e18, collateralToken);
      vm.stopPrank();

      emit log_named_uint("slippage coll->stable", registry.getSlippage(collateralToken, stableToken));
      emit log_named_uint("slippage stable->coll", registry.getSlippage(stableToken, collateralToken));
    }

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract StkBnbWBnbLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 2e18;

    address stkBnbMarket = 0xAcfbf93d8fD1A9869bAb2328669dDba33296a421;
    address wbnbMarket = 0x3Af258d24EBdC03127ED6cEb8e58cA90835fbca5;
    address stkBnbWhale = 0x84b78452A97C5afDa1400943333F691448069A29; // algebra pool
    address wbnbWhale = 0x84b78452A97C5afDa1400943333F691448069A29; // algebra pool

    AlgebraSwapLiquidator liquidator = new AlgebraSwapLiquidator();
    _configurePairAndLiquidator(stkBnbMarket, wbnbMarket, liquidator);
    _fundMarketAndSelf(ICErc20(stkBnbMarket), stkBnbWhale);
    _fundMarketAndSelf(ICErc20(wbnbMarket), wbnbWhale);

    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    collateralToken.transfer(address(this), depositAmount);
    collateralToken.approve(address(factory), depositAmount);
    position = factory.createAndFundPosition(collateralMarket, stableMarket, collateralToken, depositAmount);
  }
}

interface TwoBrl {
  function minter() external view returns (address);

  function mint(address payable _to, uint256 _value) external returns (bool);
}

contract Jbrl2BrlLeveredPositionTest is LeveredPositionTest {
  IonicComptroller pool;
  ComptrollerFirstExtension asExtension;

  function setUp() public fork(BSC_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1000e18;

    address twoBrlMarket = 0xf0a2852958aD041a9Fb35c312605482Ca3Ec17ba; // 2brl as collateral
    address jBrlMarket = 0x82A3103bc306293227B756f7554AfAeE82F8ab7a; // jbrl as borrowable
    address payable twoBrlWhale = payable(address(177)); // empty account
    address jBrlWhale = 0xA0695f78AF837F570bcc50f53e58Cda300798B65; // solidly pair BRZ-JBRL

    TwoBrl twoBrl = TwoBrl(ICErc20(twoBrlMarket).underlying());
    vm.prank(twoBrl.minter());
    twoBrl.mint(twoBrlWhale, depositAmount * 100);

    _configurePair(twoBrlMarket, jBrlMarket);
    _fundMarketAndSelf(ICErc20(twoBrlMarket), twoBrlWhale);
    _fundMarketAndSelf(ICErc20(jBrlMarket), jBrlWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract Par2EurLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 2000e18;

    address twoEurMarket = 0x1944FA4a490f85Ed99e2c6fF9234F94DE16fdbde;
    address parMarket = 0xCA1A940B02E15FF71C128f877b29bdb739785299;
    address twoEurWhale = address(888);
    address balancer = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address parWhale = 0xFa22D298E3b0bc1752E5ef2849cEc1149d596674; // uniswap pool

    IERC20Upgradeable twoEur = IERC20Upgradeable(ICErc20(twoEurMarket).underlying());
    vm.prank(balancer);
    twoEur.transfer(twoEurWhale, 80 * depositAmount);

    _configurePair(twoEurMarket, parMarket);
    _fundMarketAndSelf(ICErc20(twoEurMarket), twoEurWhale);
    _fundMarketAndSelf(ICErc20(parMarket), parWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract MaticXMaticXBbaWMaticLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1000e18;

    address maticXBbaWMaticMarket = 0x13e763D25D78c3Fd6FEA534231BdaEBE7Fa52945;
    address maticXMarket = 0x0db51E5255E44751b376738d8979D969AD70bff6;
    address maticXBbaWMaticWhale = 0xB0B28d7A74e62DF5F6F9E0d9Ae0f4e7982De9585;
    address maticXWhale = 0x72f0275444F2aF8dBf13F78D54A8D3aD7b6E68db;

    IonicComptroller pool = IonicComptroller(ICErc20(maticXBbaWMaticMarket).comptroller());
    _configurePairAndLiquidator(maticXBbaWMaticMarket, maticXMarket, new BalancerSwapLiquidator());

    {
      vm.prank(pool.admin());
      pool._supplyCapWhitelist(address(maticXBbaWMaticMarket), maticXBbaWMaticWhale, true);
    }

    _fundMarketAndSelf(ICErc20(maticXBbaWMaticMarket), maticXBbaWMaticWhale);
    _fundMarketAndSelf(ICErc20(maticXMarket), maticXWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);

    {
      vm.prank(pool.admin());
      pool._supplyCapWhitelist(address(maticXBbaWMaticMarket), address(position), true);
    }
  }
}

contract BombTDaiLeveredPositionTest is LeveredPositionTest {
  uint256 depositAmount = 100e18;
  address whale = 0xe7B7dF67C1fe053f1C6B965826d3bFF19603c482;
  uint256 ratioOnCreation = 1.0e18;
  uint256 minBorrowNative = 1e17;

  function setUp() public fork(BSC_CHAPEL) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    upgradeRegistry();

    vm.mockCall(
      address(ffd),
      abi.encodeWithSelector(IFeeDistributor.minBorrowEth.selector),
      abi.encode(minBorrowNative)
    );

    address xMarket = 0x11771Cd06dB2633EF6A0cEef027E8e1A120d3f25; // BOMB
    address yMarket = 0x66b05c1711094c32c99a65d2734C72dE0A1C3c81; // tdai

    collateralMarket = ICErc20(xMarket);
    stableMarket = ICErc20(yMarket);

    //upgradePoolAndMarkets();

    IERC20Upgradeable collateralToken = IERC20Upgradeable(collateralMarket.underlying());
    IERC20Upgradeable stableToken = IERC20Upgradeable(stableMarket.underlying());
    // call amountOutAndSlippageOfSwap to cache the slippage
    vm.startPrank(whale);
    {
      collateralToken.approve(address(registry), 1e36);
      registry.amountOutAndSlippageOfSwap(collateralToken, 1e18, stableToken);
      stableToken.approve(address(registry), 1e36);
      registry.amountOutAndSlippageOfSwap(stableToken, 1e18, collateralToken);

      collateralToken.transfer(address(this), depositAmount);
    }
    vm.stopPrank();

    vm.prank(whale);
    collateralToken.transfer(address(this), depositAmount);

    collateralToken.approve(address(factory), depositAmount);
    position = factory.createAndFundPositionAtRatio(
      collateralMarket,
      stableMarket,
      collateralToken,
      depositAmount,
      ratioOnCreation
    );

    maxLevRatio = position.getMaxLeverageRatio();
    minLevRatio = position.getMinLeverageRatio();

    vm.label(address(position), "Levered Position");
  }
}

contract PearlWUsdrWUsdrUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 0.000002e18;

    address lpTokenMarket = 0x06F61E22ef144f1cC4550D40ffbF681CB1C3aCAF;
    address wusdrMarket = 0x26EA46e975778662f98dAa0E7a12858dA9139262;
    address lpTokenWhale = 0x03Fa7A2628D63985bDFe07B95d4026663ED96065;
    address wUsdrWhale = 0x8711a1a52c34EDe8E61eF40496ab2618a8F6EA4B;

    _configurePair(lpTokenMarket, wusdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(wusdrMarket), wUsdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrWUsdrUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 0.000002e18;

    address lpTokenMarket = 0x06F61E22ef144f1cC4550D40ffbF681CB1C3aCAF;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0x03Fa7A2628D63985bDFe07B95d4026663ED96065;
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdcUsdrLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 800e9;

    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address usdcMarket = 0x71A7037a42D0fB9F905a76B7D16846b2EACC59Aa;
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;
    address usdcWhale = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;

    IRedemptionStrategy liquidator = new SolidlySwapLiquidator();
    _configurePairAndLiquidator(usdrMarket, usdcMarket, liquidator);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);
    _fundMarketAndSelf(ICErc20(usdcMarket), usdcWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdcUsdcUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 10e9;

    // LP token underlying 0xD17cb0f162f133e339C0BbFc18c36c357E681D6b
    address lpTokenMarket = 0x83DF24fE1B1eBF38048B91ffc4a8De0bAa88b891;
    address usdcMarket = 0x71A7037a42D0fB9F905a76B7D16846b2EACC59Aa;
    address lpTokenWhale = 0x97Bd59A8202F8263C2eC39cf6cF6B438D0B45876; // Thena Gauge
    address usdcWhale = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;

    _configurePair(lpTokenMarket, usdcMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdcMarket), usdcWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrUsdcUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 10e9;

    // LP token underlying 0xD17cb0f162f133e339C0BbFc18c36c357E681D6b
    address lpTokenMarket = 0x83DF24fE1B1eBF38048B91ffc4a8De0bAa88b891;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0x97Bd59A8202F8263C2eC39cf6cF6B438D0B45876; // Thena Gauge
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrDaiUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 2e18;

    // LP token underlying 0xBD02973b441Aa83c8EecEA158b98B5984bb1036E
    address lpTokenMarket = 0xBcE30B4D78cEb9a75A1Aa62156529c3592b3F08b;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0x85Fa2331040933A02b154579fAbE6A6a5A765279; // Thena Gauge
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrTngblUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 0.02e18;

    // LP token underlying 0x0Edc235693C20943780b76D79DD763236E94C751
    address lpTokenMarket = 0x2E870Aeee3D9d1eA29Ec93d2c0A99A4e0D5EB697;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0xdaeF32cA8D699015fcFB2884F6902fFCebE51c5b; // Thena Gauge
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrWbtcUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 0.000000071325342755e18;

    // LP token underlying 0xb95E1C22dd965FafE926b2A793e9D6757b6613F4
    address lpTokenMarket = 0xffc8c8d747E52fAfbf973c64Bab10d38A6902c46;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0x39976f6328ebA2a3C860b7DE5cF2c1bB41581FB8; // Thena Gauge
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrWethUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 0.004081e18;

    // LP token underlying 0x343D9a8D2Bc6A62390aEc764bb5b900C4B039127
    address lpTokenMarket = 0x343D9a8D2Bc6A62390aEc764bb5b900C4B039127;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0x7D02A8b758791A03319102f81bF61E220F73e43D; // Thena Gauge
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract PearlUsdrMaticUsdrLpLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 0.05e18;

    // LP token underlying vAMM-WMATIC/USDR
    address lpTokenMarket = 0xfacEdA4f9731797102f040380aD5e234c92d1942;
    address usdrMarket = 0x1F11940B239D129dE0e5D30A3E59089af5Ecd6ed;
    address lpTokenWhale = 0xdA0AfBeEEBef6dA2F060237D35cab759b99B13B6; // Thena Gauge
    address usdrWhale = 0x00e8c0E92eB3Ad88189E7125Ec8825eDc03Ab265;

    _configurePair(lpTokenMarket, usdrMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdrMarket), usdrWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract RetroCashAUsdcCashLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();
    upgradeRegistry();

    uint256 depositAmount = 700e18;

    // LP token underlying xCASH-USDC
    address lpTokenMarket = 0x1D2A7078a404ab970f951d5A6dbECD9e24838FB6;
    address cashMarket = 0xf69207CFDe6228A1e15A34F2b0c4fDe0845D9eBa;
    address lpTokenWhale = 0x38e481367E0c50f4166AD2A1C9fde0E3c662CFBa;
    address cashWhale = 0x88C522E526E5Eea8d636fd6805cA7fEB488780D0;

    _configurePair(lpTokenMarket, cashMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(cashMarket), cashWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract RetroUsdcAUsdcCashLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 700e18;

    // LP token underlying xCASH-USDC
    address lpTokenMarket = 0x1D2A7078a404ab970f951d5A6dbECD9e24838FB6;
    address usdcMarket = 0x38EbA94210bCEf3F9231E1764EE230abC14D1cbc;
    address lpTokenWhale = 0x38e481367E0c50f4166AD2A1C9fde0E3c662CFBa;
    address usdcWhale = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;

    _configurePair(lpTokenMarket, usdcMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdcMarket), usdcWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract RetroUsdcAUsdcWethLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 8e18;

    // LP token underlying xUSDC-WETH05
    address lpTokenMarket = 0xC7cA03A0bE1dBAc350E5BfE5050fC5af6406490E;
    address usdcMarket = 0x38EbA94210bCEf3F9231E1764EE230abC14D1cbc;
    address lpTokenWhale = 0x38e481367E0c50f4166AD2A1C9fde0E3c662CFBa;
    address usdcWhale = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;

    _configurePair(lpTokenMarket, usdcMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(usdcMarket), usdcWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract RetroCashAUsdcWethLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 8e18;

    // LP token underlying xUSDC-WETH05
    address lpTokenMarket = 0xC7cA03A0bE1dBAc350E5BfE5050fC5af6406490E;
    address cashMarket = 0xf69207CFDe6228A1e15A34F2b0c4fDe0845D9eBa;
    address lpTokenWhale = 0x38e481367E0c50f4166AD2A1C9fde0E3c662CFBa;
    address cashWhale = 0x88C522E526E5Eea8d636fd6805cA7fEB488780D0;

    _configurePair(lpTokenMarket, cashMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(cashMarket), cashWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

contract RetroCashAWbtcWethLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(POLYGON_MAINNET) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 5e18;

    // LP token underlying xWBTC-WETH05
    address lpTokenMarket = 0xCB1a06eff3459078c26516ae3a1dB44A61D2DbCA;
    address cashMarket = 0xf69207CFDe6228A1e15A34F2b0c4fDe0845D9eBa;
    address lpTokenWhale = 0x38e481367E0c50f4166AD2A1C9fde0E3c662CFBa;
    address cashWhale = 0x88C522E526E5Eea8d636fd6805cA7fEB488780D0;

    _configurePair(lpTokenMarket, cashMarket);
    _fundMarketAndSelf(ICErc20(lpTokenMarket), lpTokenWhale);
    _fundMarketAndSelf(ICErc20(cashMarket), cashWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}

/*
contract XYLeveredPositionTest is LeveredPositionTest {
  function setUp() public fork(X_CHAIN_ID) {}

  function afterForkSetUp() internal override {
    super.afterForkSetUp();

    uint256 depositAmount = 1e18;

    address xMarket = 0x...1;
    address yMarket = 0x...2;
    address xWhale = 0x...3;
    address yWhale = 0x...4;

    IRedemptionStrategy liquidator = new IRedemptionStrategy();
    _configurePairAndLiquidator(xMarket, yMarket, liquidator);
    _fundMarketAndSelf(ICErc20(xMarket), xWhale);
    _fundMarketAndSelf(ICErc20(yMarket), yWhale);

    (position, maxLevRatio, minLevRatio) = _openLeveredPosition(address(this), depositAmount);
  }
}
*/
