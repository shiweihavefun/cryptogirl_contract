pragma solidity ^0.4.21;
import "./equipments/BaseEquipment.sol";
import './ERC721/GirlBasicToken.sol';
import './GenesFactory.sol';
import './utils/Pausable.sol';
contract AvatarEquipments is Pausable{

    event SetEquipmentV2(address indexed user, uint256 indexed girlId, address indexed tokenAddress, uint256 amount, uint validationDuration);

    event WithdrawEquipmentV2(address indexed user, address indexed tokenAddress, uint256 indexed girlId, uint64 date);

    struct Equipment {
        address BackgroundAddress;
        uint BackgroundAmount;
        uint64 BackgroundEndTime;

        address photoFrameAddress;
        uint photoFrameAmount;
        uint64 photoFrameEndTime;

        address armsAddress;
        uint armsAmount;
        uint64 armsEndTime;

        address petAddress;
        uint petAmount;
        uint64 petEndTime;
    }
    GirlBasicToken girlBasicToken;
    GenesFactory genesFactory;
  /// @dev A mapping from girl IDs to their current equipment.
    mapping (uint256 => Equipment) public GirlIndexToEquipment;

    mapping (address => bool) public equipmentToStatus;

    constructor(address _girlBasicToken, address _GenesFactory) public{
        require(_girlBasicToken != address(0x0), 'girlBasicToken address is not valid');
        girlBasicToken = GirlBasicToken(_girlBasicToken);
        genesFactory = GenesFactory(_GenesFactory);
    }

/* if the list goes to hundreds of equipment this transaction may out of gas.
    function managerEquipment(address[] addressList, bool[] statusList) public onlyOwner {
        require(addressList.length == statusList.length);
        require(addressList.length > 0);
        for (uint i = 0; i < addressList.length; i ++) {
            equipmentToStatus[addressList[i]] = statusList[i];
        }
    }
*/

    function addTokenToWhitelist(address _eq) public onlyOwner {
      equipmentToStatus[_eq] = true;
    }


    function removeFromWhitelist(address _eq) public onlyOwner {
      equipmentToStatus[_eq] = false;
    }

    function addManyToWhitelist(address[] _eqs) public onlyOwner {
      for(uint i=0; i<_eqs.length; i++) {
        equipmentToStatus[_eqs[i]] = true;
      }
    }

    // 新需求： 永久道具(validDuration=18446744073709551615)可拆卸  (18446744073709551615 is max of uint64 )
    function withdrawEquipment(uint _girlId, address _equipmentAddress) public {
       BaseEquipment baseEquipment = BaseEquipment(_equipmentAddress);
       uint _validationDuration = baseEquipment.properties(0);
       require(_validationDuration == 18446744073709551615, 'the equipment is not forever'); // the token must have infinite duration. validation duration 0 indicate infinite duration
       Equipment storage equipment = GirlIndexToEquipment[_girlId];
       uint location = baseEquipment.properties(1);
       address owner = girlBasicToken.ownerOf(_girlId);
       uint amount;
       if (location == 1 && equipment.BackgroundAddress == _equipmentAddress) {
          amount = equipment.BackgroundAmount;
          
          equipment.BackgroundAddress = address(0); 
          equipment.BackgroundAmount = 0; 
          equipment.BackgroundEndTime = 0;          
       } else if (location == 2 && equipment.photoFrameAddress == _equipmentAddress) {
          amount = equipment.photoFrameAmount;
          
          equipment.photoFrameAddress = address(0); 
          equipment.photoFrameAmount= 0; 
          equipment.photoFrameEndTime = 0;
       } else if (location == 3 && equipment.armsAddress == _equipmentAddress) {
          amount = equipment.armsAmount;
          
          equipment.armsAddress = address(0); 
          equipment.armsAmount = 0; 
          equipment.armsEndTime = 0; 
       } else if (location == 4 && equipment.petAddress == _equipmentAddress) {
          amount = equipment.petAmount;
          
          equipment.petAddress = address(0); 
          equipment.petAmount = 0; 
          equipment.petEndTime = 0; 
       } else {
          revert();
       }
       require(amount > 0, 'amount must greater than 0');
       baseEquipment.transfer(owner, amount);

       emit WithdrawEquipmentV2(owner, _equipmentAddress, _girlId, uint64(now));
    }

    function setEquipment(address _sender, uint _girlId, uint _amount, address _equipmentAddress, uint256[] _properties) whenNotPaused public {
        require(isValid(_sender, _girlId , _amount, _equipmentAddress), 'parameters is not valid');
        Equipment storage equipment = GirlIndexToEquipment[_girlId];

        require(_properties.length >= 3);
        uint _validationDuration = _properties[0];
        uint _location = _properties[1];
        uint _applicableType = _properties[2];

        if(_applicableType < 16){
          uint genes = girlBasicToken.getGirlGene(_girlId);
          uint race = genesFactory.getRace(genes);
          require(race == uint256(_applicableType));
        }

        uint _count = _amount / (1 ether);

        uint _duration = 0;

        if (_location == 1) {
            if(_validationDuration == 18446744073709551615) { // 根据永久道具需求更改
              equipment.BackgroundEndTime = 18446744073709551615;
            } else if((equipment.BackgroundAddress == _equipmentAddress) && equipment.BackgroundEndTime > now ) {
                equipment.BackgroundEndTime  += uint64(_count * _validationDuration);
            } else {
                equipment.BackgroundEndTime = uint64(now + (_count * _validationDuration));
            }
            _duration = equipment.BackgroundEndTime;
            equipment.BackgroundAddress = _equipmentAddress;
            equipment.BackgroundAmount = _amount;
        } else if (_location == 2){
            if(_validationDuration == 18446744073709551615) {
              equipment.photoFrameEndTime = 18446744073709551615;
            } else if((equipment.photoFrameAddress == _equipmentAddress) && equipment.photoFrameEndTime > now ) {
                equipment.photoFrameEndTime  += uint64(_count * _validationDuration);
            } else {
                equipment.photoFrameEndTime = uint64(now + (_count * _validationDuration));
            }
            _duration = equipment.photoFrameEndTime;
            equipment.photoFrameAddress = _equipmentAddress;
            equipment.photoFrameAmount = _amount;
        } else if (_location == 3) {
            if(_validationDuration == 18446744073709551615) {
              equipment.armsEndTime = 18446744073709551615;
            } else if((equipment.armsAddress == _equipmentAddress) && equipment.armsEndTime > now ) {
              equipment.armsEndTime  += uint64(_count * _validationDuration);
            } else {
              equipment.armsEndTime = uint64(now + (_count * _validationDuration));
            }
            _duration = equipment.armsEndTime;
            equipment.armsAddress = _equipmentAddress;
            equipment.armsAmount = _count;
        } else if (_location == 4) {
            if(_validationDuration == 18446744073709551615) {
              equipment.petEndTime = 18446744073709551615;
            } else if((equipment.petAddress == _equipmentAddress) && equipment.petEndTime > now ) {
              equipment.petEndTime  += uint64(_count * _validationDuration);
            } else {
              equipment.petEndTime = uint64(now + (_count * _validationDuration));
            }
            _duration = equipment.petEndTime;
            equipment.petAddress = _equipmentAddress;
            equipment.petAmount = _amount;
        } else{
            revert();
        }
        emit SetEquipmentV2(_sender, _girlId, _equipmentAddress, _amount, _duration);
    }

    function isValid (address _from, uint _GirlId, uint _amount, address _tokenContract) public returns (bool) {
        BaseEquipment baseEquipment = BaseEquipment(_tokenContract);
        require(equipmentToStatus[_tokenContract]);
        // must send at least 1 token
        require(_amount >= 1 ether);
        require(_amount % 1 ether == 0); // basic unit is 1 token;
        require(girlBasicToken.ownerOf(_GirlId) == _from || owner == _from); // must from girl owner or the owner of contract. 
        require(baseEquipment.transferFrom(_from, this, _amount));
        return true;
    }

    function getGirlEquipmentStatus(uint256 _girlId) public view returns(
        address BackgroundAddress,
        uint BackgroundAmount,
        uint BackgroundEndTime,

        address photoFrameAddress,
        uint photoFrameAmount,
        uint photoFrameEndTime,

        address armsAddress,
        uint armsAmount,
        uint armsEndTime,

        address petAddress,
        uint petAmount,
        uint petEndTime
  ){
        Equipment storage equipment = GirlIndexToEquipment[_girlId];
        if (equipment.BackgroundEndTime >= now) {
            BackgroundAddress = equipment.BackgroundAddress;
            BackgroundAmount = equipment.BackgroundAmount;
            BackgroundEndTime = equipment.BackgroundEndTime;
        }

        if (equipment.photoFrameEndTime >= now) {
            photoFrameAddress = equipment.photoFrameAddress;
            photoFrameAmount = equipment.photoFrameAmount;
            photoFrameEndTime = equipment.photoFrameEndTime;
        }

        if (equipment.armsEndTime >= now) {
            armsAddress = equipment.armsAddress;
            armsAmount = equipment.armsAmount;
            armsEndTime = equipment.armsEndTime;
        }

        if (equipment.petEndTime >= now) {
            petAddress = equipment.petAddress;
            petAmount = equipment.petAmount;
            petEndTime = equipment.petEndTime;
        }
    }
}
