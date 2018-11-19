pragma solidity ^0.4.21;

import './AccessControl.sol';

contract ServerControl is AccessControl{

    event AddServerAddress(address contractAddress);
    event RemoveServerAddress(address contractAddress);

    mapping (address => bool) public serverAddressList;

    modifier onlyServer {
        require(serverAddressList[msg.sender]);
        _;
    }

    function addServerAddress(address _serverAddress) onlyOwner public returns (bool){
        serverAddressList[_serverAddress] = true;
        emit AddServerAddress(_serverAddress);
        return true;
    }

    function removeServerAddress(address _serverAddress) onlyOwner public {
        require(serverAddressList[_serverAddress]);
        serverAddressList[_serverAddress] = false;
        emit RemoveServerAddress(_serverAddress);
    }
}
