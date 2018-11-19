pragma solidity ^0.4.21;
import './StandardToken.sol';
import './PrizePool.sol';
import './TokenReceiver.sol';
import '../utils/AccessControl.sol';


contract MagicBox is AccessControl, TokenReceiver {
  event AddServerAddress(address contractAddress);
  event RemoveServerAddress(address contractAddress);
  event OpenBoxV2(address addr, uint time, uint openNonceId); // server need to monitor this event to trigger openBoxFromServer

  
  uint[] public prizeIndex;
  uint[] public prizeRange;

  uint public keyRequired;
  uint public boxPrice;              //price to openbox in wei;
  uint public openNonceId;
  address public keyAddress;
  address public prizePoolAddress;
  string public name;                //The shoes name: e.g. MB

  mapping (uint => address) public openNonce;
  mapping (address => bool) public serverAddressList;

  modifier onlyServer {
    require(serverAddressList[msg.sender]);
    _;
  }

  constructor(string _name, address _prizePoolAddress,  address[] _serverAddress,address _keyAddress, uint _keyRequired, uint _boxPrice) public {
    name = _name;
    prizePoolAddress = _prizePoolAddress;
    keyAddress = _keyAddress;
    keyRequired = _keyRequired;
    boxPrice = _boxPrice;
    openNonceId = 0;
    addServerAddresss(_serverAddress);
  }


  function setupPrize(uint[] _prizeIndex, uint[] _prizeRange) public onlyOwner {
    prizeIndex = _prizeIndex;
    prizeRange = _prizeRange;
  }

  function getPrizeIndex(uint random) public view returns (uint) {
    uint maxRange = prizeRange[prizeRange.length -1];
    uint n = random % maxRange;

    uint start = 0;
    uint mid = 0;
    uint end = prizeRange.length-1;

    if (prizeRange[0]>n){
      return 0;
    }
    if (prizeRange[end-1]<=n){
      return end;
    }

    while (start <= end) {
      mid = start + (end - start) / 2;
      if (prizeRange[mid]<=n && n<prizeRange[mid+1]){
          return mid+1;
      } else if (prizeRange[mid+1] <= n) {
        start = mid+1;
      } else {
        end = mid;
      }
    }

    return start;
  }

  function _openBox(address _from, uint _random, uint[] _genes) internal returns (bool) {
    // uint random_number = uint(block.blockhash(block.number-1)) ^ _random;
    // uint index = getPrizeIndex(random_number);

    uint index = getPrizeIndex(_random);
    //uint index = 11;
    PrizePool pl = PrizePool(prizePoolAddress);
    uint count = 0;
    while(count < prizeIndex.length) {
      if(prizeIndex[index] < 10) { // get a girl // reserve first 10 item to girl gene or further special equipment.
        uint genes = 0;
        uint16 level = 1;
        if(prizeIndex[index] > 4){
            genes = _genes[3]; 
            // 固定基因顺序 0 => N | 1 => R | 2 => SR | 3 => SSR
            // prizeIndex 1 ~ 4 是老版本定义的少女，基础星级
            // prizeIndex > 4 是新需求，特殊少女
            if (prizeIndex[index] == 5){ // 2星 SSR
              level = 2;
            } else if (prizeIndex[index] == 6){ // 3星 SSR
              level = 3;
            } else if (prizeIndex[index] == 7){ // 2星 SR
              level = 2;
              genes = _genes[2];
            } else if (prizeIndex[index] == 8){ // 3星 SR
              level = 3;
              genes = _genes[2];
            } else {
              genes = _genes[0]; // 没有定义的直接给N卡
            }
        } else {
          genes = _genes[prizeIndex[index]-1];
        }

        pl.mintGirl(_from, genes, level);
        return true;
      } else if (pl.sendPrize(_from, prizeIndex[index] - 10)) { // send equipment prize successfully
        return true;
      } else {
        count = count + 1;
        index = index + 1;
        if(index == prizeIndex.length) index = 0;
        continue;
      }
    }

    // does not get anything.
    return false;

  }


  function setKeyAddress(address _key) public onlyOwner {
    keyAddress = _key;
  }


  function openBoxFromServer(address _userAddress, uint _random, uint[] _gene, uint _openNonceId) public onlyServer returns (bool) {

    require (openNonce[_openNonceId]==_userAddress,'Nonce Has been used');
    delete openNonce[_openNonceId];
    // only server can call this method.
    _openBox(_userAddress, _random, _gene);
  }

  function openBoxFromServerNoNonce(address _userAddress, uint _random, uint[] _gene) public onlyServer returns (bool) {

    // only server can call this method.
    _openBox(_userAddress, _random, _gene);
  }

  function addOpenBoxFromServer(address _userAddress) public onlyServer {
    openNonceId = openNonceId + 1;
    openNonce[openNonceId] = _userAddress;
     // server need to monitor this event and trigger openBoxFromServer.
    emit OpenBoxV2(_userAddress, now, openNonceId);
  }

  //新需求从myether wallet 直接开箱， 需要payble 没有function name, 把逻辑从magickey 移过来
  function() public payable {
     require(boxPrice > 0, 'this mode is not supported');
     require(msg.value == boxPrice);  // must pay boxprice
     openNonceId = openNonceId + 1;
     openNonce[openNonceId] = msg.sender;
     // server need to monitor this event and trigger openBoxFromServer.
     emit OpenBoxV2(msg.sender, now, openNonceId);
  }


  function receiveApproval(address _from, uint _amount, address _tokenAddress, bytes _data) public {
   require(keyRequired > 0, 'this mode is not supported');
   require(_tokenAddress == keyAddress); // only accept key.
   require(_amount == keyRequired); // need to send required amount;
   require(StandardToken(_tokenAddress).transferFrom(_from, address(this), _amount));

   openNonceId = openNonceId + 1;
   
   openNonce[openNonceId] = _from;
     // server need to monitor this event and trigger openBoxFromServer.

   // server need to monitor this event and trigger openBoxFromServer.
   emit OpenBoxV2(_from, now, openNonceId);

  }

  function withDrawToken(uint _amount) public onlyCFO {
    StandardToken(keyAddress).transfer(CFO, _amount);
  }


  function withDrawBalance(uint256 amount) public onlyCFO {
    require(address(this).balance >= amount);
    if (amount==0){
      CFO.transfer(address(this).balance);
    } else {
      CFO.transfer(amount);
    }
  }

  function setupBoxPrice(uint256 _boxPrice) public onlyCFO {
    boxPrice = _boxPrice;
  }

  function setupKeyRequired(uint256 _keyRequired) public onlyCFO {
    keyRequired = _keyRequired;
  }

  // 获取当前箱子开启类型 
  // 0 碎片、ether都可以开
  // 1 仅碎片可开
  // 2 仅ether可开
  function getMagicBoxType() public view returns (uint8) {
    uint8 boxType = 0;
    if (!(keyRequired > 0 && boxPrice > 0)) {
      if (keyRequired == 0 && boxPrice > 0) {
        boxType = 2;
      } else if (keyRequired > 0 && boxPrice == 0){
        boxType = 1;
      } else {
        revert();
      }
    }
    return boxType;
  }

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

}
