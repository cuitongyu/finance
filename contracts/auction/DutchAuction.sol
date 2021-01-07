pragma solidity >=0.5.0 <0.6.0;
import "../lib/SafeMath.sol";
import "../lib/Ownable.sol";
import "../lib/IERC721.sol";
import "../lib/Address.sol";

interface CalcReward {
    function calcAucReward(address _address, uint256 _rewart)
        external
        returns (uint256);
}

contract DutchAuction is Ownable {
    using SafeMath for uint256;
    using Address for address;
    uint256 _type = 3;
    uint256 private aucId = 0;
    uint256 persent = 1000;
    // 白名单
    mapping(address => bool) whileList;
    address public platformAddress;
    address public dividendsAddress;
    uint256 public fee = 100; // 手续费
    uint256 public platformFee = 800; // 平台项目方
    uint256 public dividendsFee = 100; // 分红
    uint256 public inviteBuyerFee = 100; // 买方推荐奖励
    uint256 public inviteSellerFee = 10; // 卖方推荐奖励

    CalcReward calc; // 计算合约
    address public calcAddress; // 计算合约
    mapping(address => uint256[]) public tokenOwner;

    mapping(uint256 => AuctionInfo) public auctionInfo;
    mapping(uint256 => bool) public myAuctionIdverify;
    mapping(address => uint256[]) public myAuctionIds;
    mapping(uint256 => uint256) public myAuctionIndex;

    // NFTToken 对应的 tokenId => NFT
    mapping(address => mapping(uint256 => AuctionInfo)) public auctionInfoMap;
    mapping(address => mapping(uint256 => NftInfo)) public nftInfoMap;
    mapping(address => mapping(uint256 => bool)) public nftInfoIsExist;

    // 当前NFT最近一次拍卖历史
    mapping(address => mapping(uint256 => AuctionInfo))
        public historyAuctionMap;

    struct NftInfo {
        address token;
        uint256 tokenId;
        uint256 lastDealPrice;
        uint256 lastDealTime;
        uint256 status; // 1 auction,2 cancel,3 over
    }

    struct AuctionInfo {
        uint256 aucId;
        address token;
        uint256 tokenId;
        address seller;
        address buyer;
        uint256 xCount;
        uint256 ld; // 最低涨幅
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 duration;
        uint256 status; // 1 auction,2 cancel,3 over
    }

    event ApplyDutchAuction(
        address token,
        uint256 tokenId,
        uint256 start_price,
        uint256 end_price,
        address seller,
        uint256 duration,
        uint256 ld
    );
    event DutchAuctions(
        address token,
        uint256 tokenId,
        uint256 current_price,
        address buyer,
        uint256 xCount
    );
    event WithdrawReward(address _from, address _to, uint256 _amount);
    event DutchRevoke(address token, uint256 tokenId);

    constructor(
        address _platAddress,
        address _dividendsAddress,
        address _calc
    ) public {
        platformAddress = _platAddress;
        dividendsAddress = _dividendsAddress;
        calc = CalcReward(_calc);
        calcAddress = _calc;
    }

    function applyAuction(
        address _token,
        uint256 _tokenId,
        uint256 _ltr,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _duration
    ) external {
        IERC721 nft = IERC721(_token);
        nft.transferFrom(msg.sender, address(this), _tokenId);
        aucId = aucId.add(1);
        uint256 id = aucId;

        if (!nftInfoIsExist[_token][_tokenId]) {
            NftInfo memory nftInfo = NftInfo(_token, _tokenId, 0, 0, 1);
            nftInfoMap[_token][_tokenId] = nftInfo;
            nftInfoIsExist[_token][_tokenId] = true;
        }

        AuctionInfo memory info = AuctionInfo(
            id,
            _token,
            _tokenId,
            msg.sender,
            address(0),
            0,
            _ltr,
            _startPrice,
            _endPrice,
            block.timestamp,
            _duration,
            1
        );
        if (!myAuctionIdverify[id]) {
            myAuctionIndex[id] = myAuctionIds[msg.sender].length;
            myAuctionIds[msg.sender].push(id);
            myAuctionIdverify[id] = true;
        }
        auctionInfo[id] = info;
        auctionInfoMap[_token][_tokenId] = info;

        emit ApplyDutchAuction(
            _token,
            _tokenId,
            _startPrice,
            _endPrice,
            msg.sender,
            _duration,
            info.ld
        );
    }

    function auction(address _token, uint256 _tokenId) external payable {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        require(msg.sender != info.seller, "Can't buy by yourself");
        require(block.timestamp < info.startTime.add(info.duration), "is end");
        info.status = 3;
        info.buyer = msg.sender;
        info.xCount = info.xCount.add(1);

        NftInfo storage nftInfo = nftInfoMap[_token][_tokenId];
        nftInfo.lastDealPrice = msg.value;
        nftInfo.lastDealTime = block.timestamp;
        nftInfo.status = 3;

        // 平台手续费
        uint256 feeAmount = msg.value.mul(fee).div(persent);
        // 项目方
        uint256 platReward = feeAmount.mul(platformFee).div(persent);
        // 分红池
        uint256 dividendsReward = feeAmount.mul(dividendsFee).div(persent);

        // 买方推荐总奖励 （平台手续费出）
        uint256 inviteBuyerReward = feeAmount.mul(inviteBuyerFee).div(persent);
        // 买方推荐需要奖励 （平台手续费出）
        uint256 buyerReward = getCalcResult(info.buyer, inviteBuyerReward);

        // 卖方推荐奖励
        uint256 inviteSellerReward = msg.value.mul(inviteSellerFee).div(
            persent
        );
        // 计算卖方推荐奖励 (卖家出)
        uint256 sellerReward = getCalcResult(info.seller, inviteSellerReward);
        // // 平台获取的收益
        uint256 platFormReward = platReward.add(inviteBuyerReward).sub(
            buyerReward
        );
        address(uint160(platformAddress)).transfer(platFormReward);
        // 分红池
        address(uint160(dividendsAddress)).transfer(dividendsReward);
        // 卖方获取的收益
        uint256 userReward = msg.value.sub(feeAmount).sub(sellerReward);
        address(uint160(info.seller)).transfer(userReward);

        auctionInfo[info.aucId] = info;
        historyAuctionMap[_token][_tokenId] = info;
        removeOwnerAuc(info.seller, info.aucId);
        // 买方获取的收益
        IERC721 nft = IERC721(info.token);
        nft.transferFrom(address(this), msg.sender, info.tokenId);

        emit DutchAuctions(info.token, info.tokenId, msg.value, msg.sender, 1);
    }

    function withdrawReward(address _address, uint256 _amount)
        external
        onlyWhile(msg.sender)
    {
        address(uint160(_address)).transfer(_amount);
        emit WithdrawReward(address(this), _address, _amount);
    }

    function revoke(address _token, uint256 _tokenId) external {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        require(info.status == 1, " nft Be auctioned ");
        IERC721 nft = IERC721(info.token);
        nft.transferFrom(address(this), info.seller, info.tokenId);
        removeOwnerAuc(info.seller, info.aucId);
        info.status = 2;
        auctionInfo[info.aucId] = info;
        emit DutchRevoke(info.token, info.tokenId);
    }

    function getAuctionPrice(address _token, uint256 _tokenId)
        external
        view
        returns (uint256 r_price, uint256 r_time)
    {
        NftInfo storage info = nftInfoMap[_token][_tokenId];
        return (info.lastDealPrice, info.lastDealTime);
    }

    function getMyAuctionIds(address _address)
        external
        view
        returns (uint256[] memory ids)
    {
        return myAuctionIds[_address];
    }

    function getAuctionInfo(uint256 _id)
        external
        view
        returns (
            uint256 aucIndex,
            address token,
            uint256 tokenId,
            address seller,
            address buyer,
            uint256 xCount,
            uint256 ld, // 涨幅
            uint256 startPrice,
            uint256 endPrice,
            uint256 startTime,
            uint256 duration,
            uint256 status
        )
    {
        AuctionInfo memory info = auctionInfo[_id];
        return (
            info.aucId,
            info.token,
            info.tokenId,
            info.seller,
            info.buyer,
            info.xCount,
            info.ld,
            info.startPrice,
            info.endPrice,
            info.startTime,
            info.duration,
            info.status
        );
    }

    function getCurrentPrice(address _token, uint256 _tokenId)
        external
        view
        returns (uint256 r_price)
    {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        uint256 price = block
            .timestamp
            .sub(info.startTime)
            .div(info.duration)
            .mul(info.ld);
        if (price < info.endPrice) {
            return info.endPrice;
        }

        return info.startPrice.sub(price);
    }

    function removeOwnerAuc(address _owner, uint256 _index) private {
        uint256[] storage ids = myAuctionIds[_owner];
        for (uint256 i = myAuctionIndex[_index]; i < ids.length - 1; i++) {
            ids[i] = ids[i + 1];
        }
        delete ids[myAuctionIndex[_index]];
        ids.length--;
    }

    function calcReward(address _calc) external onlyOwner {
        calc = CalcReward(_calc);
        calcAddress = _calc;
    }

    // 添加白名单
    function addToWhile(address _addr) public onlyOwner {
        whileList[_addr] = true;
    }

    function withdraw(
        address token,
        uint256 tokenId,
        address _from,
        address _to
    ) external onlyOwner {
        IERC721 nft = IERC721(token);
        nft.transferFrom(_from, _to, tokenId);
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function setPlatformFee(uint256 _fee) public onlyOwner {
        platformFee = _fee; // 平台
    }

    function setDividendsFee(uint256 _fee) public onlyOwner {
        dividendsFee = _fee; // 分红
    }

    function setInviteBuyerFee(uint256 _fee) public onlyOwner {
        inviteBuyerFee = _fee; // 买方邀请
    }

    function setInviteSellerFee(uint256 _fee) public onlyOwner {
        inviteSellerFee = _fee; // 卖方邀请
    }

    function setPlatformAddress(address _address) external onlyOwner {
        platformAddress = _address;
    }

    function setDividendsAddress(address _address) external onlyOwner {
        dividendsAddress = _address;
    }

    function getCalcResult(address _address, uint256 _amount)
        public
        returns (uint256)
    {
        // 计算推荐奖励
        return calc.calcAucReward(_address, _amount);
    }

    // 白名单验证
    modifier onlyWhile(address _addr) {
        require(whileList[_addr], "caller is not the whileList!");
        _;
    }
}
