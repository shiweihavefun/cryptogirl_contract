pragma solidity ^0.4.21;

import '../ERC721/GirlOps.sol';
import './BaseEquipment.sol';
import '../utils/Ownable.sol';

contract PrizePool is Ownable {

  event SendPrized(address equipementAddress, address to);

  address[] public magicBoxes;
  mapping(address => bool) public magicBoxList;

  address[] public equipments;
  GirlOps public girlOps;

  event SendEquipment(address to, address prizeAddress, uint time);
  event EquipmentOutOfStock(address eqAddress);

  modifier onlyMagicBox() {
    require(magicBoxList[msg.sender]);
    _;
  }

  constructor(address _girlOpsAddress) public {
    girlOps = GirlOps(_girlOpsAddress);
  }

  function sendPrize(address _to, uint _index) public onlyMagicBox returns (bool) {
    //新确定方案，如果开箱开到某个道具没有了，直接选下一个
    //递归调用，全部箱子如果都遍历完了全都脱销，则失败
    //现在这样会开出箱子中没有的东西， 按理来讲应该开出箱子的下一个物品。
    address prizeAddress = equipments[_index];
    BaseEquipment baseEquipment = BaseEquipment(prizeAddress);
    if(baseEquipment.checkCap(1 ether)) {
      baseEquipment.mint(_to, 1 ether);
      emit SendEquipment(_to, prizeAddress, now);
      return true;
    } else {
      emit EquipmentOutOfStock(prizeAddress);
      return false;
    }
  }

  function mintGirl(address to, uint gene, uint16 _level) public onlyMagicBox returns (bool) {
    girlOps.createGirl(gene, to, _level);
    return true;
  }

  function setEquipments(address[] _equipments) public onlyOwner {
    equipments = _equipments;
  }


  function addMagicBox(address addr) public onlyOwner returns (bool) {
    if (!magicBoxList[addr]) {
      magicBoxList[addr] = true;
      magicBoxes.push(addr);
      return true;
    } else {
      return false;
    }
  }

  function addMagicBoxes(address[] addrs) public onlyOwner returns (bool) {
    for (uint i=0; i<addrs.length; i++) {
      require(addMagicBox(addrs[i]));
    }
    return true;
  }

  function removeMagicBox(address addr) public onlyOwner returns (bool) {
    require(magicBoxList[addr]);
    for (uint i=0; i<magicBoxes.length - 1; i++) {
      if (magicBoxes[i] == addr) {
        magicBoxes[i] = magicBoxes[magicBoxes.length -1];
        break;
      }
    }
    magicBoxes.length -= 1;
    magicBoxList[addr] = false;
    return true;
  }

}
