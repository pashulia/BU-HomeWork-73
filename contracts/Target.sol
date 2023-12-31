//SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

contract Target {
    uint256 public number;
    address public owner;

    event SetValue(address adr, uint256 value);

    constructor (address _owner) {
        owner = _owner;
    }
    
    function setNumber(uint256 _number) public {
        require(msg.sender == owner, "You are not owner!");
        number = _number;
        emit SetValue(msg.sender, number);
    }
}