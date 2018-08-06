pragma solidity 0.4.24;
import "./CustomPausable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";


contract Vesting is CustomPausable {
  using SafeMath for uint256;
  ERC20 public VestingToken;

  struct Grant {
    bool granted;
    bool revoked;
    uint allocation;
    uint claimed;
    uint startTime;
    uint endTime;
  }

  mapping(address => Grant) public grants;
  constructor(ERC20 _token) public {
    VestingToken = _token;
  }

  function addressGranted(address _assignee) public constant returns(bool) {
    return grants[_assignee].granted;
  }

  function addGrant(address _assignee, uint _allocation, uint _startTime, uint _endTime) internal {
    if(grants[_assignee].granted) {
      revert();
    }

    Grant memory grant;
    grant.granted = true;
    grant.allocation = _allocation;
    grant.startTime = _startTime;
    grant.endTime = _endTime;
    grants[_assignee] = grant;
  }

  function increaseGrant(address _assignee, uint _increase) internal {
    if(!grants[_assignee].granted) {
      revert();
    }
    grants[_assignee].allocation = grants[_assignee].allocation.add(_increase);
  }

  function calculateVestedTokens(address _assignee) public constant returns (uint256) {
    if(!grants[_assignee].granted || grants[_assignee].revoked) {
      return 0;
    }
   Grant memory grant;
   if(now < grant.startTime) {
     return 0;
   }
   if(now > grant.endTime) {
     return grant.allocation;
   }
   uint noOfMonthsPassed = (now - grant.startTime).div(30 * 1 days);
   if(noOfMonthsPassed < 6) {
     return grants[_assignee].allocation.mul(20).div(100);
   }
   else {
     return grants[_assignee].allocation.mul(60).div(100);
   }
  }

  function claimTokens(address _assignee) private {
    uint tokensVested = calculateVestedTokens(_assignee);
    uint difference = tokensVested.sub(grants[_assignee].claimed);
    require(difference > 0);
    grants[msg.sender].claimed = grants[_assignee].claimed.add(difference);
    require(VestingToken.transfer(_assignee, difference));
  }
  function claimTokens() public whenNotPaused {
    if(!grants[msg.sender].granted || grants[msg.sender].revoked) {
      revert();
    }
    claimTokens(msg.sender);
  }

  function revoke(address _assignee) public whenNotPaused onlyWhitelisted {
    if(grants[_assignee].revoked || !grants[_assignee].granted) {
      revert();
    }
    claimTokens(_assignee);
    grants[_assignee].revoked = true;
  }
}