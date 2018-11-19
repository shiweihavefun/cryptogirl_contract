pragma solidity ^0.4.21;
import "./BaseEquipment.sol";
import "../AvatarEquipments.sol";
contract EquipmentToken is BaseEquipment {
    string public name;                //The shoes name: e.g. shining shoes
    string public symbol;              //The shoes symbol: e.g. SS
    uint8 public decimals;           //Number of decimals of the smallest unit


    constructor (
        string _name,
        string _symbol,
        uint256 _cap,
        uint[] _properties
    ) public BaseEquipment(_cap, _properties) {

        name = _name;
        symbol = _symbol;
        decimals = 18;  // set as default
    }

    function setEquipment(address _target, uint _GirlId, uint256 _amount) public returns (bool success) {
        AvatarEquipments eq = AvatarEquipments(_target);
        if (approve(_target, _amount)) {
            eq.setEquipment(msg.sender, _GirlId, _amount, this, properties);
            return true;
        }
    }
}
