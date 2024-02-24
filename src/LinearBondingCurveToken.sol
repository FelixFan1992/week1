// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title An ERC20 token which has linear bonding curve
/// @author Felix Fan
/// @notice the token price will increase according to total supply
/// @dev Not production ready
contract LinearBondingCurveToken is ERC20, Ownable2Step {
    error NotEnoughEther(uint256 amount, uint256 want, uint256 sent);

    // price of 1 token is I_COEFFICIENT * total supply / 100
    uint8 public immutable I_COEFFICIENT;
    uint8 public constant PERCENT = 100;
    uint256 public constant MIN_AMOUNT = 0.1 ether;
    mapping(uint256 => mapping(address => bool)) private accountByBlock;

    constructor(string memory _name, string memory _symbol, uint8 _c) ERC20(_name, _symbol) {
        require(_c > 0, "must be greater than 0");
        I_COEFFICIENT = _c;
    }

    /// @notice mint some tokens.
    /// @dev requires that the amount is at least MIN_MINT_AMOUNT
    /// @param _to the address to which new tokens will be sent
    /// @param _amount the amount of tokens to mint
    function mint(address _to, uint256 _amount) external payable {
        require(_amount >= MIN_AMOUNT, "must mint at least MIN_AMOUNT");
        uint256 expectedEther = calculatePayment(_amount);
        require(msg.value >= expectedEther, "not enough ether");
        accountByBlock[block.number][_to] = true;

        _mint(_to, _amount);
    }

    /// @notice burn some tokens for msg sender
    /// @dev requires that the amount is at least MIN_MINT_AMOUNT
    /// @param _amount the amount of tokens to burn
    function burn(uint256 _amount) external {
        require(_amount >= MIN_AMOUNT, "must burn at least MIN_AMOUNT");
        require(!accountByBlock[block.number][_msgSender()], "same account cannot mint and burn at the same block");

        _burn(_msgSender(), _amount);

        uint256 payment = calculatePayment(_amount);
        msg.sender.call{value: payment}("");
    }

    /// @notice burn some tokens for the account
    /// @dev requires that the amount is at least MIN_MINT_AMOUNT
    /// @param _account the owner of tokens which will be burnt
    /// @param _amount the amount of tokens to burn
    function burnFrom(address _account, uint256 _amount) external {
        require(!accountByBlock[block.number][_account], "same account cannot mint and burn at the same block");

        _spendAllowance(_account, _msgSender(), _amount);
        _burn(_account, _amount);

        uint256 payment = calculatePayment(_amount);
        _account.call{value: payment}("");
    }

    function calculatePayment(uint256 _amount) internal view returns (uint256) {
        uint256 price1 = (totalSupply() + _amount) * I_COEFFICIENT / PERCENT;
        uint256 price0 = totalSupply() * I_COEFFICIENT / PERCENT;
        return (price1 * price1 - price0 * price0) / 1 ether;
    }
}
