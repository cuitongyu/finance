pragma solidity >=0.5.0 <0.7.0;

import "../lib/SafeMath.sol";
import "../lib/IERC721.sol";

contract NftToken is IERC721 {
    function getTokenInfo(uint256 _tokenId)
        public
        view
        returns (
            string memory _name,
            uint256 _url,
            uint256 _level
        );

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract ERC20 {
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function decimals() external view returns (uint256);
}

contract NewThingAuction {
    using SafeMath for uint256;

    event XCountBuy(address _owner, uint256 _tokenId, uint256 _xCount);
    event BuyPlatform(address _owner);
    event WinnerWithDraw(address _owner, uint256 _tokenId, uint256 reward);
    event AuctionPok(address _owner, uint256 _tokenId);
    event CancelAuction(address _owner, uint256 _tokenId);
    event VerifyAuction(address _subAddress, uint256 _tokenId, uint256 _price);

    mapping(address => NftToken) aritistMap;
    address[] aritistTokenMap;

    //owner tokenIds
    mapping(address => mapping(address => uint256[])) public platFormTokensIds;
    mapping(address => bool) public platFormSellers;

    //todo
    uint256 public overTime = 12 hours;
    uint256 persent = 10;

    //todo not all public
    mapping(address => mapping(uint256 => PokAuction)) public tradingMap;
    uint256 public mFeeRate;
    //auctions
    mapping(address => uint256[]) public auctionTokens;
    mapping(address => mapping(uint256 => bool)) auctionTokensMap;
    //history auctions
    mapping(address => uint256[]) public historyTokens;
    mapping(address => mapping(uint256 => bool)) historyTokensMap;
    mapping(address => mapping(uint256 => PokAuctionInfo)) historyAuctions;
    //nft token info
    mapping(address => NftInfo) public nftInfoMap;
    mapping(address => bool) nftExistMap;

    mapping(address => bool) public xCountBuyerMap;

    address priceOwner;
    address initOwner;
    mapping(address => bool) initToken;
    address roomAddress;

    struct NftInfo {
        address token;
        string name;
        string symbol;
        uint256 levelRange;
        address token20;
        address platFormAddress;
        uint256 submitPrice;
        uint256 ltr; //价格涨幅
        uint256 mur; // 血池与补偿比例
        uint256 br; // (回血池奖励比例)
        mapping(address => bool) whiteList;
    }

    struct PokAuction {
        address token20;
        address platFormAddress;
        address seller;
        bool isValid;
        address tempBuyer;
        address lastBuyer;
        uint256 price;
        uint256 xCount;
        uint256 startedAt;
        uint256 lastAt;
        uint256[3] lmb;
        // uint256 ltr;
        // uint256 mur;
        // uint256 br;
        uint256 tokenPool;
        // 0 init,1 auction,2 cancel,3 over, 10 unStart
        uint256 status;
    }

    struct PokAuctionInfo {
        address seller;
        address buyer;
        uint256 startedAt;
        uint256 endTime;
        uint256 ltr;
        uint256 xCount;
        uint256 tokenId;
        uint256 price;
        uint256 currentPrice;
    }

    constructor(
        address _initOwner,
        address _priceOwner,
        address _roomAddress
    ) public {
        priceOwner = _priceOwner;
        initOwner = _initOwner;
        roomAddress = _roomAddress;
    }

    modifier checkPriceOwner() {
        require(priceOwner == msg.sender, "Not price Owner");
        _;
    }

    modifier checkInitOwner() {
        require(initOwner == msg.sender, "Not init Owner");
        _;
    }

    /**
     * @dev get decimals
     * @param _token token
     * @return decimals
     */
    function getTokenDecimal(address _token)
        public
        view
        returns (uint256 _decimals)
    {
        ERC20 erc20 = ERC20(_token);
        return erc20.decimals();
    }

    function addNftToken(
        address _token,
        uint256 _range,
        address _token20,
        address _platFormAddress,
        uint256 _submitPrice,
        uint256 _ltr,
        uint256 _mur,
        uint256 _br
    ) public checkPriceOwner() {
        aritistMap[_token] = NftToken(_token);
        nftInfoMap[_token] = NftInfo(
            _token,
            aritistMap[_token].name(),
            aritistMap[_token].symbol(),
            _range,
            _token20,
            _platFormAddress,
            _submitPrice,
            _ltr,
            _mur,
            _br
        );
        initToken[_token] = true;
        if (!nftExistMap[_token]) {
            //add token list
            aritistTokenMap.push(_token);
            nftExistMap[_token] = true;
        }
        //approve erc20 token max value
        safeApprove(_token20, address(this), 2**256 - 1);
    }

    function setOverTime(uint256 _time) public checkPriceOwner() {
        overTime = _time;
    }

    function setMFeeRate(uint256 _mFeeRate) public checkPriceOwner() {
        mFeeRate = _mFeeRate;
    }

    function addXCountBuyer(address _buyer) public checkPriceOwner {
        xCountBuyerMap[_buyer] = true;
    }

    function removeXCountBuyer(address _buyer) public checkPriceOwner {
        xCountBuyerMap[_buyer] = false;
    }

    function currentAuctionTokens(address _token)
        public
        view
        returns (uint256[] memory _tokenIds)
    {
        return auctionTokens[_token];
    }

    function historyAuctionTokens(address _token)
        public
        view
        returns (uint256[] memory _tokenIds)
    {
        return historyTokens[_token];
    }

    function getCurrentTime() public view returns (uint256 _time) {
        return now;
    }

    function setRoomAddress(address _roomAddress) public checkPriceOwner {
        roomAddress = _roomAddress;
    }

    /**
     * @dev get nfts
     */
    function getNftInfos() public view returns (address[] memory _addresses) {
        return aritistTokenMap;
    }

    function currentOwnerAuctionTokens(address _token, address _address)
        public
        view
        returns (uint256[] memory _tokenIds)
    {
        return platFormTokensIds[_token][_address];
    }

    function getNftToken(address _token, uint256 _tokenId)
        public
        view
        returns (
            string memory name,
            string memory symbol,
            string memory tokenURI
        )
    {
        NftToken temp = NftToken(_token);
        return (temp.name(), temp.symbol(), temp.tokenURI(_tokenId));
    }

    function tradingMapInfo(address _token, uint256 _tokenId)
        public
        view
        returns (
            address token20,
            address seller,
            address tempBuyer,
            uint256 price,
            uint256 xCount,
            uint256 startedAt,
            uint256 lastAt,
            uint256 ltr,
            uint256 mur,
            uint256 br,
            uint256 status
        )
    {
        PokAuction memory info = tradingMap[_token][_tokenId];
        return (
            info.token20,
            info.seller,
            info.tempBuyer,
            info.price,
            info.xCount,
            info.startedAt,
            info.lastAt,
            info.lmb[0],
            info.lmb[1],
            info.lmb[2],
            info.status
        );
    }

    function addWiteList(address _token, address[] memory _addresses)
        public
        checkInitOwner
    {
        NftInfo storage nftInfo = nftInfoMap[_token];
        for (uint256 i = 0; i < _addresses.length; i++) {
            nftInfo.whiteList[_addresses[i]] = true;
        }
    }

    function checkWhiteList(address _token, address _address)
        public
        view
        returns (bool _isExist)
    {
        NftInfo storage nftInfo = nftInfoMap[_token];
        return nftInfo.whiteList[_address];
    }

    function removeWhiteList(address _token, address[] memory _addresses)
        public
        checkInitOwner
    {
        NftInfo storage nftInfo = nftInfoMap[_token];
        for (uint256 i = 0; i < _addresses.length; i++) {
            nftInfo.whiteList[_addresses[i]] = false;
        }
    }

    function getPokTokenOwner(address _token, uint256 _tokenId)
        public
        view
        returns (address _address)
    {
        return aritistMap[_token].ownerOf(_tokenId);
    }

    /**
     * @dev Owner set init
     * @param _tokenId id
     * @param _startAt srartTime
     */
    function verifyAuc(
        address _token,
        uint256 _tokenId,
        uint256 _startAt
    ) public checkPriceOwner {
        PokAuction storage pokAuction = tradingMap[_token][_tokenId];
        pokAuction.startedAt = _startAt;
        //init
        pokAuction.status = 0;
        emit VerifyAuction(pokAuction.seller, _tokenId, pokAuction.price);
    }

    function userGetTokenApproved(address _token)
        public
        view
        returns (uint256 _approved)
    {
        ERC20 erc20 = ERC20(_token);
        return erc20.allowance(msg.sender, address(this));
    }

    /**
     * @dev user approve
     * @param _token20 erc20 token
     */
    function userApproveToken(address _token20) public {
        safeApprove(_token20, address(this), 2**256 - 1);
    }

    /**
     * @dev put auction
     * @param _token    token
     * @param _tokenId  tokenId
     * @param _price    price
     */
    function auctionToken(
        address _token,
        uint256 _tokenId,
        uint256 _price
    ) public payable {
        NftInfo storage nftInfo = nftInfoMap[_token];
        //whiteList
        require(nftInfo.whiteList[msg.sender], "Not in white list");
        // pay for platform
        require(msg.value == nftInfo.submitPrice, "Submit price wrong");
        require(
            getPokTokenOwner(_token, _tokenId) == msg.sender,
            "Not tokenId owner"
        );
        require(!tradingMap[_token][_tokenId].isValid, "Token on sell");
        //check price
        require(
            _price >= 0 && _price <= nftInfo.levelRange,
            "seller price range wrong"
        );
        uint256[] storage tokenIds = platFormTokensIds[_token][msg.sender];
        bool isRepeat = false;
        //add token
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == _tokenId) {
                isRepeat = true;
                break;
            }
        }
        //add seller pok
        if (!isRepeat) {
            tokenIds.push(_tokenId);
        }

        //check Token is exist
        if (!auctionTokensMap[_token][_tokenId]) {
            auctionTokens[_token].push(_tokenId);
            auctionTokensMap[_token][_tokenId] = true;
        }

        //add auction info, temp buyer himself

        uint256[3] memory lmb = [nftInfo.ltr, nftInfo.mur, nftInfo.br];
        PokAuction memory pok = PokAuction(
            nftInfo.token20,
            nftInfo.platFormAddress,
            msg.sender,
            true,
            msg.sender,
            msg.sender,
            _price,
            0,
            0,
            now,
            lmb,
            0,
            10
        );
        tradingMap[_token][_tokenId] = pok;
        //deposit
        aritistMap[_token].transferFrom(msg.sender, address(this), _tokenId);
        if (msg.value != 0) {
            //transfer platform eth
            address(uint160(roomAddress)).transfer(msg.value);
        }
        emit AuctionPok(msg.sender, _tokenId);
    }

    function cancelAuctionToken(address _token, uint256 _tokenId)
        public
        payable
    {
        require(msg.value == 0, "Do not need fee");
        uint256[] storage pokIds = platFormTokensIds[_token][msg.sender];
        require(pokIds.length > 0, "Not a seller");
        //find seller tokenId
        bool isRight;
        for (uint256 i = 0; i < pokIds.length; i++) {
            if (pokIds[i] == _tokenId) {
                isRight = true;
                break;
            }
        }
        //check owner
        require(isRight, "Not owner seller");
        //change status to primary
        PokAuction storage pokAuction = tradingMap[_token][_tokenId];
        require(pokAuction.status == 10, "Not on sell or already auction");
        pokAuction.status = 2;
        pokAuction.tempBuyer = address(0);
        pokAuction.seller = address(0);
        pokAuction.lastBuyer = address(0);
        pokAuction.isValid = false;
        //set 0
        pokAuction.tokenPool = 0;
        aritistMap[_token].transferFrom(address(this), msg.sender, _tokenId);
        emit CancelAuction(msg.sender, _tokenId);
    }

    /**
     * @dev cancel auction
     * @param _token    token
     * @param _tokenId  tokenId
     */
    function backAuctionToken(address _token, uint256 _tokenId)
        public
        payable
        checkPriceOwner
    {
        require(msg.value == 0, "Do not need fee");
        PokAuction storage pokAuction = tradingMap[_token][_tokenId];
        require(
            pokAuction.status == 0 || pokAuction.status == 10,
            "Not on sell or already auction"
        );
        //transfer back
        aritistMap[_token].transferFrom(
            address(this),
            pokAuction.seller,
            _tokenId
        );
        //change status to primary
        pokAuction.status = 2;
        pokAuction.tempBuyer = address(0);
        pokAuction.seller = address(0);
        pokAuction.lastBuyer = address(0);
        pokAuction.isValid = false;
        //set 0
        pokAuction.tokenPool = 0;
        emit CancelAuction(msg.sender, _tokenId);
    }

    function xCountBuySelf(
        address _token,
        uint256 _tokenId,
        uint256 _amount
    ) public payable {
        address[2] memory addresses = [_token, msg.sender];
        xCountBuy(addresses, [_tokenId, _amount, 0]);
    }

    function xCountBuyPool(
        address[2] memory addresses,
        uint256 _tokenId,
        uint256[2] memory _amount
    )
        public
        payable
        returns (
            bool _res,
            uint256 _earn,
            address lBuyer
        )
    {
        require(xCountBuyerMap[msg.sender], "Not approved");
        (uint256 _e, address _lastBuyer) = xCountBuy(
            addresses,
            [_tokenId, _amount[0], _amount[1]]
        );
        return (true, _e, _lastBuyer);
    }

    /**
     * @dev x count buy
     * @param _addresses addresses token address, sender address
     * @param _tae tokenId,amount,earnRate
     */

    function xCountBuy(address[2] memory _addresses, uint256[3] memory _tae)
        internal
        returns (uint256 _earn, address _lastBuyer)
    {
        //avoid stack over flow
        address token = _addresses[0];
        address addressSender = _addresses[1];
        uint256 _tid = _tae[0];
        uint256 _earnRate = _tae[2];
        PokAuction storage pokAuction = tradingMap[token][_tid];
        require(pokAuction.startedAt != 0, "Auction Not start");
        //is exist
        require(pokAuction.isValid, "Not on sell");
        require(pokAuction.status <= 1, "Not on sell status");
        //not repeat
        require(
            pokAuction.tempBuyer != addressSender,
            "Owner can not auction current pok"
        );
        uint256 realPrice;
        uint256 lastPrice;
        //stack to deep
        // uint256 xCount = pokAuction.xCount;
        // uint256 lRate = pokAuction.lmb[0];
        // uint256 mRate = pokAuction.lmb[1];
        require(pokAuction.xCount <= 250, "XCount height is 250");
        if (pokAuction.xCount == 0) {
            //normal
            realPrice = pokAuction.price;
            lastPrice = 0;
        } else {
            //devil check time
            require(
                (now - pokAuction.lastAt < overTime),
                "Token auction time over"
            );
            //buy price (price + rate)^xCount
            realPrice = calcuXCountValue(
                pokAuction.price,
                pokAuction.lmb[0],
                pokAuction.xCount
            );
            //lastPrice
            lastPrice = calcuXCountValue(
                pokAuction.price,
                pokAuction.lmb[0],
                pokAuction.xCount.sub(1)
            );
        }
        //check value
        require(realPrice == _tae[1], "Value error");
        //change tokenId owner
        pokAuction.lastBuyer = pokAuction.tempBuyer;
        pokAuction.tempBuyer = addressSender;
        //auction stauts
        pokAuction.status = 1;
        //change trade
        pokAuction.lastAt = now;
        //pay make up  price
        uint256 makeUpPrice = realPrice.sub(lastPrice);
        //make up ( subPrice * makeUpRate ) + baseBuy   10% to platform   20%
        uint256 makeUpReward = makeUpPrice.mul(pokAuction.lmb[1]).div(persent);
        //make up last buyer , auction earn rate to pool.
        uint256 mureward = makeUpReward.mul((persent.sub(mFeeRate))).div(
            persent
        );
        if (pokAuction.xCount > 0) {
            // auction rate if rate ==0 then last buyer will get all the reward.  use number -,because of stark too deep
            safeTransferFrom(
                pokAuction.token20,
                addressSender,
                pokAuction.lastBuyer,
                mureward.mul((10 - _earnRate)).div(10).add(lastPrice)
            );
            // reward pool else  earn rate != 0,then pool will get the persent reward.
            if (_earnRate != 0) {
                safeTransferFrom(
                    pokAuction.token20,
                    addressSender,
                    msg.sender,
                    mureward.mul(_earnRate).div(persent)
                );
            }

            //platform get mFeeRate
            safeTransferFrom(
                pokAuction.token20,
                addressSender,
                pokAuction.platFormAddress,
                makeUpReward.mul(mFeeRate).div(persent)
            );
            //add platform
            uint256 platformPool = makeUpPrice
                .mul(persent.sub(pokAuction.lmb[1]))
                .div(persent);
            //token pool
            safeTransferFrom(
                pokAuction.token20,
                addressSender,
                address(this),
                platformPool
            );
            //rest to pool
            pokAuction.tokenPool = pokAuction.tokenPool.add(platformPool);
            pokAuction.xCount = pokAuction.xCount.add(1);
        } else {
            //pay to owner
            pokAuction.xCount = 1;
            safeTransferFrom(
                pokAuction.token20,
                addressSender,
                pokAuction.seller,
                pokAuction.price
            );
        }
        //remove lastBuyer
        uint256[] storage pokIds = platFormTokensIds[token][pokAuction
            .lastBuyer];
        uint256 ri;
        for (uint256 i = 0; i < pokIds.length; i++) {
            if (pokIds[i] == _tid) {
                ri = i;
                break;
            }
        }
        removeIndex(token, ri, pokAuction.lastBuyer);
        //add seller
        uint256[] storage pokBuyerIds = platFormTokensIds[token][pokAuction
            .tempBuyer];
        pokBuyerIds.push(_tid);
        //next version will remove owner auction, now show all status, but not on sell
        emit XCountBuy(addressSender, _tid, pokAuction.xCount);
        //pool reward price, lastBuyer
        return (mureward.mul(_earnRate).div(persent), pokAuction.lastBuyer);
    }

    function withdrawSelf(address _token, uint256 _tokenId) public {
        withDraw([_token, msg.sender], [_tokenId, 0]);
    }

    function withdrawPool(address[2] memory _ts, uint256[2] memory _te)
        public
        returns (bool _res, uint256 _reward)
    {
        require(xCountBuyerMap[msg.sender], "Not approved");
        return (true, withDraw(_ts, _te));
    }

    function withDraw(address[2] memory _ts, uint256[2] memory _te)
        public
        returns (uint256 _reward)
    {
        //check owner
        address _token = _ts[0];
        address _sender = _ts[1];
        uint256 _tokenId = _te[0];
        uint256 _earnRate = _te[1];
        PokAuction storage pokAuction = tradingMap[_token][_tokenId];
        require(pokAuction.status == 1, "Not picked");
        //check owner
        require(pokAuction.tempBuyer == _sender, "Not auction owner");
        //check time
        uint256 lastAt = pokAuction.lastAt;
        uint256 xCount = pokAuction.xCount;
        //over auction time can get
        require(
            xCount > 0 && (now - lastAt > overTime),
            "Token auction time not over"
        );
        //br
        uint256 bRate = pokAuction.lmb[2];
        //every xCount reward
        uint256 reward = pokAuction.tokenPool;
        //90% to owner
        uint256 earnReward = reward.mul(persent.sub(bRate)).div(persent);
        //send to owner ,1 - earnRate to owner
        safeTransferFrom(
            pokAuction.token20,
            address(this),
            _sender,
            earnReward.mul(persent.sub(_earnRate)).div(persent)
        );
        //sub reward
        if (_earnRate != 0) {
            //if earn rate !=0 earn reward to referrers pool
            safeTransferFrom(
                pokAuction.token20,
                address(this),
                msg.sender,
                earnReward.mul(_earnRate).div(persent)
            );
        }

        //10% send platform
        address plat = pokAuction.platFormAddress;
        safeTransferFrom(
            pokAuction.token20,
            address(this),
            plat,
            reward.mul(bRate).div(persent)
        );
        //add history
        pokAuction.status = 3;
        pokAuction.lastAt = now;
        pokAuction.isValid = false;
        uint256 lRate = pokAuction.lmb[0];
        //set token current price
        //buy price (price + rate)^xCount
        uint256 realPrice = calcuXCountValue(
            pokAuction.price,
            lRate,
            xCount.sub(1)
        );
        //add history
        //check Token is exist
        if (!historyTokensMap[_token][_tokenId]) {
            historyTokens[_token].push(_tokenId);
            historyTokensMap[_token][_tokenId] = true;
        }
        PokAuctionInfo storage info = historyAuctions[_token][_tokenId];
        info.currentPrice = realPrice;
        info.endTime = now;
        info.tokenId = _tokenId;
        info.ltr = lRate;
        info.startedAt = pokAuction.startedAt;
        info.seller = pokAuction.seller;
        info.buyer = pokAuction.tempBuyer;
        info.xCount = xCount;
        info.price = pokAuction.price;
        //send token
        aritistMap[_token].transferFrom(address(this), _sender, _tokenId);
        emit WinnerWithDraw(_sender, _tokenId, reward);
        return earnReward.mul(_earnRate).div(persent);
    }

    function getTokenAuctionPrice(address _token, uint256 _tokenId)
        public
        view
        returns (uint256 _price)
    {
        PokAuctionInfo storage info = historyAuctions[_token][_tokenId];
        return info.currentPrice;
    }

    function getTokenAuction(address _token, uint256 _tokenId)
        public
        view
        returns (address tempBuyer)
    {
        PokAuction storage info = tradingMap[_token][_tokenId];
        return info.tempBuyer;
    }

    /** @dev token auction price
     * @param _tokenId tokenId
     * @param _price price
     */
    function setTokenAuctionPrice(
        address _token,
        uint256 _tokenId,
        uint256 _price,
        address _seller,
        uint256 _startedAt,
        uint256 _endTime,
        uint256 _ltr,
        uint256 _xCount,
        uint256 _currentPrice
    ) public checkPriceOwner {
        if (!historyTokensMap[_token][_tokenId]) {
            historyTokens[_token].push(_tokenId);
            historyTokensMap[_token][_tokenId] = true;
        }
        PokAuctionInfo storage info = historyAuctions[_token][_tokenId];
        info.currentPrice = _currentPrice;
        info.endTime = _endTime;
        info.ltr = _ltr;
        info.tokenId = _tokenId;
        info.startedAt = _startedAt;
        info.seller = _seller;
        info.xCount = _xCount;
        info.price = _price;
    }

    function getNfcToken(address _token, uint256 _tokenId)
        public
        checkPriceOwner
    {
        PokAuction storage pokAuction = tradingMap[_token][_tokenId];
        require(pokAuction.isValid, "Not on sell");
        aritistMap[_token].transferFrom(address(this), msg.sender, _tokenId);
    }

    function getPoolTokens(address _token, uint256 _amount)
        public
        checkPriceOwner
    {
        safeTransferFrom(_token, address(this), msg.sender, _amount);
    }

    function removeIndex(
        address _token,
        uint256 _index,
        address _owner
    ) private {
        uint256[] storage pokIds = platFormTokensIds[_token][_owner];
        for (uint256 i = _index; i < pokIds.length - 1; i++) {
            pokIds[i] = pokIds[i + 1];
        }
        delete pokIds[pokIds.length - 1];
        pokIds.length--;
    }

    function getPoolRewardOwner(address _token, uint256 _amount)
        public
        checkPriceOwner
    {
        safeTransferFrom(_token, address(this), msg.sender, _amount);
    }

    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "APPROVE_FAILED"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        //transfer ERC20 Token
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FROM_FAILED"
        );
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
