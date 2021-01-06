/**
 * NFT Pool
 */
pragma solidity 0.5.16;

import "../lib/Ownable.sol";
import "../lib/Math.sol";
import "../lib/SafeMath.sol";
import "../lib/SafeERC20.sol";

contract NFTInterface {
    struct PokAuctionInfo {
        address seller;
        address buyer;
        uint256 startedAt;
        uint256 endTime;
        uint256 xCount;
        uint256 tokenId;
        uint256 price;
        uint256 currentPrice;
    }

    mapping(uint256 => PokAuctionInfo) public historyAuctions;

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public;

    function getTokenInfo(uint256 _tokenId)
        public
        view
        returns (
            string memory _name,
            uint256 _url,
            uint256 _level
        );
}

contract NFTWrapper {
    using SafeMath for uint256;

    // 抵押币种POK_NFT
    NFTInterface _nft;

    uint256 private _totalSupply;

    // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    mapping(address => uint256) private _balances;

    function _tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        return _ownedTokens[owner];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 price, uint256 tokenId) internal {
        _totalSupply = _totalSupply.add(price); //  总抵押
        _balances[msg.sender] = _balances[msg.sender].add(price); // 个人余额
        _nft.transferFrom(msg.sender, address(this), tokenId);
        _addTokenToOwnerEnumeration(msg.sender, tokenId);
    }

    function withdraw(uint256 price, uint256 tokenId) internal {
        _totalSupply = _totalSupply.sub(price); //  总抵押
        _balances[msg.sender] = _balances[msg.sender].sub(price); // 个人余额
        _nft.transferFrom(address(this), msg.sender, tokenId);
        _removeTokenFromOwnerEnumeration(msg.sender, tokenId);
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        private
    {
        uint256 lastTokenIndex = _ownedTokens[from].length.sub(1);
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        _ownedTokens[from].length--;

        // Note that _ownedTokensIndex[tokenId] hasn't been cleared: it still points to the old slot (now occupied by
        // lastTokenId, or just over the end of the array if the token was the last one).
    }
}

contract POKNFTERC20Pool is NFTWrapper, Ownable {
    using SafeERC20 for IERC20;

    NFTInterface _acu;
    IERC20 token;
    uint256[] public cardToPrice;
    // 开始时间
    uint256 public startTime = 0;
    // 结束时间
    uint256 public periodFinish;
    // 每秒奖励多少
    uint256 public rewardRate;
    // 上次更新时间
    uint256 public lastUpdateTime;
    // 每个令牌存储奖励
    uint256 public rewardPerTokenStored = 0;
    bool private open = true;
    uint256 private constant _gunit = 1e18;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards; // Unclaimed rewards

    event RewardAdded(uint256 reward);
    event Staked(address indexed _from, address indexed _to, uint256 _tokenId);
    event Withdrawn(
        address indexed _from,
        address indexed _to,
        uint256 _tokenId
    );
    event RewardPaid(address indexed user, uint256 reward);
    event SetOpen(bool _open);

    constructor(address _nftToken, address _acutionToken) public {
        cardToPrice.push(0.1 ether);
        cardToPrice.push(0.3 ether);
        cardToPrice.push(0.5 ether);
        cardToPrice.push(1 ether);
        cardToPrice.push(2 ether);
        cardToPrice.push(5 ether);
        cardToPrice.push(10 ether);
        _nft = NFTInterface(_nftToken);
        _acu = NFTInterface(_acutionToken);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /**
     * Calculate the rewards for each token
     * 时间区间单个收益
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(_gunit)
                    .div(totalSupply())
            );
    }

    // 当前收益
    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(_gunit) //why
                .add(rewards[account]);
    }

    function stake(uint256[] memory tokenIds)
        public
        checkOpen
        checkStart
        updateReward(msg.sender)
    {
        require(tokenIds.length > 0, "Cannot stake 0");
        uint256 price;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // 获取NFT 等级
            uint256 level = getTokenInfo(tokenIds[i]);
            // 获取定价
            price = historyAuctions(tokenIds[i]);
            if (price <= 0) {
                price = cardToPrice[level];
            }
            super.stake(price, tokenIds[i]);
            emit Staked(msg.sender, address(this), tokenIds[i]);
        }
    }

    function withdraw(uint256[] memory tokenIds)
        public
        checkStart
        updateReward(msg.sender)
    {
        require(tokenIds.length > 0, "Cannot withdraw 0");
        uint256 price;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // 获取NFT 等级
            uint256 level = getTokenInfo(tokenIds[i]);
            // 获取定价
            price = historyAuctions(tokenIds[i]);
            if (price <= 0) {
                price = cardToPrice[level];
            }
            super.withdraw(price, tokenIds[i]);
            emit Withdrawn(msg.sender, address(this), tokenIds[i]);
        }
    }

    function getTokenInfo(uint256 tokenId) public view returns (uint256) {
        (string memory _name, uint256 _url, uint256 _level) = _nft.getTokenInfo(
            tokenId
        );
        return _level;
    }

    function historyAuctions(uint256 _tokenId) public view returns (uint256) {
        (
            address seller,
            address buyer,
            uint256 startedAt,
            uint256 endTime,
            uint256 xCount,
            uint256 tokenId,
            uint256 price,
            uint256 currentPrice
        ) = _acu.historyAuctions(_tokenId);

        return price;
    }

    function exit() external {
        withdraw(_tokensOfOwner(msg.sender));
        getReward();
    }

    function getReward() public checkStart updateReward(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            token.safeTransfer(msg.sender, reward);
        }
    }

    function withdrawRewardBalance() external onlyOwner {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function getRewardBalance() external view returns (uint256) {
        return address(this).balance;
    }

    modifier checkStart() {
        require(block.timestamp > startTime, "Not start");
        _;
    }

    modifier checkOpen() {
        require(open, "Pool is closed");
        _;
    }

    function isOpen() external view returns (bool) {
        return open;
    }

    function setOpen(bool _open) external onlyOwner {
        open = _open;
        emit SetOpen(_open);
    }

    function getCardPrice() external view returns (uint256[] memory) {
        return cardToPrice;
    }

    function setPrice(uint256 _level, uint256 _price) external onlyOwner {
        require(
            _level >= 0 && _level < cardToPrice.length,
            "Level is not exit"
        );
        cardToPrice[_level] = _price;
    }

    function setTime(
        uint256 _startTime,
        uint256 _period,
        address _token,
        uint256 _amount
    ) external payable onlyOwner updateReward(address(0)) {
        require(_startTime > periodFinish && now > periodFinish, "Can't set");
        // 开始时间
        startTime = _startTime;
        // 结束时间
        periodFinish = _startTime.add(_period);
        // 收益率  总量除以时长
        rewardRate = _amount.div(_period);
        token = IERC20(_token);
        token.safeTransferFrom(msg.sender, address(this), _amount);
        lastUpdateTime = _startTime;
    }
}
