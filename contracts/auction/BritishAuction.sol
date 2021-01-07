pragma solidity >=0.5.0 <0.6.0;
import "../lib/SafeMath.sol";
import "../lib/IERC721.sol";
import "../lib/Ownable.sol";
import "../lib/Address.sol";

interface CalcReward {
    function calcAucReward(address _address, uint256 _rewart)
        external
        returns (uint256);
}

contract BritishAuction is Ownable {
    using SafeMath for uint256;
    using Address for address;

    // 白名单
    mapping(address => bool) whileList;
    uint256 _type = 2;
    uint256 private aucId = 0;
    uint256 public overTime = 12 hours;
    uint256 persent = 1000;
    uint256 aucPersent = 100;
    address public calcAddress; // 计算合约
    address public platformAddress;
    address public dividendsAddress;
    uint256 public fee = 100; // 手续费
    uint256 public platformFee = 800; // 平台
    uint256 public dividendsFee = 100; // 分红
    uint256 public inviteBuyerFee = 100; // 买方推荐奖励
    uint256 public inviteSellerFee = 10; // 卖方推荐奖励

    CalcReward calc; // 计算合约

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
        uint256[2] increase; // 涨幅
        uint256 submitPrice;
        uint256 currentPrice;
        uint256 startTime;
        uint256 aucTime;
        uint256 duration;
        uint256 status; // 1 auction,2 cancel,3 over
    }

    event ApplyBritishAuction(
        address token,
        uint256 tokenId,
        uint256 applyTime,
        uint256 submit_price,
        uint256 minIncrese,
        uint256 maxIncrese,
        address seller,
        uint256 duration
    );
    event BritishAuctions(
        address token,
        uint256 tokenId,
        uint256 aucTime,
        uint256 current_price,
        address buyer,
        uint256 xCount
    );
    event BritishWithdraw(address token, uint256 tokenId);
    event WithdrawReward(address _from, address _to, uint256 _amount);
    event BritishRevoke(address token, uint256 tokenId);

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
        uint256 _price,
        uint256 _minIncrease,
        uint256 _maxIncrease,
        uint256 _duration
    ) external {
        IERC721 nft = IERC721(_token);
        nft.transferFrom(msg.sender, address(this), _tokenId);
        aucId = aucId.add(1);
        uint256 id = aucId;
        uint256[2] memory increase = [_minIncrease, _maxIncrease];
        if (_duration < 0) {
            _duration = overTime;
        }

        if (!nftInfoIsExist[_token][_tokenId]) {
            NftInfo memory nftInfo = NftInfo(_token, _tokenId, 0, 0, 1);
            nftInfoMap[_token][_tokenId] = nftInfo;
            nftInfoIsExist[_token][_tokenId] = true;
        }

        uint256 time = block.timestamp;
        AuctionInfo memory info = AuctionInfo(
            id,
            _token,
            _tokenId,
            msg.sender,
            msg.sender,
            0,
            increase,
            _price,
            _price,
            time,
            time,
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

        emit ApplyBritishAuction(
            _token,
            _tokenId,
            time,
            _price,
            info.increase[0],
            info.increase[1],
            msg.sender,
            _duration
        );
    }

    function auction(address _token, uint256 _tokenId) external payable {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        require(msg.sender != info.buyer, "Can't buy by yourself");
        if (info.xCount > 0) {
            require(
                block.timestamp - info.aucTime < info.duration,
                "Token auction time not over"
            );
            uint256 minIncrese = info.increase[0];
            uint256 maxIncrese = info.increase[1];
            uint256 min = info.currentPrice.mul(minIncrese).div(aucPersent).add(
                info.currentPrice
            );
            uint256 max = info.currentPrice.mul(maxIncrese).div(aucPersent).add(
                info.currentPrice
            );
            require(min <= msg.value && msg.value <= max, "Submit price wrong");
            Address.sendValue(Address.toPayable(info.buyer), info.currentPrice);
            // address(uint160(platformAddress))
            removeOwnerAuc(info.buyer, info.aucId);
        }

        // add seller
        myAuctionIndex[info.aucId] = myAuctionIds[msg.sender].length;
        myAuctionIds[msg.sender].push(info.aucId);
        info.aucTime = block.timestamp;
        info.buyer = msg.sender;
        info.currentPrice = msg.value;
        info.xCount = info.xCount.add(1);
        auctionInfo[info.aucId] = info;
        auctionInfoMap[_token][_tokenId] = info;
        emit BritishAuctions(
            info.token,
            info.tokenId,
            block.timestamp,
            msg.value,
            msg.sender,
            info.xCount
        );
    }

    function revoke(address _token, uint256 _tokenId) external {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        IERC721 nft = IERC721(info.tokenId);
        nft.transferFrom(address(this), info.seller, info.tokenId);
        require(info.xCount == 0, " nft Be auctioned ");
        removeOwnerAuc(info.seller, info.aucId);
        info.status = 2;
        auctionInfo[info.aucId] = info;

        emit BritishRevoke(info.token, info.tokenId);
    }

    function withdraw(address _token, uint256 _tokenId) external {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];

        require(
            info.xCount > 0 && (block.timestamp - info.aucTime > info.duration),
            "Token auction time not over"
        );

        info.status = 3;

        NftInfo storage nftInfo = nftInfoMap[_token][_tokenId];
        nftInfo.status = 3;
        nftInfo.lastDealPrice = info.currentPrice;
        nftInfo.lastDealTime = block.timestamp;

        auctionInfo[info.aucId] = info;

        removeOwnerAuc(info.seller, info.aucId);
        removeOwnerAuc(info.buyer, info.aucId);

        // 平台手续费
        uint256 feeAmount = info.currentPrice.mul(fee).div(persent);
        // 项目方
        uint256 platReward = feeAmount.mul(platformFee).div(persent);
        // 分红池
        uint256 dividendsReward = feeAmount.mul(dividendsFee).div(persent);

        uint256 buyerTotalReward = feeAmount.mul(inviteBuyerFee).div(persent);
        // 计算买方推荐奖励 平台出
        uint256 buyerReward = getCalcResult(info.buyer, buyerTotalReward);

        // 推荐总费用
        uint256 sellerTotalReward = info.currentPrice.mul(inviteSellerFee).div(
            persent
        );
        // 计算卖方推荐奖励
        uint256 sellerReward = getCalcResult(info.seller, sellerTotalReward);
        // 平台获取的收益
        Address.sendValue(
            platformAddress.toPayable(),
            platReward.add(buyerTotalReward).sub(buyerReward)
        );
        // 分红池
        Address.sendValue(dividendsAddress.toPayable(), dividendsReward);

        // 卖方获取的收益
        Address.sendValue(
            info.seller.toPayable(),
            info.currentPrice.sub(feeAmount).sub(sellerReward)
        );

        historyAuctionMap[_token][_tokenId] = info;

        // 买方获取的收益
        IERC721 nft = IERC721(info.token);
        nft.transferFrom(address(this), info.buyer, info.tokenId);
        emit BritishWithdraw(info.token, info.tokenId);
    }

    function withdrawReward(address _address, uint256 _amount)
        external
        onlyWhile(msg.sender)
    {
        Address.sendValue(_address.toPayable(), _amount);
        emit WithdrawReward(address(this), _address, _amount);
    }

    function withdrawNft(
        address token,
        uint256 tokenId,
        address _from,
        address _to
    ) external onlyOwner {
        IERC721 nft = IERC721(token);
        nft.transferFrom(_from, _to, tokenId);
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
            uint256[2] memory increase, // 涨幅
            uint256[2] memory price,
            uint256 startTime,
            uint256 aucTime,
            uint256 duration,
            uint256 status
        )
    {
        AuctionInfo memory info = auctionInfo[_id];
        // uint256[2] memory r_increate = [info.increase[0], info.increase[1]];
        uint256[2] memory r_price = [info.submitPrice, info.currentPrice];
        return (
            info.aucId,
            info.token,
            info.tokenId,
            info.seller,
            info.buyer,
            info.xCount,
            info.increase,
            r_price,
            info.startTime,
            info.aucTime,
            info.duration,
            info.status
        );
    }

    function getAuctionInfoMap(address _token, uint256 _tokenId)
        external
        view
        returns (
            address token,
            uint256 tokenId,
            address seller,
            address buyer,
            uint256 xCount,
            uint256[2] memory increase, // 涨幅
            uint256[2] memory price,
            uint256 startTime,
            uint256 aucTime,
            uint256 duration,
            uint256 status
        )
    {
        AuctionInfo memory info = auctionInfoMap[_token][_tokenId];
        // uint256[2] memory r_increate = [info.increase[0], info.increase[1]];
        uint256[2] memory r_price = [info.submitPrice, info.currentPrice];
        return (
            info.token,
            info.tokenId,
            info.seller,
            info.buyer,
            info.xCount,
            info.increase,
            r_price,
            info.startTime,
            info.aucTime,
            info.duration,
            info.status
        );
    }

    function setCalcReward(address _calc) external onlyOwner {
        calc = CalcReward(_calc);
        calcAddress = _calc;
    }

    function getCalcResult(address _address, uint256 _amount)
        public
        returns (uint256)
    {
        // 计算推荐奖励
        return calc.calcAucReward(_address, _amount);
    }

    function removeOwnerAuc(address _owner, uint256 _index) private {
        uint256[] storage ids = myAuctionIds[_owner];
        for (uint256 i = myAuctionIndex[_index]; i < ids.length - 1; i++) {
            ids[i] = ids[i + 1];
        }
        delete ids[myAuctionIndex[_index]];
        ids.length--;
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

    function setPlatformAddress(address _address) external onlyOwner {
        platformAddress = _address;
    }

    function setDividendsAddress(address _address) external onlyOwner {
        dividendsAddress = _address;
    }

    function setInviteBuyerFee(uint256 _fee) public onlyOwner {
        inviteBuyerFee = _fee; // 买方邀请
    }

    function setInviteSellerFee(uint256 _fee) public onlyOwner {
        inviteSellerFee = _fee; // 卖方邀请
    }

    // 添加白名单
    function addToWhile(address _addr) public onlyOwner {
        whileList[_addr] = true;
    }

    // 白名单验证
    modifier onlyWhile(address _addr) {
        require(whileList[_addr], "caller is not the whileList!");
        _;
    }
}
