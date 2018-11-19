pragma solidity ^0.4.21;
import './StandardToken.sol';

contract AtomicSwappableToken is StandardToken {
  struct HashLockContract {
    address sender;
    address receiver;
    uint amount;
    bytes32 hashlock;
    uint timelock;
    bytes32 secret;
    States state;
  }

  enum States {
    INVALID,
    OPEN,
    CLOSED,
    REFUNDED
  }

  mapping (bytes32 => HashLockContract) private contracts;

  modifier futureTimelock(uint _time) {
    // only requirement is the timelock time is after the last blocktime (now).
    // probably want something a bit further in the future then this.
    // but this is still a useful sanity check:
    require(_time > now);
    _;
}

  modifier contractExists(bytes32 _contractId) {
    require(_contractExists(_contractId));
    _;
  }

  modifier hashlockMatches(bytes32 _contractId, bytes32 _secret) {
    require(contracts[_contractId].hashlock == keccak256(_secret));
    _;
  }

  modifier closable(bytes32 _contractId) {
    require(contracts[_contractId].state == States.OPEN);
    require(contracts[_contractId].timelock > now);
    _;
  }

  modifier refundable(bytes32 _contractId) {
    require(contracts[_contractId].state == States.OPEN);
    require(contracts[_contractId].timelock <= now);
    _;
  }

  event NewHashLockContract (
    bytes32 indexed contractId,
    address indexed sender,
    address indexed receiver,
    uint amount,
    bytes32 hashlock,
    uint timelock
  );

  event SwapClosed(bytes32 indexed contractId);
  event SwapRefunded(bytes32 indexed contractId);


  function open (
    address _receiver,
    bytes32 _hashlock,
    uint _timelock,
    uint _amount
  ) public
    futureTimelock(_timelock)
    returns (bytes32 contractId)
  {
    contractId = keccak256 (
      msg.sender,
      _receiver,
      _amount,
      _hashlock,
      _timelock
    );

    // the new contract must not exist
    require(!_contractExists(contractId));

    // transfer token to this contract
    require(transfer(address(this), _amount));

    contracts[contractId] = HashLockContract(
      msg.sender,
      _receiver,
      _amount,
      _hashlock,
      _timelock,
      0x0,
      States.OPEN
    );

    emit NewHashLockContract(contractId, msg.sender, _receiver, _amount, _hashlock, _timelock);
  }

  function close(bytes32 _contractId, bytes32 _secret)
    public
    contractExists(_contractId)
    hashlockMatches(_contractId, _secret)
    closable(_contractId)
    returns (bool)
  {
    HashLockContract storage c = contracts[_contractId];
    c.secret = _secret;
    c.state = States.CLOSED;
    require(this.transfer(c.receiver, c.amount));
    emit SwapClosed(_contractId);
    return true;
  }

  function refund(bytes32 _contractId)
    public
    contractExists(_contractId)
    refundable(_contractId)
    returns (bool)
  {
    HashLockContract storage c = contracts[_contractId];
    c.state = States.REFUNDED;
    require(this.transfer(c.sender, c.amount));
    emit SwapRefunded(_contractId);
    return true;
  }

  function _contractExists(bytes32 _contractId) internal view returns (bool exists) {
    exists = (contracts[_contractId].sender != address(0));
  }

  function checkContract(bytes32 _contractId)
    public
    view
    contractExists(_contractId)
    returns (
      address sender,
      address receiver,
      uint amount,
      bytes32 hashlock,
      uint timelock,
      bytes32 secret
    )
  {
    HashLockContract memory c = contracts[_contractId];
    return (
      c.sender,
      c.receiver,
      c.amount,
      c.hashlock,
      c.timelock,
      c.secret
    );
  }

}
