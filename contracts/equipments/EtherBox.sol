pragma solidity ^0.4.21;
import './StandardToken.sol';
import './TokenReceiver.sol';
import '../utils/AccessControl.sol';
import '../utils/SafeMath.sol';

contract EtherBox is AccessControl, TokenReceiver {
  using SafeMath for uint256;
  uint public keyRequired;
  address public keyAddress;
  string public name;       //The shoes name: e.g. MB
  uint public uintPrice;    //uintPrice in wei per token e.g. 10000000000000000
  uint64[] public disableDateRange;

  event EtherBoxOpen(address indexed from,
                        address indexed tokenAddress,
                        uint tokenAmount, 
                        uint etherAmount, 
                        uint64 date);

  constructor(string _name, address _keyAddress, uint _keyRequired, uint _unitPrice, uint64[] _disableDateRange) public {
    name = _name;
    keyAddress = _keyAddress;
    keyRequired = _keyRequired;
    uintPrice = _unitPrice;
    disableDateRange = _disableDateRange;
  }

  function setupUnitPrice(uint256 _unitPrice) public onlyCFO {
    uintPrice = _unitPrice;
  }

  function setupKeyRequired(uint256 _keyRequired) public onlyCFO {
    keyRequired = _keyRequired;
  }

  //设置禁用时间范围
  function setDisableDateRange(uint64[] _disableDateRange) public onlyCFO {
    disableDateRange = _disableDateRange;
  }

  function receiveApproval(address _from, uint _amount, address _tokenAddress, bytes _data) public {
    uint _timeDiffer = now % 86400;
    

    require(_timeDiffer >= (disableDateRange[0] % 86400) || _timeDiffer <= (disableDateRange[1] % 86400),'Not Open Now');

    require(_tokenAddress == keyAddress,'keyAddress not right'); // only accept key.
    require(_amount >= keyRequired,'Amount lower than require'); // send amount need to be larger than required;

    require(StandardToken(_tokenAddress).transferFrom(_from, address(this), _amount),'transfer fail');

    uint _etherAmount = computeEtherAmount(_amount);
    require(address(this).balance >= _etherAmount,'ETH not enough');
    _from.transfer(_etherAmount);
    emit EtherBoxOpen(_from, _tokenAddress, _amount, _etherAmount, uint64(now));
  }

  function computeEtherAmount(uint _tokenAmount) view public returns (uint) {
    return _tokenAmount.div(1 ether).mul(uintPrice);
  }

  function withDrawToken(uint _amount) public onlyCFO {
    StandardToken(keyAddress).transfer(CFO, _amount);
  }

  function withDrawBalance(uint256 amount) public onlyCFO {
    require(address(this).balance >= amount);
    if (amount==0) {
      CFO.transfer(address(this).balance);
    } else {
      CFO.transfer(amount);
    }
  }

  function deposit() public onlyCFO payable {

  }

}
