// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct Market {
        string question;
        uint256 endTime;
        uint256 totalYesShares;
        uint256 totalNoShares;
        bool resolved;
        bool outcome;
        address creator;
        mapping(address => uint256) yesShares;
        mapping(address => uint256) noShares;
        mapping(address => bool) hasClaimed;
    }
    
    mapping(uint256 => Market) public markets;
    uint256 public marketCount;
    
    event MarketCreated(uint256 indexed marketId, string question, uint256 endTime, address creator);
    event SharesPurchased(uint256 indexed marketId, address indexed buyer, bool isYes, uint256 amount, uint256 shares);
    event MarketResolved(uint256 indexed marketId, bool outcome);
    event WinningsClaimed(uint256 indexed marketId, address indexed claimer, uint256 amount);
    
    modifier onlyCreator(uint256 marketId) {
        require(msg.sender == markets[marketId].creator, "Only market creator can resolve");
        _;
    }
    
    modifier marketExists(uint256 marketId) {
        require(marketId < marketCount, "Market does not exist");
        _;
    }
    
    modifier marketActive(uint256 marketId) {
        require(block.timestamp < markets[marketId].endTime, "Market has ended");
        require(!markets[marketId].resolved, "Market already resolved");
        _;
    }
    
    modifier marketResolved(uint256 marketId) {
        require(markets[marketId].resolved, "Market not yet resolved");
        _;
    }
    
    // Core Function 1: Create a new prediction market
    function createMarket(string memory _question, uint256 _duration) external {
        require(bytes(_question).length > 0, "Question cannot be empty");
        require(_duration > 0, "Duration must be positive");
        
        uint256 marketId = marketCount;
        Market storage newMarket = markets[marketId];
        
        newMarket.question = _question;
        newMarket.endTime = block.timestamp + _duration;
        newMarket.creator = msg.sender;
        newMarket.resolved = false;
        
        marketCount++;
        
        emit MarketCreated(marketId, _question, newMarket.endTime, msg.sender);
    }
    
    // Core Function 2: Buy prediction shares (Yes or No)
    function buyShares(uint256 marketId, bool isYes) 
        external 
        payable 
        marketExists(marketId) 
        marketActive(marketId) 
    {
        require(msg.value > 0, "Must send ETH to buy shares");
        
        Market storage market = markets[marketId];
        
        // Simple pricing: 1 ETH = 100 shares
        uint256 shares = (msg.value * 100) / 1 ether;
        require(shares > 0, "Insufficient ETH for shares");
        
        if (isYes) {
            market.yesShares[msg.sender] += shares;
            market.totalYesShares += shares;
        } else {
            market.noShares[msg.sender] += shares;
            market.totalNoShares += shares;
        }
        
        emit SharesPurchased(marketId, msg.sender, isYes, msg.value, shares);
    }
    
    // Core Function 3: Resolve market and claim winnings
    function resolveMarket(uint256 marketId, bool _outcome) 
        external 
        marketExists(marketId) 
        onlyCreator(marketId) 
    {
        Market storage market = markets[marketId];
        require(block.timestamp >= market.endTime, "Market still active");
        require(!market.resolved, "Market already resolved");
        
        market.resolved = true;
        market.outcome = _outcome;
        
        emit MarketResolved(marketId, _outcome);
    }
    
    // Additional function to claim winnings
    function claimWinnings(uint256 marketId) 
        external 
        marketExists(marketId) 
        marketResolved(marketId) 
    {
        Market storage market = markets[marketId];
        require(!market.hasClaimed[msg.sender], "Already claimed");
        
        uint256 userShares;
        uint256 totalWinningShares;
        
        if (market.outcome) {
            // Yes won
            userShares = market.yesShares[msg.sender];
            totalWinningShares = market.totalYesShares;
        } else {
            // No won
            userShares = market.noShares[msg.sender];
            totalWinningShares = market.totalNoShares;
        }
        
        require(userShares > 0, "No winning shares");
        
        // Calculate winnings: user's share of total pool
        uint256 totalPool = address(this).balance;
        uint256 winnings = (userShares * totalPool) / totalWinningShares;
        
        market.hasClaimed[msg.sender] = true;
        
        require(winnings > 0, "No winnings to claim");
        payable(msg.sender).transfer(winnings);
        
        emit WinningsClaimed(marketId, msg.sender, winnings);
    }
    
    // View functions
    function getMarketInfo(uint256 marketId) 
        external 
        view 
        marketExists(marketId) 
        returns (
            string memory question,
            uint256 endTime,
            uint256 totalYesShares,
            uint256 totalNoShares,
            bool resolved,
            bool outcome,
            address creator
        ) 
    {
        Market storage market = markets[marketId];
        return (
            market.question,
            market.endTime,
            market.totalYesShares,
            market.totalNoShares,
            market.resolved,
            market.outcome,
            market.creator
        );
    }
    
    function getUserShares(uint256 marketId, address user) 
        external 
        view 
        marketExists(marketId) 
        returns (uint256 yesShares, uint256 noShares) 
    {
        Market storage market = markets[marketId];
        return (market.yesShares[user], market.noShares[user]);
    }
    
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
