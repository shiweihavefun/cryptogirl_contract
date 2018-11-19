pragma solidity ^0.4.19;
import '../ERC721/GirlOps.sol';
import '../GenesFactory.sol';

// after deploy need to add this contract to trust list of GirlOps.sol
contract GirlSummon {
  GenesFactory public genesFactory;
  GirlOps public girlOps;

  event Summon(address ownner, uint256 token1, uint256 token2, uint newTokenId);

  constructor(address _girlOpsAddress, address _genesFactoryAddress) public {
    genesFactory = GenesFactory(_genesFactoryAddress);
    girlOps = GirlOps(_girlOpsAddress);
  }


  function summon(uint _token1, uint _token2) public returns (uint) {
    require(girlOps.isNotCoolDown(_token1));
    require(girlOps.isNotCoolDown(_token2));
    require(girlOps.ownerOf(_token1) == msg.sender);
    require(girlOps.ownerOf(_token2) == msg.sender);
    uint canBorn_1;
    uint coolDown_1;
    uint canBorn_2;
    uint coolDown_2;

    (canBorn_1, coolDown_1) = genesFactory.getCanBorn(girlOps.getGirlGene(_token1));
    (canBorn_2, coolDown_2) = genesFactory.getCanBorn(girlOps.getGirlGene(_token2));
    require (canBorn_1 > 0);
    require (canBorn_2 > 0);

    uint gene = genesFactory.mixGenes(girlOps.getGirlGene(_token1), girlOps.getGirlGene(_token2));
    uint girlId = girlOps.createGirl(gene, msg.sender, 1);

    girlOps.setCoolDownTime(_token1, _getCoolDownTime(coolDown_1));
    girlOps.setCoolDownTime(_token2, _getCoolDownTime(coolDown_2));
    emit Summon(msg.sender,  _token1,  _token2, girlId);

    return girlId;
    // return 1;
  }

  function isNotCoolDown(uint _token1) public view returns (bool) {
    return girlOps.isNotCoolDown(_token1);
  }


  function _getCoolDownTime(uint _coolDownIndex) internal pure returns (uint cooldownTime) {
    require(_coolDownIndex <= 15);
    if (_coolDownIndex <= 5){
      cooldownTime = uint64(12 hours + (_coolDownIndex * 12 hours)  );
    } else {
      cooldownTime = uint64(72 hours + ((_coolDownIndex - 5) *  1 days) );
    }
    return cooldownTime;
  }

}
