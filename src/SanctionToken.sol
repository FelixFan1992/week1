// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title An ERC20 token which allows sanctions on certain addresses
/// @author Felix Fan
/// @notice Authorities will love this
/// @dev Not production ready
contract SanctionToken is ERC20, Ownable2Step {
    mapping(address => bool) internal sanctioned;
    address internal admin;

    event AdminUpdated(address newAdmin);
    event Sanctioned(address);
    event SanctionLifted(address);

    error SanctionedSender(address);
    error SanctionedReceiver(address);

    modifier onlyAdmin() {
        require(_msgSender() == admin, "only admin can carry out this operation");
        _;
    }

    constructor(string memory _name, string memory _symbol, address _admin) ERC20(_name, _symbol) {
        admin = _admin;
    }

    /// @notice update the admin, can only be done by contract owner
    /// @dev emits an AdminUpdated event
    /// @dev requires that the new admin is not zero address
    /// @param _admin The new admin
    function updateAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "zero address is not a valid admin");

        admin = _admin;
        emit AdminUpdated(_admin);
    }

    /// @notice mint some tokens. can be called by anyone. free to mint.
    /// @dev requires that the amount is not zero
    /// @param _to the address to which new tokens will be sent
    /// @param _amount the amount of tokens to mint
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    /// @notice sanction an address, can only be done by admin
    /// @dev emits a Sanctioned event
    /// @dev requires that this address is not already sanctioned
    /// @param _address The address to be sanctioned
    function sanction(address _address) external onlyAdmin {
        require(!sanctioned[_address], "the address is already sanctioned");

        sanctioned[_address] = true;
        emit Sanctioned(_address);
    }

    /// @notice unsanction an address, can only be done by admin
    /// @dev emits a SanctionLifted event
    /// @dev requires that this address is already sanctioned
    /// @param _address The address whose sanction will be lifted
    function unsanction(address _address) external onlyAdmin {
        require(sanctioned[_address], "the address is not sanctioned");

        sanctioned[_address] = false;
        emit SanctionLifted(_address);
    }

    /// @inheritdoc ERC20
    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        if (sanctioned[to]) {
            revert SanctionedReceiver(to);
        }
        if (sanctioned[from]) {
            revert SanctionedSender(from);
        }
    }
}
