pragma solidity ^0.4.21;

contract GenesFactory{
    function mixGenes(uint256 gene1, uint gene2) public returns(uint256);
    function getPerson(uint256 genes) public pure returns (uint256 person);
    function getRace(uint256 genes) public pure returns (uint256);
    function getRarity(uint256 genes) public pure returns (uint256);
    function getBaseStrengthenPoint(uint256 genesMain,uint256 genesSub) public pure returns (uint256);

    function getCanBorn(uint256 genes) public pure returns (uint256 canBorn,uint256 cooldown);
}
