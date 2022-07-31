// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Seedifyfund inspiration: https://github.com/Seedifyfund/Locked-Staking/blob/main/contracts/Locking.sol
contract LockedStaking is ReentrancyGuard {
    /* ========== STRUCTS ========== */

    /* ========== STATE VARIABLES ========== */

    address public dev;
    address public owner;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    uint public periodFinish = 0; // Timestamp of when the rewards finish

    uint public rewardRate = 0; // Reward to be paid out per second

    uint public rewardsDuration; // Duration of rewards to be paid out (in seconds)

    uint public lastUpdateTime; // Minimum of last updated time and reward finish time

    uint public rewardPerTokenStored; // Sum of (reward rate * dt * 1e18 / total supply)

    mapping(address => uint) public userRewardPerTokenPaid; // User address => rewardPerTokenStored

    mapping(address => uint) public rewards; // User address => rewards to be claimed

    uint private _totalSupply; // Total staked

    mapping(address => uint) private _balances; // User address => staked amount

    mapping(address => uint) private _unlockTimestamp; // User address => unlock timestamp

    uint public lockDuration;

    bool public isStakingActive = false;

    constructor(
        address _dev,
        address _owner,
        address _stakingToken,
        address _rewardToken,
        uint _rewardsDuration,
        uint _lockDuration
    ) {
        dev = _dev;
        owner = _owner;

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
        rewardsDuration = _rewardsDuration;
        lockDuration = _lockDuration;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function stakingStatusOf(address account) external view returns (uint256, uint256, uint256) {
        return (
            _balances[account],
            _unlockTimestamp[account],
            earned(account)
        );
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) /
            _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return
            ((_balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 _amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0, "Cannot stake 0");
        require(isStakingActive, "Staking is not active yet");
        require(
            _balances[msg.sender] < 1 ||
                block.timestamp < _unlockTimestamp[msg.sender],
            "Lock expired, please withdraw your previous tokens and stake again"
        );

        _totalSupply += _amount;
        _balances[msg.sender] += _amount;
        _unlockTimestamp[msg.sender] = block.timestamp + lockDuration;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        emit LockStaked(msg.sender, _amount, _unlockTimestamp[msg.sender]);
    }

    function withdraw(uint256 _amount)
        public
        nonReentrant
        updateReward(msg.sender)
    {
        require(_amount > 0, "Cannot withdraw 0");
        require(
            _balances[msg.sender] >= _amount,
            "You can't withdraw more than what you have"
        );
        require(
            block.timestamp >= _unlockTimestamp[msg.sender],
            "Requesting before lock time"
        );

        _totalSupply -= _amount;
        _balances[msg.sender] -= _amount;
        stakingToken.transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 _reward)
        external
        onlyOwner
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = _reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (_reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(
            rewardRate <= balance / rewardsDuration,
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        isStakingActive = true;
        emit StakingActive(isStakingActive, block.timestamp);
        emit RewardAdded(_reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        require(tokenAmount <= (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate,"Cannot withdraw more than the safe rewards");
        IERC20(tokenAddress).transfer(dev, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOwner() {
        require(msg.sender == owner || msg.sender == dev, "not authorized");
        _;
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

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event LockStaked(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event StakingActive(bool status, uint256 time);
}
