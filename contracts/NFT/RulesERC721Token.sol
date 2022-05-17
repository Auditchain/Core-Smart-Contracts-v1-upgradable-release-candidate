// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "../Auditchain/ValidationsNoCohort.sol";


/**
 * @title RulesERC721Token
 * RulesERC721Token - ERC721Upgradeable contract that and has minting functionality.
 */
contract RulesERC721Token is ERC721Upgradeable,  ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    ValidationsNoCohort public validation;

    mapping(bytes32 => bool) public NFTCompleted;
    event Mint(uint256 tokenId, address recipient);

    function initialize(string memory _name, string memory _symbol, address _validation) public
        
    {
        __ERC721_init(_name, _symbol);
        validation = ValidationsNoCohort(_validation);
    }


   function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) returns (string memory) {
       
        return super.tokenURI(tokenId);
    }
     
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721EnumerableUpgradeable, ERC721Upgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, ERC721Upgradeable) returns (bool) {
       return super.supportsInterface(interfaceId);

    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        super._burn(tokenId);
    }


    /**
     * @dev Mints a token to an enterprise/rule creator with a given validation hashvalidation
     * @param _hash of the validated document
     * @return newTokenId
     */
    function mintTo(bytes32 _hash)
        public
        returns (uint256)
    {
        (,address requestor,, uint256 executionTime , string memory url, uint256 consensus, , , , ) = validation.returnValidationRecord(_hash);
        require(requestor != address(0), "RulesERC721Token:mintTo - Recipient address can't be 0");
        require(executionTime > 0 , "RulesERC721Token:mintTo - This rule hasn't been approved yet");
        require(consensus == 1,  "RulesERC721Token:mintTo - This rule hasn't received sufficient quorum yet");
        require(!NFTCompleted[_hash], "RulesERC721Token:mintTo  - This token has been already claimed");
        uint256 newTokenId = _getNextTokenId();
        NFTCompleted[_hash] = true;
        _safeMint(requestor, newTokenId);
        _setTokenURI(newTokenId, url);
        emit Mint(newTokenId, requestor);
        return newTokenId;
    }

    function mintToPure(address user, string memory url) public returns (uint256) {

        uint256 newTokenId = _getNextTokenId();

        _safeMint(user, newTokenId);
        _setTokenURI(newTokenId, url);
        return newTokenId;

    }

    function _getNextTokenId() private view returns (uint256) {
        return totalSupply().add(1);
    }


}
