pragma solidity ^0.4.21;
import '../utils/Pausable.sol';
import '../utils/AccessControl.sol';
import '../utils/SafeMath.sol';
import '../utils/Serialize.sol';
import '../equipments/StandardToken.sol';
import '../equipments/TokenReceiver.sol';

contract SeekToPurchase is Pausable, Serialize, TokenReceiver, AccessControl {
    using SafeMath for uint256;
   
    event SeekToPurchaseCreate(uint256 id, address requester, address tokenAddress, uint256 amount, uint256 unitPrice, uint256 startNumber );
    event SeekToPurchaseSuccess(uint256 id, uint256 amount, uint256 price);
    event SeekToPurchaseCancle(uint256 id);
    event SeekToPurchaseClear(uint256 id);
    
    mapping(address => bool) public tokenToStatus;

    uint public ownerCut;

    struct SeekToPurchase{
        address requester; // 求购方
        address token;
        uint256 amount; // 求购数量
        uint256 unitPrice; // 单个求购价格
        uint256 startNumber; // 起售数
    }

    mapping(uint256 => SeekToPurchase) public seekToPurchases;


    modifier onlyRequester(uint256 _seekToPurchaseId){
        require(msg.sender == seekToPurchases[_seekToPurchaseId].requester);
        _;
    }

    modifier validToken(address _token){
        require (tokenToStatus[_token]);
        _;
    }
    modifier onlyOnSeekToPurchase(uint256 _seekToPurchaseId){
        require(seekToPurchases[_seekToPurchaseId].requester != address(0x0));
        _;
    }

    constructor (uint _cut) public {
        ownerCut = _cut;
    }

    function setOwnerCut(uint _cut) public onlyOwner {
      ownerCut  = _cut;
    }

    function addTokenToWhitelist(address _tokenAddress) public onlyOwner {
      tokenToStatus[_tokenAddress] = true;
    }

    function addManyToWhitelist(address[] _tokenAddresses) public onlyOwner {
      for(uint i=0; i<_tokenAddresses.length; i++) {
        tokenToStatus[_tokenAddresses[i]] = true;
      }
    }

    function removeFromWhitelist(address _tokenAddress) public onlyOwner {
      tokenToStatus[_tokenAddress] = false;
    }

    // 发起求购
    function sendSeekToPurchase(address _tokenAddress, uint _amount, uint _unitPrice, uint _startNumber) public validToken(_tokenAddress) whenNotPaused payable{
        require((_amount % 1 ether) == 0 );
        require((_startNumber % 1 ether) == 0 );
        require(_amount >= _startNumber);

        require(msg.value == _unitPrice.mul(_amount.div(1 ether)));

        uint256 seekToPurchaseId = uint256(keccak256(block.timestamp,block.number, msg.sender, _tokenAddress, _amount, _unitPrice, _startNumber));

        SeekToPurchase memory seekToPurchase = SeekToPurchase({
            requester:msg.sender,
            token:_tokenAddress,
            amount:_amount,
            unitPrice:_unitPrice,
            startNumber: _startNumber
        });
        seekToPurchases[seekToPurchaseId] = seekToPurchase;

        emit SeekToPurchaseCreate(seekToPurchaseId, msg.sender, _tokenAddress, _amount, _unitPrice, _startNumber);
    }


    function receiveApproval(address _from, uint _amount, address _tokenAddress, bytes _data) public whenNotPaused {
      require((_amount % 1 ether) == 0 );
      uint seekToPurchaseId;
      uint offset = 32;
      (seekToPurchaseId, offset) = getUint(offset, _data);

      SeekToPurchase storage seekToPurchase = seekToPurchases[seekToPurchaseId];
      require(_tokenAddress == seekToPurchase.token);
      require(seekToPurchase.requester != address(0x0)); //必须在求购中

      // require(seekToPurchase.startNumber <= _amount);

      if(seekToPurchase.amount >= seekToPurchase.startNumber){
        require(_amount >= seekToPurchase.startNumber);
      }
      
      require(seekToPurchase.amount >= _amount);
      require(StandardToken(_tokenAddress).transferFrom(_from, seekToPurchase.requester, _amount));

      uint price = seekToPurchase.unitPrice.mul(_amount.div(1 ether));

      uint cut = _computeCut(price);
      uint proceeds = price.sub(cut);
      seekToPurchase.amount = seekToPurchase.amount.sub(_amount);
      _from.transfer(proceeds);

      emit SeekToPurchaseSuccess(seekToPurchaseId, _amount, proceeds);
      if (seekToPurchase.amount == 0){
        _clearSeekToPurchase(seekToPurchaseId);
      }
    }

    function getSeekToPurchase(uint256 _seekToPurchaseId) public view onlyOnSeekToPurchase(_seekToPurchaseId) returns(
        address requester,
        address token,
        uint256 amount,
        uint256 unitPrice,
        uint256 startNumber
    ){
        SeekToPurchase storage seekToPurchase = seekToPurchases[_seekToPurchaseId];
        requester = seekToPurchase.requester;
        token = seekToPurchase.token;
        amount = seekToPurchase.amount;
        unitPrice = seekToPurchase.unitPrice;
        startNumber = seekToPurchase.startNumber;

    }

    // 删除求购
    function _clearSeekToPurchase(uint256 _seekToPurchaseId) private{
        delete seekToPurchases[_seekToPurchaseId];
        emit SeekToPurchaseClear(_seekToPurchaseId);
    }

    function _computeCut(uint _price) internal view returns (uint) {
      return _price.mul(ownerCut).div(10000);
    }


    function withDrawBalance(uint256 amount) public onlyCFO {
      require(address(this).balance >= amount);
      CFO.transfer(amount);
    }

    // 取消求购
    function cancelSeekToPurchase(uint256 _seekToPurchaseId) public onlyRequester(_seekToPurchaseId) {
        SeekToPurchase storage seekToPurchase = seekToPurchases[_seekToPurchaseId];
        uint256 amount = seekToPurchase.unitPrice.mul(seekToPurchase.amount.div(1 ether));
        require(address(this).balance >= amount);
        msg.sender.transfer(amount);
        delete seekToPurchases[_seekToPurchaseId];
        emit SeekToPurchaseCancle(_seekToPurchaseId);
    }

}
