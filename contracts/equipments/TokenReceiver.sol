pragma solidity ^0.4.21;

contract TokenReceiver {
  function receiveApproval(address from, uint amount, address tokenAddress, bytes data) public;
}
