pragma solidity ^0.4.21;
import './ERC721BasicToken.sol';
import '../utils/Serialize.sol';

// add atomic swap feature in the token contract.
contract GirlBasicToken is ERC721BasicToken, Serialize {

  event CreateGirl(address owner, uint256 tokenID, uint256 genes, uint64 birthTime, uint64 cooldownEndTime, uint16 starLevel);
  event CoolDown(uint256 tokenId, uint64 cooldownEndTime);
  event GirlUpgrade(uint256 tokenId, uint64 starLevel);

  struct Girl{
    /**
    少女基因,生成以后不会改变
    **/
    uint genes;

    /*
    出生时间 少女创建时候的时间戳
    */
    uint64 birthTime;

    /*
    冷却结束时间
    */
    uint64 cooldownEndTime;
    /*
    star level
    */
    uint16 starLevel;
  }

  Girl[] girls;


  function totalSupply() public view returns (uint256) {
    return girls.length;
  }

  function getGirlGene(uint _index) public view returns (uint) {
    return girls[_index].genes;
  }

  function getGirlBirthTime(uint _index) public view returns (uint64) {
    return girls[_index].birthTime;
  }

  function getGirlCoolDownEndTime(uint _index) public view returns (uint64) {
    return girls[_index].cooldownEndTime;
  }

  function getGirlStarLevel(uint _index) public view returns (uint16) {
    return girls[_index].starLevel;
  }

  function isNotCoolDown(uint _girlId) public view returns(bool) {
    return uint64(now) > girls[_girlId].cooldownEndTime;
  }

  function _createGirl(
      uint _genes,
      address _owner,
      uint16 _starLevel
  ) internal returns (uint){
      Girl memory _girl = Girl({
          genes:_genes,
          birthTime:uint64(now),
          cooldownEndTime:0,
          starLevel:_starLevel
      });
      uint256 girlId = girls.push(_girl) - 1;
      _mint(_owner, girlId);
      emit CreateGirl(_owner, girlId, _genes, _girl.birthTime, _girl.cooldownEndTime, _girl.starLevel);
      return girlId;
  }

  function _setCoolDownTime(uint _tokenId, uint _coolDownTime) internal {
    girls[_tokenId].cooldownEndTime = uint64(now.add(_coolDownTime));
    emit CoolDown(_tokenId, girls[_tokenId].cooldownEndTime);
  }

  function _LevelUp(uint _tokenId) internal {
    require(girls[_tokenId].starLevel < 65535);
    girls[_tokenId].starLevel = girls[_tokenId].starLevel + 1;
    emit GirlUpgrade(_tokenId, girls[_tokenId].starLevel);
  }

  // ---------------
  // this is atomic swap for girl to be set cross chain.
  // ---------------
  uint8 constant public GIRLBUFFERSIZE = 50;  // buffer size need to serialize girl data; used for cross chain sync

  struct HashLockContract {
    address sender;
    address receiver;
    uint tokenId;
    bytes32 hashlock;
    uint timelock;
    bytes32 secret;
    States state;
    bytes extraData;
  }

  enum States {
    INVALID,
    OPEN,
    CLOSED,
    REFUNDED
  }

  mapping (bytes32 => HashLockContract) private contracts;

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
    uint tokenId,
    bytes32 hashlock,
    uint timelock,
    bytes extraData
  );

  event SwapClosed(bytes32 indexed contractId);
  event SwapRefunded(bytes32 indexed contractId);

  function open (
    address _receiver,
    bytes32 _hashlock,
    uint _duration,
    uint _tokenId
  ) public
    onlyOwnerOf(_tokenId)
    returns (bytes32 contractId)
  {
    uint _timelock = now.add(_duration);

    // compute girl data;
    bytes memory _extraData = new bytes(GIRLBUFFERSIZE);
    uint offset = GIRLBUFFERSIZE;

    offset = addUint16(offset, _extraData, girls[_tokenId].starLevel);
    offset = addUint64(offset, _extraData, girls[_tokenId].cooldownEndTime);
    offset = addUint64(offset, _extraData, girls[_tokenId].birthTime);
    offset = addUint(offset, _extraData, girls[_tokenId].genes);

    contractId = keccak256 (
      msg.sender,
      _receiver,
      _tokenId,
      _hashlock,
      _timelock,
      _extraData
    );

    // the new contract must not exist
    require(!_contractExists(contractId));

    // temporary change the ownership to this contract address.
    // the ownership will be change to user when close is called.
    clearApproval(msg.sender, _tokenId);
    removeTokenFrom(msg.sender, _tokenId);
    addTokenTo(address(this), _tokenId);


    contracts[contractId] = HashLockContract(
      msg.sender,
      _receiver,
      _tokenId,
      _hashlock,
      _timelock,
      0x0,
      States.OPEN,
      _extraData
    );

    emit NewHashLockContract(contractId, msg.sender, _receiver, _tokenId, _hashlock, _timelock, _extraData);
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

    // transfer token ownership from this contract address to receiver.
    // clearApproval(address(this), c.tokenId);
    removeTokenFrom(address(this), c.tokenId);
    addTokenTo(c.receiver, c.tokenId);

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

    // transfer token ownership from this contract address to receiver.
    // clearApproval(address(this), c.tokenId);
    removeTokenFrom(address(this), c.tokenId);
    addTokenTo(c.sender, c.tokenId);


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
      bytes32 secret,
      bytes extraData
    )
  {
    HashLockContract memory c = contracts[_contractId];
    return (
      c.sender,
      c.receiver,
      c.tokenId,
      c.hashlock,
      c.timelock,
      c.secret,
      c.extraData
    );
  }


}
