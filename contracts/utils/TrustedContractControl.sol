pragma solidity ^0.4.21;
import './Ownable.sol';
import "./AddressUtils.sol";

contract TrustedContractControl is Ownable{
  using AddressUtils for address;

  mapping (address => bool) public trustedContractList;

  modifier onlyTrustedContract(address _contractAddress) {
    require(trustedContractList[_contractAddress]);
    _;
  }

  event AddTrustedContract(address contractAddress);
  event RemoveTrustedContract(address contractAddress);


  function addTrustedContracts(address[] _contractAddress) onlyOwner public {
    for(uint i=0; i<_contractAddress.length; i++) {
      require(addTrustedContract(_contractAddress[i]));
    }
  }


  // need to add GirlSummon, GirlRecycle contract into the trusted list.
  function addTrustedContract(address _contractAddress) onlyOwner public returns (bool){
    require(!trustedContractList[_contractAddress]);
    require(_contractAddress.isContract());
    trustedContractList[_contractAddress] = true;
    emit AddTrustedContract(_contractAddress);
    return true;
  }

  function removeTrustedContract(address _contractAddress) onlyOwner public {
    require(trustedContractList[_contractAddress]);
    trustedContractList[_contractAddress] = false;
    emit RemoveTrustedContract(_contractAddress);
  }
}
