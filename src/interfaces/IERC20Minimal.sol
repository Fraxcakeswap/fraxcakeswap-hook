// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IERC20Minimal {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256 balance);
}
