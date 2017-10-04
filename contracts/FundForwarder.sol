pragma solidity ^0.4.15;
/*
    Copyright 2017, Arthur Lunn

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

/// @title Fund Forwarder
/// @authors Vojtech Simetka, Jordi Baylina, Dani Philia, Arthur Lunn (hardly)
/// @notice This contract is used to forward funds to a Giveth Campaign 
///  with an escapeHatch.The fund value is sent directly to designated Campaign.
///  The escapeHatch allows removal of any other tokens deposited by accident.

import '../node_modules/giveth-common-contracts/contracts/Escapable.sol';

/// @dev This is an empty contract to declare `proxyPayment()` to comply with
///  Giveth Campaigns so that tokens will be generated when donations are sent
contract Campaign {
    /// @notice `proxyPayment()` allows the caller to send ether to the Campaign and
    /// have the tokens created in an address of their choosing
    /// @param _owner The address that will hold the newly created tokens
    function proxyPayment(address _owner) payable returns(bool);
}

/// @dev The main contract which forwards funds sent to contract.
contract FundForwarder is Escapable {
    Campaign public beneficiary; // expected to be a Giveth campaign

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
    function FundForwarder(
            Campaign _beneficiary, // address that receives ether
            address _escapeHatchCaller,
            address _escapeHatchDestination
        )
        // Set the escape hatch to accept ether (0x0)
        Escapable(_escapeHatchCaller, _escapeHatchDestination)
    {
        beneficiary = _beneficiary;
    }

    /// @notice Directly forward Eth to `beneficiary`. The `msg.sender` is rewarded with Campaign tokens.
    ///  This contract may have a high gasLimit requirement dependent on beneficiary.
    function () payable {
        uint amount;
        amount = msg.value;
        // Send the ETH to the beneficiary so that they receive Campaign tokens
        require (beneficiary.proxyPayment.value(amount)
        (msg.sender)
        );
        FundsSent(msg.sender, amount);
    }
    event FundsSent(address indexed sender, uint amount);
}
