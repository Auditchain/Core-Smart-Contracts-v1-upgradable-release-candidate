//SPDX-License-Identifier: MIT

pragma solidity =0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./UniSwap.sol";


contract TestUniswap {
//   address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ;
//   address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D ;
  address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;


  function swap(
    address _tokenIn,
    address _tokenOut,
    uint256 _amountIn,
    uint256 _amountOutMin,
    address _to 

  ) external {
    ERC20Upgradeable(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
    ERC20Upgradeable( _tokenIn).approve(UNISWAP_ROUTER_ADDRESS, _amountIn);

    address[] memory path;
    path = new address[] (3);
    path[0] = _tokenIn;
    path[1] = WETH;
    path[2] = _tokenOut;

    IUniswapV2Router(UNISWAP_ROUTER_ADDRESS).swapExactTokensForTokens (
        _amountIn,
        _amountOutMin,
        path,
        _to,
        block.timestamp
    );



  }

    
}