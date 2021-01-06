pragma solidity >=0.5.0 <0.7.0;
import "../lib/SafeMath.sol";
import "../lib/Ownable.sol";

contract BaseInfo is Ownable {
    using SafeMath for uint256;

    struct NftInfo {
        address token;
        uint256 tokenId;
        uint256 lastDealPrice;
        uint256 lastDealTime;
        uint256 status; // 1 auction,2 cancel,3 over
    }

    uint256 public feeRate; // 平台手续费
    uint256 public platformFee; // 平台
    uint256 public dividendsFee; // 分红
    uint256 public inviteBuyerFee = 0; // 买方推荐奖励
    uint256 public inviteSellerFee = 0; // 卖方推荐奖励
    mapping(address => uint256) public rewards;
    mapping(uint256 => uint256) public levelFee; // 推荐等级奖励

    mapping(address => mapping(uint256 => NftInfo)) public nftInfoMap;
    mapping(address => mapping(uint256 => bool)) public nftInfoIsExist;

    constructor() public {}
}
