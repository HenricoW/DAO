// SPDX-License-Identifier: MIT

pragma solidity ^0.7.3;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract DAO {
    IERC20 public gToken;
    mapping (address => uint) public shares;
    uint public totalShares;

    enum Side { Yes, No }
    enum State { Undecided, Approved, Rejected }
    struct Proposal {
        address creator;
        uint createdAt;
        bytes32 proposalHash;
        uint sharesFor;
        uint sharesAgainst;
        State status;
    }
    uint public constant MIN_SHARES_FOR_PROPOSAL = 10 ether;

    mapping (bytes32 => Proposal) public proposals; // keep track of proposals
    mapping (address => mapping (bytes32 => bool)) public voted; // keep track of who voted

    constructor (address _gtoken) {
        gToken = IERC20(_gtoken);
    }

    function deposit(uint amount_g) external {
        gToken.transferFrom(msg.sender, address(this), amount_g);
        shares[msg.sender] += amount_g;
        totalShares += amount_g;
    }

    function withdraw(uint amount_s) external {
        require(shares[msg.sender] >= amount_s, "Insufficient token balance");
        shares[msg.sender] -= amount_s;
        totalShares -= amount_s;
        gToken.transfer(msg.sender, amount_s);
    }

    function createProposal(bytes32 propHash) external {
        require(shares[msg.sender] >= MIN_SHARES_FOR_PROPOSAL, "Not enough shares to create proposal");
        require(proposals[propHash].proposalHash == bytes32(0), "Proposal already exists");
        Proposal memory prop = Proposal(
            msg.sender,
            block.timestamp,
            propHash,
            0,
            0,
            State.Undecided
        );
        proposals[propHash] = prop;
    }

    function vote(uint _shares, Side side, bytes32 propHash) external {
        require(proposals[propHash].proposalHash != bytes32(0), "Proposal does not exist");
        require(block.timestamp >= (proposals[propHash].createdAt + 1 hours), "Past proposal deadline");
        require(voted[msg.sender][propHash] == false, "Already voted");

        if(side == Side.Yes){
            proposals[propHash].sharesFor += _shares;
            if(proposals[propHash].sharesFor * 100 / totalShares > 50) proposals[propHash].status = State.Approved; // only works if no voting during deposits
        } else {
            proposals[propHash].sharesAgainst += _shares;
            if(proposals[propHash].sharesAgainst * 100 / totalShares > 50) proposals[propHash].status = State.Rejected;
        }
    }
}