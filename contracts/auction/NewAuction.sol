pragma solidity >=0.5.0 <0.6.0;

import "../lib/SafeMath.sol";
import "../lib/IERC721.sol";
import "../lib/Ownable.sol";
import "../lib/IERC1155.sol";
import "./ERC1155Recevied.sol";

interface CalcReward {
    function calcAucReward(
        address _address,
        uint256 _rewart,
        uint256 _of,
        uint256 _tf
    ) external returns (uint256);
}

contract NewAuction is Ownable, ERC1155Recevied {
    using SafeMath for uint256;

    event ApplyNewAuction(
        address token,
        uint256 tokenId,
        uint256 applyTime,
        uint256 price,
        uint256 ltr,
        address seller,
        uint256 duration
    );
    event NewAuctions(
        address token,
        uint256 tokenId,
        uint256 aucTime,
        uint256 xCount,
        uint256 price,
        address buyer
    ); // 拍卖
    event WithdrawReward(address _from, address _to, uint256 _amount);
    event NewWithdraw(address token, uint256 tokenId);
    event NewRevoke(address token, uint256 tokenId);

    uint256 _type = 1;
    CalcReward calc; // 计算合约
    address public calcAddress;
    uint256 private aucId = 0;
    uint256 sysPersent = 1000;
    uint256 persent = 100;
    uint256 public fee = 100; // 手续费
    uint256 public dividendsFee = 100; // 分红
    uint256 public inviteFee = 50; // 邀请
    uint256 public mur = 200; // 补偿比例
    mapping(uint256 => uint256) public levelFee; // 等级奖励
    address public platformAddress;
    address public dividendsAddress;

    // 白名单
    mapping(address => bool) whileList;

    // 所有的拍卖
    mapping(uint256 => AuctionInfo) public auctionInfo;

    // NFT 基础信息
    mapping(address => mapping(uint256 => NftInfo)) public nftInfoMap;
    mapping(address => mapping(uint256 => bool)) public nftInfoIsExist;

    //NFT 最近一次拍卖信息
    mapping(address => mapping(uint256 => AuctionInfo)) public auctionInfoMap;

    // 我的拍卖
    mapping(address => uint256[]) public myAuctionIds;
    mapping(uint256 => bool) public myAuctionIdverify;
    mapping(uint256 => uint256) public myAuctionIndex;
    // 当前NFT最近一次拍卖历史
    mapping(address => mapping(uint256 => AuctionInfo)) historyAuctionMap;

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
        uint256 ltr;
        uint256 submitPrice;
        uint256 currentPrice;
        uint256 startTime;
        uint256 aucTime;
        uint256 duration;
        uint256 pool;
        uint256 status;
    }

    constructor(
        address _platAddress,
        address _dividendsAddress,
        address _calc
    ) public {
        platformAddress = _platAddress;
        dividendsAddress = _dividendsAddress;
        calc = CalcReward(_calc);
        calcAddress = _calc;
        levelFee[1] = 60;
        levelFee[2] = 40;
    }

    // 白名单验证
    modifier onlyWhile(address _addr) {
        require(whileList[_addr], "caller is not the whileList!");
        _;
    }

    // 添加白名单
    function addToWhile(address _addr) public onlyOwner {
        whileList[_addr] = true;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee; // 补偿比例
    }

    function setMur(uint256 _fee) public onlyOwner {
        mur = _fee;
    }

    function setDividendsFee(uint256 _fee) public onlyOwner {
        dividendsFee = _fee; // 分红
    }

    function setInviteFee(uint256 _fee) public onlyOwner {
        inviteFee = _fee; // 邀请
    }

    function calcReward(address _calc) external onlyOwner {
        calc = CalcReward(_calc);
        calcAddress = _calc;
    }

    function setLevelFee(uint256 _index, uint256 _fee) external onlyOwner {
        levelFee[_index] = _fee;
    }

    function setPlatformAddress(address _address) external onlyOwner {
        platformAddress = _address;
    }

    function setDividendsAddress(address _address) external onlyOwner {
        dividendsAddress = _address;
    }

    /**
     * @dev apply auction
     * @param _token    token
     * @param _tokenId  tokenId
     * @param _price    price
     */
    function applyAuction(
        address _token,
        uint256 _tokenId,
        uint256 _price,
        uint256 _increase,
        uint256 _duration
    ) external {
        IERC1155 nft = IERC1155(_token);
        nft.safeTransferFrom(msg.sender, address(this), _tokenId, 1, "");
        aucId = aucId.add(1);
        uint256 id = aucId;

        if (!nftInfoIsExist[_token][_tokenId]) {
            NftInfo memory nftInfo = NftInfo(_token, _tokenId, 0, 0, 1);
            nftInfoMap[_token][_tokenId] = nftInfo;
            nftInfoIsExist[_token][_tokenId] = true;
        }
        uint256 time = block.timestamp;
        AuctionInfo memory auc = AuctionInfo(
            id,
            _token,
            _tokenId,
            msg.sender,
            msg.sender,
            0,
            _increase,
            _price,
            0,
            time,
            time,
            _duration,
            0,
            1
        );
        if (!myAuctionIdverify[id]) {
            myAuctionIndex[id] = myAuctionIds[msg.sender].length;
            myAuctionIds[msg.sender].push(id);
            myAuctionIdverify[id] = true;
        }

        auctionInfo[id] = auc;
        auctionInfoMap[_token][_tokenId] = auc;

        emit ApplyNewAuction(
            _token,
            _tokenId,
            time,
            _price,
            _increase,
            msg.sender,
            _duration
        );
    }

    function revoke(address _token, uint256 _tokenId) external {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        IERC1155 nft = IERC1155(info.token);
        nft.safeTransferFrom(address(this), info.seller, info.tokenId, 1, "");
        require(info.xCount == 0, "nft Be auctioned ");
        info.status = 2;
        info.buyer = address(0);
        removeOwnerAuc(info.seller, info.aucId);

        NftInfo storage nftInfo = nftInfoMap[_token][_tokenId];
        nftInfo.status = 2;

        auctionInfo[info.aucId] = info;

        emit NewRevoke(msg.sender, _tokenId);
    }

    function auction(address _token, uint256 _tokenId) external payable {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        require(msg.sender != info.buyer, "Can't buy by yourself");
        require(block.timestamp > info.startTime, "Auction Not start");
        require(info.status == 1, "Not on sell status");
        require(info.xCount <= 250, "XCount height is 250");

        uint256 feeAmount;
        uint256 inviteReward;
        uint256 dividendsReward;
        if (info.xCount == 0) {
            //  平台总手续费
            feeAmount = info.submitPrice.mul(fee).div(sysPersent);
            // 分红池
            dividendsReward = feeAmount.mul(dividendsFee).div(sysPersent);
            // 计算推荐奖励 (卖家出)
            inviteReward = getCalcResult(
                info.seller,
                info.submitPrice.mul(inviteFee).div(sysPersent)
            );
            address(uint160(info.seller)).transfer(
                info.submitPrice.sub(feeAmount).sub(inviteReward)
            );
        } else {
            require(
                block.timestamp - info.aucTime < info.duration,
                "Token auction time over"
            );
            uint256 thisPrice = calcuXCountValue(
                info.submitPrice,
                info.ltr.div(10),
                info.xCount
            );

            require(thisPrice == msg.value, "Value error");
            // 涨价
            uint256 upPrice = thisPrice.sub(info.currentPrice);
            // 补偿奖励
            uint256 makeUpPrice = upPrice.mul(mur).div(sysPersent);
            // 回血池
            info.pool = upPrice.sub(makeUpPrice).add(info.pool);
            // 手续费
            feeAmount = makeUpPrice.mul(fee).div(sysPersent);
            // 分红池
            dividendsReward = feeAmount.mul(dividendsFee).div(sysPersent);
            // 计算推荐奖励 (卖家出)
            inviteReward = getCalcResult(
                info.seller,
                makeUpPrice.mul(inviteFee).div(sysPersent)
            );

            address(uint160(info.seller)).transfer(
                makeUpPrice.sub(feeAmount).sub(inviteReward).add(
                    info.currentPrice
                )
            );
        }
        // 分红
        address(uint160(dividendsAddress)).transfer(dividendsReward);
        // 平台
        address(uint160(platformAddress)).transfer(
            feeAmount.sub(dividendsReward)
        );

        info.seller = info.buyer;
        info.currentPrice = msg.value;
        info.buyer = msg.sender;
        info.xCount = info.xCount.add(1);
        info.aucTime = block.timestamp;
        auctionInfo[info.aucId] = info;

        removeOwnerAuc(info.seller, info.aucId);
        // add seller
        myAuctionIndex[info.aucId] = myAuctionIds[msg.sender].length;
        myAuctionIds[msg.sender].push(info.aucId);

        emit NewAuctions(
            _token,
            _tokenId,
            block.timestamp,
            info.xCount,
            msg.value,
            msg.sender
        );
    }

    function withdraw(address _token, uint256 _tokenId) external {
        AuctionInfo storage info = auctionInfoMap[_token][_tokenId];
        require(info.status == 1, "Not picked");
        //check owner
        require(info.buyer == msg.sender, "Not auction owner");
        //check time
        uint256 xCount = info.xCount;
        //over auction time can get
        require(
            xCount > 0 && (block.timestamp - info.aucTime > info.duration),
            "Token auction time not over"
        );

        //every xCount reward
        uint256 feeAmount = info.pool.mul(fee).div(sysPersent);
        uint256 dividendsReward = feeAmount.mul(dividendsFee).div(sysPersent);
        // 分红
        address(uint160(dividendsAddress)).transfer(dividendsReward);
        // 平台
        address(uint160(platformAddress)).transfer(
            feeAmount.sub(dividendsReward)
        );
        // 计算推荐奖励 (卖家出)
        uint256 inviteReward = getCalcResult(
            info.buyer,
            info.pool.mul(inviteFee).div(sysPersent)
        );

        address(uint160(info.buyer)).transfer(
            info.pool.sub(feeAmount).sub(inviteReward)
        );

        info.status = 3;

        NftInfo storage nftInfo = nftInfoMap[_token][_tokenId];
        nftInfo.status = 3;
        nftInfo.lastDealTime = block.timestamp;
        nftInfo.lastDealPrice = info.currentPrice;

        historyAuctionMap[_token][_tokenId] = info;
        auctionInfo[info.aucId] = info;
        removeOwnerAuc(info.buyer, info.aucId);
        //send token
        IERC1155 nft = IERC1155(info.token);
        nft.safeTransferFrom(address(this), msg.sender, info.tokenId, 1, "");
        emit NewWithDraw(_token, _tokenId);
    }

    function calcuPrice(uint256 _price, uint256 _rate)
        public
        pure
        returns (uint256 value)
    {
        uint256 price = _rate.mul(_price).div(100).add(_price);
        if (price >= 1e18) {
            price = price.div(1e10).mul(1e10);
        } else {
            price = price;
        }
        return price;
    }

    function removeOwnerAuc(address _owner, uint256 _index) public {
        uint256[] storage ids = myAuctionIds[_owner];
        for (uint256 i = myAuctionIndex[_index]; i < ids.length - 1; i++) {
            ids[i] = ids[i + 1];
        }
        delete ids[myAuctionIndex[_index]];
        ids.length--;
    }

    function withdrawReward(address _address, uint256 _amount)
        external
        onlyWhile(msg.sender)
    {
        address(uint160(_address)).transfer(_amount);
        emit WithdrawReward(address(this), _address, _amount);
    }

    function withdrawNft(
        address token,
        uint256 tokenId,
        address _from,
        address _to
    ) external onlyOwner {
        IERC1155 nft = IERC1155(token);
        nft.safeTransferFrom(_from, _to, tokenId, 1, "");
    }

    function getTokenAuctionPrice(address _token, uint256 _tokenId)
        public
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

    function getCalcResult(address _address, uint256 _amount)
        public
        returns (uint256)
    {
        // 计算推荐奖励
        return calc.calcAucReward(_address, _amount, levelFee[1], levelFee[2]);
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
            uint256 increase, // 涨幅
            uint256[2] memory price,
            uint256 startTime,
            uint256 aucTime,
            uint256 duration,
            uint256 status
        )
    {
        AuctionInfo memory info = auctionInfo[_id];
        uint256[2] memory r_price = [info.submitPrice, info.currentPrice];
        return (
            info.aucId,
            info.token,
            info.tokenId,
            info.seller,
            info.buyer,
            info.xCount,
            info.ltr,
            r_price,
            info.startTime,
            info.aucTime,
            info.duration,
            info.status
        );
    }

    function getAuctionPrice(address _token, uint256 _tokenId)
        external
        view
        returns (uint256 r_price, uint256 r_time)
    {
        NftInfo storage info = nftInfoMap[_token][_tokenId];
        return (info.lastDealPrice, info.lastDealTime);
    }

    function calcuXCountValue(
        uint256 _price,
        uint256 _rate,
        uint256 _xCount
    ) public pure returns (uint256 value) {
        if (_xCount == 0) {
            return _price;
        }
        uint256 size = _xCount / 45;
        uint256 y = _xCount % 45;
        if (y > 0) {
            size++;
        }
        uint256 p = 1;
        for (uint256 i = 0; i < size; i++) {
            uint256 _xc = i.add(1).mul(45); //45-90-135-180
            uint256 _p = 0;
            if (_xCount > _xc) {
                //45
                _p = getXCountPrice(_rate, 45); //0-45-90
            } else {
                _p = getXCountPrice(_rate, _xCount.sub(i.mul(45))); //0-45-90
            }
            if (i == 0) {
                p = p.mul(_p);
            } else {
                p = p.mul(_p).div(1e26);
            }
        }
        uint256 result = _price.mul(p).div(1e26);
        if (result >= 1e18) {
            result = result.div(1e10).mul(1e10);
        } else {
            result = result;
        }
        return result;
    }

    function getXCountPrice(uint256 _rate, uint256 _range)
        public
        pure
        returns (uint256 _p)
    {
        uint256 p1 = (_rate.add(10))**_range;
        uint256 p3 = 10**_range;
        uint256 p5 = p1.mul(1e26).div(p3);
        return p5;
    }
}
