pragma solidity ^0.4.19;
import '../ERC721/GirlOps.sol';
import '../GenesFactory.sol';
import '../equipments/MagicKeys.sol';
import '../utils/SafeMath.sol';
import '../utils/AccessControl.sol';


contract GirlDecompose is AccessControl {
  using SafeMath for uint256;

  GenesFactory public genesFactory;
  GirlOps public girlOps;

  MagicKeys debris;

  uint baseOrigin = 0.9 ether;
  uint base = 0.1 ether;
  uint cap = 0.7 ether;
  uint duration = 10368000; //120 days, 120 *24 *60 *60;
  uint newCalStartTime;

  event Decomposition(address sender, uint256 tokenId);

  constructor(address _girlOpsAddress, address _genesFactoryAddress, address _debrisAddress) public {
    genesFactory = GenesFactory(_genesFactoryAddress);
    girlOps = GirlOps(_girlOpsAddress);
    debris = MagicKeys(_debrisAddress);
  }


  function decompose (uint _tokenId) public {
    require(msg.sender == girlOps.ownerOf(_tokenId));
    require(girlOps.isNotCoolDown(_tokenId));

    uint _currentValue = computeCurrentValue(_tokenId);
    girlOps.burnGirl(msg.sender, _tokenId);

    sendKeys(msg.sender, _currentValue);

    emit Decomposition(msg.sender, _tokenId);
  }

  function setNewCalStartTime(uint _startTime) public onlyOwner {
    newCalStartTime = _startTime;
  }

  function setParams(uint _baseOrigin, uint _base, uint _cap) public onlyOwner {
    baseOrigin = _baseOrigin;
    base = _base;
    cap = _cap;
  }

  function computeCurrentValue(uint _tokenId) public view returns (uint) {
    uint _currentBase;
    uint _birthTime = girlOps.getGirlBirthTime(_tokenId);
    if(_birthTime < newCalStartTime) {
      _currentBase = baseOrigin;
    } else {
      uint _secondPassed = block.timestamp.sub(_birthTime);
      if(_secondPassed > duration) {
        _currentBase = cap;
      } else {
        uint _totalPriceChange = cap.sub(base);
        uint _currentBaseChange = _totalPriceChange.mul(_secondPassed).div(duration);
        _currentBase = base.add(_currentBaseChange);
      }
    }

    uint _gene = girlOps.getGirlGene(_tokenId);
    uint _rarity = genesFactory.getRarity(_gene);
    uint _starLevel = girlOps.getGirlStarLevel(_tokenId);

    uint ret = 10;
    if (_rarity == 3){
      ret = 100;
    } else if (_rarity == 2){
      ret = 50;
    } else if(_rarity == 1){
      ret = 20;
    }
    if (_starLevel>10){
      _starLevel = 10;
    }

    ret = ret.mul(uint256(3 ** uint256(_starLevel -1))).mul(_currentBase);
    ret = ret.div(1 ether).mul(1 ether);

    return ret;
  }

  function sendKeys(address _to, uint _amount) internal {
      debris.transfer(_to, _amount);
  }

  function withDrawToken(uint _amount) public onlyCFO {
    debris.transfer(CFO, _amount);
  }

}
