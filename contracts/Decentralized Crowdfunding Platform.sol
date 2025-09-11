// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Crowdfunding Platform
 * @dev A smart contract for creating and managing crowdfunding campaigns
 * @author Your Name
 */
contract Project {
    
    // Struct to represent a crowdfunding campaign
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool completed;
        bool fundsWithdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    // State variables
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFee = 25; // 2.5% platform fee (in basis points)
    address payable public owner;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }
    
    modifier onlyCampaignCreator(uint256 _campaignId) {
        require(
            msg.sender == campaigns[_campaignId].creator,
            "Only campaign creator can call this function"
        );
        _;
    }
    
    // Constructor
    constructor() {
        owner = payable(msg.sender);
        campaignCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title The title of the campaign
     * @param _description Brief description of the campaign
     * @param _goalAmount The funding goal in wei
     * @param _durationInDays Duration of the campaign in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 campaignId = campaignCounter;
        Campaign storage newCampaign = campaigns[campaignId];
        
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);
        newCampaign.completed = false;
        newCampaign.fundsWithdrawn = false;
        
        campaignCounter++;
        
        emit CampaignCreated(
            campaignId,
            msg.sender,
            _title,
            _goalAmount,
            newCampaign.deadline
        );
    }
    
    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId The ID of the campaign to contribute to
     */
    function contributeToCampaign(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(!campaign.completed, "Campaign is already completed");
        
        // Track contribution
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount) {
            campaign.completed = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds or claim refunds
     * @param _campaignId The ID of the campaign
     */
    function withdrawOrRefund(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        
        if (campaign.completed && msg.sender == campaign.creator) {
            // Creator withdraws funds if goal was met
            require(!campaign.fundsWithdrawn, "Funds already withdrawn");
            
            uint256 platformFeeAmount = (campaign.raisedAmount * platformFee) / 1000;
            uint256 creatorAmount = campaign.raisedAmount - platformFeeAmount;
            
            campaign.fundsWithdrawn = true;
            
            // Transfer platform fee to owner
            owner.transfer(platformFeeAmount);
            
            // Transfer remaining funds to creator
            campaign.creator.transfer(creatorAmount);
            
            emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
            
        } else if (!campaign.completed && campaign.contributions[msg.sender] > 0) {
            // Contributor claims refund if goal was not met
            uint256 refundAmount = campaign.contributions[msg.sender];
            campaign.contributions[msg.sender] = 0;
            campaign.raisedAmount -= refundAmount;
            
            payable(msg.sender).transfer(refundAmount);
            
            emit RefundIssued(_campaignId, msg.sender, refundAmount);
        } else {
            revert("No funds to withdraw or refund");
        }
    }
    
    // View functions
    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool completed,
            bool fundsWithdrawn
        ) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.completed,
            campaign.fundsWithdrawn
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getAllCampaigns() external view returns (uint256[] memory) {
        uint256[] memory allCampaigns = new uint256[](campaignCounter);
        for (uint256 i = 0; i < campaignCounter; i++) {
            allCampaigns[i] = i;
        }
        return allCampaigns;
    }
    
    function getActiveCampaigns() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // First pass: count active campaigns
        for (uint256 i = 0; i < campaignCounter; i++) {
            if (block.timestamp < campaigns[i].deadline && !campaigns[i].completed) {
                activeCount++;
            }
        }
        
        // Second pass: populate active campaigns array
        uint256[] memory activeCampaigns = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < campaignCounter; i++) {
            if (block.timestamp < campaigns[i].deadline && !campaigns[i].completed) {
                activeCampaigns[index] = i;
                index++;
            }
        }
        
        return activeCampaigns;
    }
    
    // Admin functions
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 100, "Platform fee cannot exceed 10%");
        platformFee = _newFee;
    }
    
    function emergencyWithdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }
    
    // Utility functions
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function isDeadlinePassed(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (bool) 
    {
        return block.timestamp >= campaigns[_campaignId].deadline;
    }
}
