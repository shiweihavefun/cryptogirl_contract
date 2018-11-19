pragma solidity ^0.4.21;
import './AtomicSwappableToken.sol';
import './TokenReceiver.sol';
import '../utils/Ownable.sol';


contract MagicKeys is AtomicSwappableToken, Ownable {

  string public name;                //The shoes name: e.g. MB
  string public symbol;              //The shoes symbol: e.g. MB
  uint8 public decimals;             //Number of decimals of the smallest unit

  constructor (
    string _name,
    string _symbol
  ) public {
    name = _name;
    symbol = _symbol;
    decimals = 18;  // set as default
  }


  function _mint(address _to, uint _amount) internal returns (bool) {
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Transfer(address(0), _to, _amount);
  }

  function mint(address _to, uint256 _amount) onlyOwner public returns (bool) {
    _mint(_to, _amount);
    return true;
  }

  function approveAndCall(address _spender, uint _amount, bytes _data) public {
    if(approve(_spender, _amount)) {
      TokenReceiver(_spender).receiveApproval(msg.sender, _amount, address(this), _data);
    }
  }

}
