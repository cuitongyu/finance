pragma solidity >=0.5.0 <0.7.0;

import "../lib/SafeMath.sol";
import "../lib/Ownable.sol";

contract InviteApollo2 {
    event Register(address owner, uint256 uid);

    using SafeMath for uint256;
    mapping(address => User) public userMap;
    mapping(uint256 => address) public userIdMap;
    address owner;
    address first;

    User[] public users;

    struct User {
        address owner;
        uint256 id;
        address referrer;
        uint256 referrerId;
        uint256 createTime;
    }

    function getUserSimpleInfo(address _address)
        external
        view
        returns (address referrer)
    {
        User memory user = userMap[_address];
        return (user.referrer);
    }

    function getFirstAddress() external view returns (address firstAddress) {
        return userIdMap[1];
    }

    constructor(address _owner, address _first) public {
        owner = _owner;
        first = _first;
        User storage firstUser = userMap[_first];
        firstUser.id = 1;
        firstUser.referrer = address(0);
        firstUser.owner = _first;
        firstUser.createTime = now;
        //add user
        users.push(firstUser);
        userIdMap[1] = _first;
    }

    modifier checkOwner() {
        require(msg.sender == owner);
        _;
    }

    function getUserLength() public view returns (uint256 _userLength) {
        return users.length;
    }

    function register(uint256 _referrerId) public {
        address _referrer = userIdMap[_referrerId];
        require(isUserExists(_referrer), "Referrer not exist");
        uint256 uid = users.length.add(1);
        User storage user = userMap[msg.sender];
        require(user.id == 0, "Already register");
        user.id = uid;
        user.referrer = _referrer;
        user.owner = msg.sender;
        user.createTime = now;
        user.referrerId = _referrerId;
        //add user
        users.push(user);
        userIdMap[uid] = msg.sender;
        emit Register(msg.sender, uid);
    }

    function isUserExists(address user) public view returns (bool) {
        return (userMap[user].id != 0);
    }
}
