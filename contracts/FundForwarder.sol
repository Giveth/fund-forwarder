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
/// @authors Vojtech Simetka, Jordi Baylina, Dani Philia, Arthur Lunn
/// @notice This contract is used to forward funds to a Giveth Campaign with an escape. 
///  The fund value is sent directly to designated Campaign.
///  The EscapeHatch  allows removal of any other tokens deposited by accident.

import './Escapable.sol';

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
        Escapable(0x0, _escapeHatchCaller, _escapeHatchDestination)
    {
        beneficiary = _beneficiary;
    }

    /// @notice Donate ETH to the `beneficiary`, and if there is enough in the 
    ///  contract double it. The `msg.sender` is rewarded with Campaign tokens
    // depending on how one calls into this fallback function, i.e. with .send ( hard limit of 2300 gas ) vs .value (provides fallback with all the available gas of the caller), it may throw
    function () payable {
        uint amount;
        amount = msg.value;
        // Send the ETH to the beneficiary so that they receive Campaign tokens
        require (beneficiary.proxyPayment.value(amount)(msg.sender));
        FundsSent(msg.sender, amount);
    }
    event FundsSent(address indexed sender, uint amount);
}