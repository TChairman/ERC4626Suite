// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
/// @author Tom Shields (https://github.com/tomshields/ERC4626Suite)

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockCoin is ERC20, Ownable {
    constructor() ERC20("MockCoin", "MOCK") {}

    function mint(address receiver, uint256 amount) onlyOwner public {
        _mint(receiver, amount);
    }

    function burn(address loser, uint256 amount) onlyOwner public {
        _burn(loser, amount);
    }
}