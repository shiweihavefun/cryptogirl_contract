pragma solidity ^0.4.21;
import '../utils/Pausable.sol';
import '../utils/AccessControl.sol';
import '../utils/SafeMath.sol';
import '../utils/Serialize.sol';
import '../equipments/StandardToken.sol';
import '../equipments/TokenReceiver.sol';
contract EquipmentMarket is Pausable, Serialize, TokenReceiver, AccessControl {
    using SafeMath for uint256;
    event SaleCreate(uint256 id, address seller, address token, uint256 amount, uint256 price );
    event SaleSuccess(uint256 id,  address token, address seller, address buyer, uint256 amount);
    event SaleCancel(uint256 id, address seller, address token, uint256 amount);
    event SaleClear(uint256 id);

    mapping(address => bool) public tokenToStatus;

    // Cut owner takes on each auction, measured in basis points (1/100 of a percent).
    // Values 0-10,000 map to 0%-100%
    uint public ownerCut;

    struct Sale{
        address seller;
        address token;
        uint256 amount;
        uint256 unitPrice;
    }
    mapping(uint256 => Sale) public sales;

    modifier onlySeller(uint256 _saleId){
        require(msg.sender == sales[_saleId].seller);
        _;
    }

    modifier validToken(address _token){
        require (tokenToStatus[_token]);
        _;
    }
    modifier onlyOnSale(uint256 _saleId){
        require(sales[_saleId].seller != address(0x0));
        _;
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

    function receiveApproval(address _from, uint _amount, address _tokenAddress, bytes _data) public whenNotPaused {
     // _amount must be mul of 1 ether, align with buy func 
     require((_amount % 1 ether) == 0 );
     require(StandardToken(_tokenAddress).transferFrom(_from, address(this), _amount));
      uint unitPrice;
      uint offset = 32;
      (unitPrice, offset) = getUint(offset, _data);
      createSale(_from, _tokenAddress, _amount, unitPrice);
    }

    function createSale (
        address _seller,
        address _token,
        uint256 _amount,
        uint256 _unitPrice
    ) internal validToken(_token){

        uint256 saleId = uint256(keccak256(block.timestamp,block.number, _seller, _token, _amount, _unitPrice));
        Sale memory sale = Sale({
            seller:_seller,
            token:_token,
            amount:_amount,
            unitPrice:_unitPrice
        });
        sales[saleId] = sale;
        emit SaleCreate(saleId, _seller, _token, _amount, _unitPrice);
    }

    function getSale(uint256 _saleId) public view onlyOnSale(_saleId) returns(
        address seller,
        address token,
        uint256 amount,
        uint256 unitPrice
    ){
        Sale storage sale = sales[_saleId];
        seller = sale.seller;
        token = sale.token;
        amount = sale.amount;
        unitPrice = sale.unitPrice;

    }
    function _clearSale(uint256 _saleId) private{
        emit SaleClear(_saleId);
        delete sales[_saleId];
    }

    function buy(uint256 _saleId, uint256 _amount) public onlyOnSale(_saleId) payable{
        Sale storage sale = sales[_saleId];
        require(_amount <= sale.amount);
        require((_amount % 1 ether) == 0 );
        require(msg.value == sale.unitPrice.mul(_amount.div(1 ether)));

        // contract owner get a cut
        uint cut = _computeCut(msg.value);
        uint sellerProceeds = msg.value.sub(cut);

        sale.seller.transfer(sellerProceeds);
        StandardToken standardToken = StandardToken(sale.token);
        standardToken.transfer(msg.sender, _amount);
        sale.amount = sale.amount.sub(_amount);
        emit SaleSuccess(_saleId, sale.token, sale.seller, msg.sender, _amount);
        if (sale.amount == 0){
            _clearSale(_saleId);
        }
    }

    function _computeCut(uint _price) internal view returns (uint) {
      return _price.mul(ownerCut).div(10000);
    }


    function withDrawBalance(uint256 amount) public onlyCFO {
      require(address(this).balance >= amount);
      CFO.transfer(amount);
    }

    function cancel(uint256 _saleId) public onlySeller(_saleId) {
        Sale storage sale = sales[_saleId];
        //返回装备给用户
        StandardToken standardToken = StandardToken(sale.token);
        standardToken.transfer(sale.seller, sale.amount);
        emit SaleCancel(_saleId, sale.seller, sale.token, sale.amount);
        _clearSale(_saleId);

    }

}
