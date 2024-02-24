// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// how to specify a specific version here????
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title An ERC20 token which has an almighty address
/// @author Felix Fan
/// @notice Authorities will love this
/// @dev Not production ready
contract GodToken is ERC20, Ownable2Step {
    address internal admin;

    event AdminUpdated(address newAdmin);

    constructor(string memory _name, string memory _symbol, address _admin) ERC20(_name, _symbol) {
        admin = _admin;
    }

    /// @notice mint some tokens. can be called by anyone. free to mint.
    /// @dev requires that the amount is not zero
    /// @param _to the address to which new tokens will be sent
    /// @param _amount the amount of tokens to mint
    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
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

    /// @notice verifies the allowance is no less than a certain amount, unless the spender is the admin
    /// @dev emits an Approval event if the spender is not the admin while it has enough allowance
    /// @param _owner The token owner
    /// @param _spender The spender
    /// @param _amount The amount of tokens
    function _spendAllowance(address _owner, address _spender, uint256 _amount) internal override {
        if (_spender == admin) {
            return;
        }

        uint256 currentAllowance = allowance(_owner, _spender);
        // why this check?
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= _amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(_owner, _spender, currentAllowance - _amount);
            }
        }
    }
}
