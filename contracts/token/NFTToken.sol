pragma solidity >=0.5.0 <0.6.0;

import "../lib/ERC721Full.sol";

contract Nft is ERC721Full {
    using SafeMath for uint256;

    struct info {
        string name;
        uint256 url;
        uint256 level;
    }
    mapping(uint256 => info) public TokenForInfo;

    constructor() public ERC721Full("ONE TOKEN", "ONE") {}

    function mint(
        string memory _name,
        uint256 _tokenId,
        uint256 _level
    ) public {
        info memory base = info(_name, 123, _level);
        TokenForInfo[_tokenId] = base;
        _mint(msg.sender, _tokenId);
    }

    function burn(address _from, uint256 tokenId) public {
        _burn(_from, tokenId);
    }

    function transfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) public {
        transferFrom(_from, _to, _tokenId);
    }

    function getTokenInfo(uint256 _tokenId)
        public
        view
        returns (
            string memory _name,
            uint256 _url,
            uint256 _level
        )
    {
        info memory base = TokenForInfo[_tokenId];
        return (base.name, base.url, base.level);
    }
}
