// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenTimelock} from "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title An escrow service
/// @author Felix Fan
/// @notice the token price will increase according to total supply
/// @dev Not production ready
// challenges:
// 1. if funds are not transferred to the escrow service, senders may drain the funds before receivers withdraw, even they have approved the allowance
// 2. if escrow requires the senders to send the funds over at deposit time, how to manage the funds safely
// 3. how to manage multiple timelock transfers for beneficiaries
// 4. how to safely withdraw all the matured timelock transfers
// 5. how to skip all the failed ones
// 6. how to handle fee-on tokens / rebasing tokens
// 7. protect against re-entrancy attack
// solution:
// 1. transfer tokens from senders to escrow service (note: escrow address needs to be approved first)
// 2. deploy a timelock contract to manage a transfer
// 3. use a mapping from beneficiary to an array of timelocks
// 4. use a mapping from beneficiary to an index to the timelocks array.
// 5. implement a wrapper to catch revert and return false?
// 6. overcharge 3-5% and refund to sender after releasing the funds to receivers?
// 7. timelock contract makes sure funds are not mingled together
contract UntrustedEscrow is Ownable2Step {
    using SafeERC20 for IERC20;

    event TimelockCreated(address indexed creator, address indexed token, address indexed beneficiary, uint256 amount);

    mapping(address => TokenTimelock[]) internal ttls;
    mapping(address => uint256) internal indexToCollect;

    function getAllTimelocks() external view returns (TokenTimelock[] memory) {
        return ttls[_msgSender()];
    }

    /// @notice deposit certain tokens in the escrow service for a beneficiary
    /// @dev emits a TimelockCreated event
    /// @dev requires that this address is approved for transferring tokens to a new timelock contract
    /// @param token The token address
    /// @param beneficiary The beneficiary address
    /// @param amount The amount of tokens to transfer
    function deposit(IERC20 token, address beneficiary, uint256 amount) external {
        require(token.balanceOf(_msgSender()) >= amount, "insufficient balance");
        require(token.allowance(_msgSender(), address(this)) >= amount, "insufficient allowance");
        require(beneficiary != address(0), "beneficiary address cannot be zero address");
        require(amount > 0, "deposit amount is zero");

        TokenTimelock lock = new TokenTimelock(token, beneficiary, block.timestamp + 3 days);
        // use safe ERC20 to make sure if the transfer fails, the tx will revert
        token.transferFrom(_msgSender(), address(lock), amount);

        ttls[beneficiary].push(lock);
        emit TimelockCreated(_msgSender(), address(token), beneficiary, amount);
    }

    /// @notice retrieves all the time lock contracts for the msg sender
    function getAllTimeLocks() external view returns (TokenTimelock[] memory) {
        return ttls[_msgSender()];
    }

    /// @notice release the funds in idx-th timelock contract to the beneficiary
    /// @param idx The index
    function withdrawFor(uint256 idx) external {
        TokenTimelock[] memory locks = ttls[_msgSender()];
        require(locks.length > idx, "incorrect index");

        locks[idx].release();
    }

    /// @notice release the funds in timelock contract to the beneficiary
    /// @dev requires that the beneficiary is the msg sender
    /// @param lock The timelock contract address
    function withdraw(TokenTimelock lock) external {
        require(lock.beneficiary() == _msgSender(), "only the beneficiary can withdraw from its timelock contract");

        lock.release();
    }

    /// @notice withdraw all the matured timelock transfers
    /// @dev requires that the beneficiary calls this function
    function withdrawAll() external {
        TokenTimelock[] memory locks = ttls[_msgSender()];
        uint256 idx = indexToCollect[_msgSender()];

        uint256 len = locks.length;
        uint256 i = idx;
        for (; i < len; i++) {
            TokenTimelock lock = locks[i];
            if (lock.releaseTime() <= block.timestamp) {
                lock.release();
                // if the transfer fails, we should emit an event and ask the beneficiary to retry manually
                // instead of using SafeERC20, the token timelock should probably use an unsafe ERC20 version
                // which does not revert in all cases. e.g. catch revert and return false.
            } else {
                break;
            }
        }

        indexToCollect[_msgSender()] = i;
    }
}
