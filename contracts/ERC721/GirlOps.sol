pragma solidity ^0.4.21;
import './GirlBasicToken.sol';
import '../utils/TrustedContractControl.sol';

contract GirlOps is GirlBasicToken, TrustedContractControl {

  string public name = "Cryptogirl";
  string public symbol = "CG";
  
  function createGirl(uint _genes, address _owner, uint16 _starLevel)
      onlyTrustedContract(msg.sender) public returns (uint) {
      require (_starLevel > 0);
      return _createGirl(_genes, _owner, _starLevel);
  }

  function createPromotionGirl(uint[] _genes, address _owner, uint16 _starLevel) onlyOwner public {
  	require (_starLevel > 0);
    for (uint i=0; i<_genes.length; i++) {
      _createGirl(_genes[i], _owner, _starLevel);
    }
  }

  function burnGirl(address _owner, uint _tokenId) onlyTrustedContract(msg.sender) public {
      _burn(_owner, _tokenId);
  }

  function setCoolDownTime(uint _tokenId, uint _coolDownTime)
      onlyTrustedContract(msg.sender) public {
      _setCoolDownTime(_tokenId, _coolDownTime);
  }

  function levelUp(uint _tokenId)
      onlyTrustedContract(msg.sender) public {
      _LevelUp(_tokenId);
  }

  function safeTransferFromWithData(
    address _from,
    address _to,
    uint256 _tokenId,
    bytes _data
  ) public {
      safeTransferFrom(_from,_to,_tokenId,_data);
  }


}
