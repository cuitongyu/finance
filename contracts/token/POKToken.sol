pragma solidity 0.5.16;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract Token {
    using SafeMath for uint256;

    /// @return total amount of tokens
    function totalSupply() external view returns (uint256 supply) {}

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner)
        external
        view
        returns (uint256 balance)
    {}

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value)
        external
        returns (bool success)
    {}

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success) {}

    /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of wei to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value)
        external
        returns (bool success)
    {}

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 remaining)
    {}

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
}

// 普通通证
contract RegularToken is Token {
    function transfer(address _to, uint256 _value) external returns (bool) {
        //Default assumes totalSupply can't be over max (2^256 - 1).
        if (
            balances[msg.sender] >= _value &&
            balances[_to] + _value >= balances[_to]
        ) {
            balances[msg.sender] = balances[msg.sender].sub(_value);
            balances[_to] = balances[_to].add(_value);
            emit Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool) {
        if (
            balances[_from] >= _value &&
            allowed[_from][msg.sender] >= _value &&
            balances[_to] + _value >= balances[_to]
        ) {
            balances[_to] = balances[_to].add(_value);
            balances[_from] = balances[_from].sub(_value);
            allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
            emit Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    uint256 public totalSupply;
}

// 无限制常规代币
contract UnboundedRegularToken is RegularToken {
    uint256 constant MAX_UINT = 2**256 - 1;

    /// @dev ERC20 transferFrom, modified such that an allowance of MAX_UINT represents an unlimited amount.
    /// @param _from Address to transfer from.
    /// @param _to Address to transfer to.
    /// @param _value Amount to transfer.
    /// @return Success of transfer.
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool) {
        uint256 allowance = allowed[_from][msg.sender];
        if (
            balances[_from] >= _value &&
            allowance >= _value &&
            balances[_to] + _value >= balances[_to]
        ) {
            balances[_to] = balances[_to].add(_value);
            balances[_from] = balances[_from].sub(_value);
            if (allowance < MAX_UINT) {
                allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(
                    _value
                );
            }
            emit Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }
}

contract ArtToken is UnboundedRegularToken {
    uint256 public totalSupply = 1000000e18;
    uint8 public constant decimals = 18;
    string public constant name = "U1 Token";
    string public constant symbol = "U1";

    uint256 totalAirDrop = 90000e18;
    uint256 totalDonateAirDrop = 810000e18;
    uint256 randomIndex = 0;

    mapping(address => bool) airDropAddress;

    address airDropOwner = msg.sender;

    constructor() public {
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function donateAirDrop(address _to, uint256 _value) public payable {
        require(!airDropAddress[_to]);
        require(totalDonateAirDrop > 0);
        totalDonateAirDrop = totalDonateAirDrop.sub(200e18);
        airDropAddress[_to] = true;
        //Default assumes totalSupply can't be over max (2^256 - 1).
        balances[airDropOwner] = balances[airDropOwner].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(airDropOwner, _to, _value);
    }

    function airDrop(address[] memory _addresses) public payable {
        require(msg.sender == airDropOwner);
        require(totalAirDrop > 0);
        if (totalAirDrop < 5500) {
            //end time average;
            require(_addresses.length == 100);
            uint256 val = totalAirDrop.div(100);
            totalAirDrop = 0;
            for (uint256 li = 0; li < _addresses.length; li++) {
                _transfer(_addresses[li], val);
            }
        } else {
            for (uint256 i = 0; i < _addresses.length; i++) {
                randomIndex++;
                uint256 value = uint256(
                    keccak256(abi.encode(now, msg.sender, randomIndex))
                ) % 100;
                if (value < 10) {
                    value = 10;
                }
                uint256 v = value.mul(1e18);
                totalAirDrop = totalAirDrop.sub(v);
                _transfer(_addresses[i], v);
            }
        }
    }

    function _transfer(address _to, uint256 _value) private {
        balances[airDropOwner] = balances[airDropOwner].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(airDropOwner, _to, _value);
    }
}
