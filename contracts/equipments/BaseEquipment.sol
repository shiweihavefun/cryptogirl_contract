pragma solidity ^0.4.21;
import "../utils/AddressUtils.sol";
import './TokenReceiver.sol';
import './AtomicSwappableToken.sol';
import '../utils/Ownable.sol';

contract BaseEquipment is Ownable, AtomicSwappableToken {

  event Mint(address indexed to, uint256 amount);

  //cap==0 means no limits
  uint256 public cap;

  /**
      properties = [
          0, //validationDuration
          1, //location
          2, //applicableType
      ];
  **/
  uint[] public properties;


  address public controller;

  modifier onlyController { require(msg.sender == controller); _; }

  function setController(address _newController) public onlyOwner {
    controller = _newController;
  }

  constructor(uint256 _cap, uint[] _properties) public {
    cap = _cap;
    properties = _properties;
  }

  function setProperty(uint256[] _properties) public onlyOwner {
    properties = _properties;
  }


  function _mint(address _to, uint _amount) internal {
    require(cap==0 || totalSupply_.add(_amount) <= cap);
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Transfer(address(0), _to, _amount);
  }


  function mint(address _to, uint256 _amount) onlyController public returns (bool) {
    _mint(_to, _amount);
    return true;
  }


  function mintFromOwner(address _to, uint256 _amount) onlyOwner public returns (bool) {
    _mint(_to, _amount);
    return true;
  }


  function approveAndCall(address _spender, uint _amount, bytes _data) public {
    if(approve(_spender, _amount)) {
      TokenReceiver(_spender).receiveApproval(msg.sender, _amount, address(this), _data);
    }
  }


  function checkCap(uint256 _amount) public view returns (bool) {
  	return (cap==0 || totalSupply_.add(_amount) <= cap);
  }




}
