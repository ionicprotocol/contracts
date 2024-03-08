// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {WithPool} from "./helpers/WithPool.sol";
import {BaseTest} from "./config/BaseTest.t.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FuseFlywheelDynamicRewards} from "fuse-flywheel/rewards/FuseFlywheelDynamicRewards.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MasterPriceOracle} from "../oracles/MasterPriceOracle.sol";
import {IRedemptionStrategy} from "../liquidators/IRedemptionStrategy.sol";
import {IFundsConversionStrategy} from "../liquidators/IFundsConversionStrategy.sol";
import {IUniswapV2Router02} from "../external/uniswap/IUniswapV2Router02.sol";
import {IonicComptroller} from "../compound/ComptrollerInterface.sol";
import {PoolLensSecondary} from "../PoolLensSecondary.sol";
import {UniswapLpTokenLiquidator} from "../liquidators/UniswapLpTokenLiquidator.sol";
import {IUniswapV2Pair} from "../external/uniswap/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../external/uniswap/IUniswapV2Factory.sol";
import {PoolLens} from "../PoolLens.sol";
import {IonicLiquidator, ILiquidator} from "../IonicLiquidator.sol";
import {CErc20} from "../compound/CToken.sol";
import {ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import {ICErc20} from "../compound/CTokenInterfaces.sol";
import {AuthoritiesRegistry} from "../ionic/AuthoritiesRegistry.sol";
import {PoolRolesAuthority} from "../ionic/PoolRolesAuthority.sol";

contract MockWNeon is MockERC20 {
    constructor() MockERC20("test", "test", 18) {}

    function deposit() external payable {}
}

contract ModeE2ETest is BaseTest {
    IonicComptroller comptroller = IonicComptroller(0xFB3323E24743Caf4ADD0fDCCFB268565c0685556);
    address feeDistributor = 0x8ea3fc79D9E463464C5159578d38870b770f6E57;
    address jumpRateModel = 0x21a455cEd9C79BC523D4E340c2B97521F4217817;

    function testModeDeployEzEth() public fork(MODE_MAINNET) {
        address ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
        bytes memory constructorData = abi.encode(
            ezETH,
            address(comptroller),
            feeDistributor,
            jumpRateModel,
            "Ionic Renzo Staked Eth",
            "ionezETH",
            0.1 ether,
            0.1 ether
        );
        bytes memory becomeImplData = hex"00";
        comptroller._deployMarket(1, constructorData, becomeImplData, 0.7 ether);
    }
}
