pragma solidity ^0.4.21;

import './Ownable.sol';

contract AccessControl is Ownable{
    address CFO;
    //Owner address can set to COO address. it have same effect.

    modifier onlyCFO{
        require(msg.sender == CFO);
        _;
    }

    function setCFO(address _newCFO)public onlyOwner {
        CFO = _newCFO;
    }

    //use pausable in the contract that need to pause. save gas and clear confusion.

}
