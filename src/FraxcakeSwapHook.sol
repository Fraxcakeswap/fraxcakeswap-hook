// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "@pancakeswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@pancakeswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {ICLPoolManager} from "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {LPFeeLibrary} from "@pancakeswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {CLBaseHook} from "./pool-cl/CLBaseHook.sol";
import {ISwapFee} from "./interfaces/ISwapFee.sol";

contract FraxcakeSwapHook is CLBaseHook {
    using PoolIdLibrary for PoolKey;

    ISwapFee public swapFees;
    mapping(PoolId => uint24) public poolIdToLpFee;

    constructor(ICLPoolManager _poolManager, address _swapFeeAddress) CLBaseHook(_poolManager) {
        swapFees = ISwapFee(_swapFeeAddress);
    }

    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return _hooksRegistrationBitmapFrom(
            Permissions({
                beforeInitialize: false,
                afterInitialize: true,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnsDelta: false,
                afterSwapReturnsDelta: false,
                afterAddLiquidiyReturnsDelta: false,
                afterRemoveLiquidiyReturnsDelta: false
            })
        );
    }

    function afterInitialize(address, PoolKey calldata key, uint160, int24, bytes calldata hookData)
        external
        override
        returns (bytes4)
    {
        uint24 swapFee = abi.decode(hookData, (uint24));
        poolIdToLpFee[key.toId()] = swapFee;

        return this.afterInitialize.selector;
    }


    function beforeSwap(
        address,
        PoolKey calldata key,
        ICLPoolManager.SwapParams calldata,
        bytes calldata
    )
        external
        override
        poolManagerOnly
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 swapFee = swapFees.swapFee(tx.origin, poolIdToLpFee[key.toId()]);
    
        poolManager.updateDynamicLPFee(key, swapFee);
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, swapFee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }
}