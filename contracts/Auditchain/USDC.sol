// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";




contract USDC is  ERC20Burnable{
      
   

    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY = 250000000 * (10**uint256(DECIMALS));
    
    /// @dev Constructor that gives an account all initial tokens.
    constructor(address account)  ERC20("USDC Token", "USDC")
 {
        require(account != address(0), "USDC:constructor - Address can't be 0");
        _mint(account, INITIAL_SUPPLY);              
    }

}