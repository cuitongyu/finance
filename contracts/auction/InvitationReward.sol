pragma solidity >=0.5.0 <0.7.0;

import "../lib/SafeMath.sol";
import "../lib/Ownable.sol";

interface InviteApollo2 {
    function getUserSimpleInfo(address _address)
        external
        view
        returns (address referrer);

    function getFirstAddress() external view returns (address firstAddress);
}

interface AuctionInterface {
    function withdrawReward(address _address, uint256 _amount) external;
}

contract InvitationReward is Ownable {
    using SafeMath for uint256;

    // 百分比精度
    uint256 percent = 100;
    mapping(uint256 => uint256) public levelFee; // 买方推荐奖励
    mapping(address => mapping(address => uint256)) private _balances;

    // 白名单
    address[] public whileLists;

    // 白名单
    mapping(address => bool) whileList;
    address public inviteAddress;
    InviteApollo2 invite;

    event Withdraw(address _from, address _to);

    constructor(address _inviteAddress) public {
        inviteAddress = _inviteAddress;
        invite = InviteApollo2(_inviteAddress);
        levelFee[1] = 60;
        levelFee[2] = 40;
    }

    // 白名单验证
    modifier onlyWhile(address _addr) {
        require(whileList[_addr], "only whileList!");
        _;
    }

    // 添加白名单
    function addToWhile(address _addr) public onlyOwner {
        whileList[_addr] = true;
        whileLists.push(_addr);
    }

    function delWhileList() external {
        delete whileLists;
        whileLists.length = 0;
    }

    function setlevelFee(uint256 _index, uint256 _fee) external onlyOwner {
        levelFee[_index] = _fee;
    }

    function balanceOf(address account) external view returns (uint256) {
        uint256 amount;
        for (uint256 i = 0; i < whileLists.length; i++) {
            amount = _balances[whileLists[i]][account].add(amount);
        }
        return amount;
    }

    function withdraw(address _address) external {
        for (uint256 i = 0; i < whileLists.length; i++) {
            AuctionInterface auc = AuctionInterface(whileLists[i]);
            if (_balances[whileLists[i]][_address] != 0) {
                uint256 amount = _balances[whileLists[i]][_address];
                _balances[whileLists[i]][_address] = 0;
                auc.withdrawReward(_address, amount);
            }
        }
        emit Withdraw(address(this), _address);
    }

    function calcAucReward(address _address, uint256 _rewart)
        external
        onlyWhile(msg.sender)
        returns (uint256)
    {
        address firstAddress = invite.getFirstAddress();
        address olAddress = invite.getUserSimpleInfo(_address);
        if (olAddress == firstAddress || olAddress == address(0)) {
            return uint256(0);
        }

        uint256 olReward = _rewart.mul(levelFee[1]).div(percent);
        _balances[msg.sender][olAddress] = _balances[msg.sender][olAddress].add(
            olReward
        );

        address tlAddress = invite.getUserSimpleInfo(olAddress);
        if (tlAddress == firstAddress) {
            return olReward;
        }

        uint256 tlReward = _rewart.mul(levelFee[2]).div(percent);
        _balances[msg.sender][tlAddress] = _balances[msg.sender][tlAddress].add(
            tlReward
        );

        return olReward.add(tlReward);
    }
}
