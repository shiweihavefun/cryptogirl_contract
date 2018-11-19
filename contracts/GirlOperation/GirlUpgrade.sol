pragma solidity ^0.4.19;
import '../ERC721/GirlOps.sol';
import '../GenesFactory.sol';
import '../utils/Ownable.sol';

// after deploy need to add this contract to trust list of GirlOps.sol
contract GirlUpgrade is Ownable {
  event UpgradeStatus(address sender, uint256 mainTokenId, bool status);
  event Upgrade(address sender, uint256 mainTokenId, uint rate);
  
  GirlOps public girlOps;
  GenesFactory public genesFactory;
  uint public maxStarLevel;

  mapping (address => bool) public serverAddressList;

  modifier onlyServer {
    require(serverAddressList[msg.sender]);
    _;
  }

  event AddServerAddress(address contractAddress);
  event RemoveServerAddress(address contractAddress);


  function addServerAddresss(address[] _serverAddress) onlyOwner public {
    for(uint i=0; i<_serverAddress.length; i++) {
      require(addServerAddress(_serverAddress[i]));
    }
  }

  function addServerAddress(address _serverAddress) onlyOwner public returns (bool){
    serverAddressList[_serverAddress] = true;
    emit AddServerAddress(_serverAddress);
    return true;
  }

  function removeServerAddress(address _serverAddress) onlyOwner public {
    require(serverAddressList[_serverAddress]);
    serverAddressList[_serverAddress] = false;
    emit RemoveServerAddress(_serverAddress);
  }

  constructor(address _girlOpsAddress,address _genesFactory, address[] _serverAddress, uint _maxStarLevel) public {
    genesFactory = GenesFactory(_genesFactory);
    girlOps = GirlOps(_girlOpsAddress);
    maxStarLevel = _maxStarLevel;
    addServerAddresss(_serverAddress);
    
  }


  function triggerUpgrade(uint _mainTokenId, uint[] _sacrificeId) public {
  	require(_sacrificeId.length > 0);
  	require(_sacrificeId.length <=8);

    require(girlOps.ownerOf(_mainTokenId) == msg.sender);

    require(girlOps.isNotCoolDown(_mainTokenId));

    require(girlOps.getGirlStarLevel(_mainTokenId) < maxStarLevel);
    uint successRate = getSuccessRate(_mainTokenId, _sacrificeId);
    for (uint i = 0; i < _sacrificeId.length; i ++ ) {
      	require(girlOps.isNotCoolDown(_sacrificeId[i]));
      	girlOps.burnGirl(msg.sender, _sacrificeId[i]);
    }

    if (successRate>=100){
      girlOps.levelUp(_mainTokenId);
      emit UpgradeStatus(msg.sender, _mainTokenId, true);
    } else {
      emit Upgrade(msg.sender, _mainTokenId, successRate);
    }
  }

  function upgradeFromServer(uint _token1, uint _rate, uint64 _random) public onlyServer {

    address owner = girlOps.ownerOf(_token1);
    if (_random % 101 <= _rate ){
      girlOps.levelUp(_token1);

      emit UpgradeStatus(owner, _token1, true);
     } else {
      emit UpgradeStatus(owner, _token1, false);
     }

  }


  function getSuccessRate(uint256 _token1, uint256[] _token2) public view returns(uint256) {
      require(_token2.length > 0);
      //新需求，吞噬一次最多8个
      require(_token2.length <=8 );
      require(genesFactory != address(0));

      uint mainGene = girlOps.getGirlGene(_token1);
      uint256 mainRarity = genesFactory.getRarity(mainGene);

      uint totalRate = 0;
      for(uint i = 0; i < _token2.length; i ++){
          uint rate = genesFactory.getBaseStrengthenPoint(mainGene, girlOps.getGirlGene(_token2[i]));
          totalRate = totalRate + rate * (3 ** uint256(girlOps.getGirlStarLevel(_token2[i])-1));
      }
      uint256 needRate = 20;
      if (mainRarity==1){
        needRate = 40;
      } else if (mainRarity==2){
        needRate = 100;
      } else if (mainRarity==3){
        needRate = 200;
      }
      needRate = needRate* (3 ** uint256(girlOps.getGirlStarLevel(_token1)-1));

      return totalRate*100/needRate;
  }


}
