pragma solidity =0.8.0;
// SPDX-License-Identifier: MIT


interface IUniswapV2Router {

  function swapExactTokensForTokens(
    uint amountIn, 
    uint amountOutMin, 
    address[] calldata path, 
    address to, 
    uint deadline
    ) external returns (uint256[] memory amounts);
}