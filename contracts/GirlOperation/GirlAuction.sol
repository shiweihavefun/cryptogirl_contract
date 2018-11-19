pragma solidity ^0.4.21;
import '../utils/Serialize.sol';
import '../ERC721/ERC721Receiver.sol';
import '../Auction/ClockAuction.sol';
import '../GenesFactory.sol';

contract GirlAuction is Serialize, ERC721Receiver, ClockAuction {

  event GirlAuctionCreated(address sender, uint256 tokenId, uint256 startingPrice, uint256 endingPrice, uint256 duration);


  constructor(address _nftAddr, uint256 _cut) public
        ClockAuction(_nftAddr, _cut) {}
  // example:
  // _startingPrice = 5000000000000,
  // _endingPrice = 100000000000,
  // _duration = 600,
  // _data = 0x0000000000000000000000000000000000000000000000000000000000000258000000000000000000000000000000000000000000000000000000e8d4a510000000000000000000000000000000000000000000000000000000048c27395000

  function onERC721Received(address _from, uint256 _tokenId, bytes _data) public returns(bytes4) {

    require(msg.sender == address(girlBasicToken));

    uint _startingPrice;
    uint _endingPrice;
    uint _duration;

    uint offset = 96;
    (_startingPrice, offset) = getUint(offset, _data);
    (_endingPrice, offset) = getUint(offset, _data);
    (_duration, offset) = getUint(offset, _data);

    require(_startingPrice > _endingPrice);
    require(girlBasicToken.isNotCoolDown(_tokenId));


    emit GirlAuctionCreated(_from, _tokenId, _startingPrice, _endingPrice, _duration);


    require(_startingPrice <= 340282366920938463463374607431768211455);
    require(_endingPrice <= 340282366920938463463374607431768211455);
    require(_duration <= 18446744073709551615);

    Auction memory auction = Auction(
        _from,
        uint128(_startingPrice),
        uint128(_endingPrice),
        uint64(_duration),
        uint64(now)
    );
    _addAuction(_tokenId, auction);

    return ERC721_RECEIVED;
  }




}
