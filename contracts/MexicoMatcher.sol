pragma solidity ^0.4.15;
/*
    Copyright 2017, Griff Green

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/// @title Mexico Matcher
/// @authors Vojtech Simetka, Jordi Baylina, Dani Philia, Arthur Lunn, Griff Green
/// @notice This contract is used to forward funds to a Giveth Campaign 
///  with an escapeHatch.The fund value is sent directly to designated Campaign.
///  The escapeHatch allows removal of any other tokens deposited by accident.

import './Escapable.sol';

/// @dev The main contract which forwards funds sent to contract.
contract MexicoMatcher is Escapable {
    address public beneficiary; // expected to be a Giveth campaign

    /// @notice The Constructor assigns the `beneficiary`, the
    ///  `escapeHatchDestination` and the `escapeHatchCaller` as well as deploys
    ///  the contract to the blockchain (obviously)
    /// @param _beneficiary The address of the CAMPAIGN CONTROLLER for the Campaign
    ///  that is to receive donations
    /// @param _escapeHatchDestination The address of a safe location (usually a
    ///  Multisig) to send the ether held in this contract
    /// @param _escapeHatchCaller The address of a trusted account or contract
    ///  to call `escapeHatch()` to send the ether in this contract to the 
    ///  `escapeHatchDestination` it would be ideal that `escapeHatchCaller`
    ///  cannot move funds out of `escapeHatchDestination`
    function MexicoMatcher(
            address _beneficiary, // address that receives ether
            address _escapeHatchCaller,
            address _escapeHatchDestination
        )
        // Set the escape hatch to accept ether (0x0)
        Escapable(0x0, _escapeHatchCaller, _escapeHatchDestination)
    {
        beneficiary = _beneficiary;
    }
    
    /// @notice Simple function to deposit more ETH to match future donations
    function depositETH() payable {
        DonationDeposited4Matching(msg.sender, msg.value);
    }
    /// @notice Donate ETH to the `beneficiary`, and if there is enough in the 
    ///  contract double it. The `msg.sender` is rewarded with Campaign tokens;
    ///  This contract may have a high gasLimit requirement
    function () payable {
        uint amount;
        
        // If there is enough ETH in the contract to double it, DOUBLE IT!
        if (this.balance >= multiply(msg.value, 2)){
            amount = multiply(msg.value, 2); // do it two it!
        
            // Send ETH to the beneficiary; must be an account, not a contract
            require (beneficiary.send(amount));
            DonationMatched(msg.sender, amount);
        } else {
            amount = this.balance;
            require (beneficiary.send(amount));
            DonationSentButNotMatched(msg.sender, amount);
    }
    event DonationDeposited4Matching(address indexed sender, uint amount);
    event DonationMatched(address indexed sender, uint amount);
    event DonationSentButNotMatched(address indexed sender, uint amount);
}
