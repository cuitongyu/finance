pragma solidity >=0.5.0 <0.7.0;

import "../lib/Ownable.sol";
import "../lib/SafeMath.sol";

interface AucInterface {
    function balanceOf(address _address) external view returns (uint256);

    function withdraw(address _address) external;
}

/**
    推荐返佣（代币交易）
*/
interface TRecommendRebate {
    // 查询奖励
    function checkEarning(address _spenderAddress)
        external
        view
        returns (uint256);

    // 领取奖励
    function takeEarning(address payable _receiverAddress) external;

    // 领取代币
    function takeToken(address _tokenAddress, address payable _spenderAddress)
        external;

    // 查询代币奖励
    function checkTokenEarning(address _tokenAddress, address _spenderAddress)
        external
        returns (uint256);
}

/**
    推荐返佣（代币交易）
*/
interface NRecommendRebate {
    // 领取奖励
    function takeEarning(address payable _receiverAddress) external;

    // 查询奖励
    function checkEarning(address _receiverAddress)
        external
        view
        returns (uint256);
}

interface Donate {
    //查询佣金
    function balanceOf(address _owner) external view returns (uint256);

    //提取佣金
    function sendBrokerage(address payable referrer) external;
}

contract Summary is Ownable {
    using SafeMath for uint256;

    AucInterface auc;
    TRecommendRebate tokenRebate;
    NRecommendRebate nftRebate;
    Donate donate;

    constructor(
        address _aucAddress,
        address _tokenAddr,
        address _nftAddr,
        address _donateAddr
    ) public {
        auc = AucInterface(_aucAddress);
        tokenRebate = TRecommendRebate(_tokenAddr);
        nftRebate = NRecommendRebate(_nftAddr);
        donate = Donate(_donateAddr);
    }

    // 盈利
    function balanceOf(address _address) external view returns (uint256) {
        uint256 aucBal = auc.balanceOf(_address);
        uint256 _tokenBalance = tokenRebate.checkEarning(_address);
        uint256 _nftBalance = nftRebate.checkEarning(_address);
        uint256 _donateBalance = donate.balanceOf(_address);
        return aucBal.add(_tokenBalance).add(_nftBalance).add(_donateBalance);
    }

    // 取出
    function takeEarning() public {
        auc.withdraw(msg.sender);
        tokenRebate.takeEarning(msg.sender);
        nftRebate.takeEarning(msg.sender);
        donate.sendBrokerage(msg.sender);
    }

    // 查询代币盈利
    function balanceOfToken(address _tokenAddress) public returns (uint256) {
        return tokenRebate.checkTokenEarning(_tokenAddress, msg.sender);
    }

    // 取出代币
    function takeTokenEarning(address _tokenAddress) public {
        tokenRebate.takeToken(_tokenAddress, msg.sender);
    }

    function setAucInterface(address _address) public onlyOwner {
        auc = AucInterface(_address);
    }

    function setTRecommendRebate(address _address) public onlyOwner {
        tokenRebate = TRecommendRebate(_address);
    }

    function setNRecommendRebate(address _address) public onlyOwner {
        nftRebate = NRecommendRebate(_address);
    }

    function setDonate(address _address) public onlyOwner {
        donate = Donate(_address);
    }
}
