// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./EcoFundModel.sol";
import "./EcoFund.sol";

    error EcoFundFactory__deposit__zero_deposit();
    error EcoFundFactory__deposit__less_than_declared();
    error EcoFundFactory__deposit__token_not_allowed();
    error EcoFundFactory__recurring__only_owner();
    error EcoFundFactory__not_implemented();

contract EcoFundFactory is KeeperCompatibleInterface, Ownable {
    /* State variables */
    uint private s_counterFundraisers = 0;
    uint private s_counterRecurringPayments = 0;
    uint public s_lastTimeStamp;
    address[] public s_allowedERC20Tokens;
    mapping(address => mapping(address => uint)) public s_userBalances;
    mapping(uint => address) public s_fundraisers;
    mapping(address => uint[]) public s_fundraisersByOwner;
    mapping(uint => EcoFundModel.RecurringPaymentDisposition) public s_recurringPayments;
    mapping(address => uint[]) public s_recurringPaymentsByOwner;
    AggregatorV3Interface public s_priceFeed;
    uint i_recurringInterval = 1 hours;

    /* Events */
    event FundraiserCreated(uint indexed fundraiserId, address indexed creator, string title, EcoFundModel.FundraiserType fundraiserType, EcoFundModel.FundraiserCategory category, uint endDate, uint goalAmount);
    event UserBalanceChanged(address indexed creator, address tokenAddress, uint previousBalance, uint newBalance);


    /* Constructor - provide ETH/USD Chainlink price feed address */
    /* rinkeby: 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e */
    constructor(/*address _ethUsdPriceFeed*/) {
        // s_priceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
        s_priceFeed = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
        s_lastTimeStamp = block.timestamp;
    }

    /* Deposit funds to the contract */
    function depositFunds(uint _amount, address _tokenAddress) external payable {
        if (_amount == 0) {
            revert EcoFundFactory__deposit__zero_deposit();
        }
        uint currentBalance = s_userBalances[msg.sender][_tokenAddress];
        if (_tokenAddress == address(0)) {
            // ETH deposit
            if (msg.value < _amount) {
                revert EcoFundFactory__deposit__less_than_declared();
            }

            s_userBalances[msg.sender][address(0)] = s_userBalances[msg.sender][address(0)] + _amount;
        } else {
            // ERC20 deposit
            if (!isTokenAllowed(_tokenAddress)) {
                revert EcoFundFactory__deposit__token_not_allowed();
            }

            /// TODO
            revert EcoFundFactory__not_implemented();
        }
        emit UserBalanceChanged(msg.sender, _tokenAddress, currentBalance, s_userBalances[msg.sender][_tokenAddress]);
    }

    /* Withdraw funds from the contract */
    function withdrawFunds(uint _amount, address _tokenAddress) public {
        require(_amount > 0, "Cannot withdraw 0");
        uint currentBalance = s_userBalances[msg.sender][_tokenAddress];
        require(_amount <= currentBalance, "Not enough balance");

        s_userBalances[msg.sender][_tokenAddress] = currentBalance - _amount;

        if (_tokenAddress == address(0)) {
            (bool success,) = msg.sender.call{value : _amount}("");
            require(success, "Transfer failed.");
        } else {
            // TODO
            revert EcoFundFactory__not_implemented();
        }
        emit UserBalanceChanged(msg.sender, _tokenAddress, s_userBalances[msg.sender][_tokenAddress], currentBalance - _amount);
    }

    /* Add a new token to the list allowed for deposits and withdrawals */
    function allowToken(address _tokenAddress) public onlyOwner {
        s_allowedERC20Tokens.push(_tokenAddress);
    }

    /* Check if deposited token is supported */
    function isTokenAllowed(address _tokenAddress) public view returns (bool) {
        for (
            uint256 idx = 0;
            idx < s_allowedERC20Tokens.length;
            idx++
        ) {
            if (s_allowedERC20Tokens[idx] == _tokenAddress) {
                return true;
            }
        }
        return false;
    }

    /* Create a new fundraiser */
    function createFundraiser(
        EcoFundModel.FundraiserType _type,
        EcoFundModel.FundraiserCategory _category,
        string calldata _name,
        string calldata _description,
        uint _endDate,
        uint _goalAmount
    ) external returns (uint fundraiserId) {
        fundraiserId = s_counterFundraisers;
        s_counterFundraisers = s_counterFundraisers + 1;

        EcoFund fundraiser = new EcoFund(
            fundraiserId,
            msg.sender,
            _type,
            _category,
            _name,
            _description,
            _endDate,
            _goalAmount
        );

        s_fundraisers[fundraiserId] = address(fundraiser);
        s_fundraisersByOwner[msg.sender].push(fundraiserId);

        emit FundraiserCreated(fundraiserId, msg.sender, _name, _type, _category, _endDate, _goalAmount);

        return fundraiserId;
    }

    /* Fetch open fundraisers */
    function listFundraisersByStatus (EcoFundModel.FundraiserStatus _status) public view returns (EcoFundModel.FundraiserItem[] memory fundraisersByStatus) {
        uint i_totalFundraisersWithStatus = 0;

        for(uint i = 0; i < s_counterFundraisers; i++) {
            if (EcoFund(s_fundraisers[i]).s_status() == _status) {
                i_totalFundraisersWithStatus++;
            }
        }

        EcoFundModel.FundraiserItem[] memory openFundraisers = new EcoFundModel.FundraiserItem[](i_totalFundraisersWithStatus);
        if (i_totalFundraisersWithStatus == 0) {
            return openFundraisers;
        }
        
        for(uint i = 0; i < i_totalFundraisersWithStatus; i++) {
            EcoFund fundraiser = EcoFund(s_fundraisers[i]);
            if (fundraiser.s_status() == _status) {
                openFundraisers[i].id = fundraiser.i_id();
                openFundraisers[i].addr = s_fundraisers[i];
                openFundraisers[i].owner = fundraiser.i_owner();
                openFundraisers[i].fType = fundraiser.i_type();
                openFundraisers[i].category = fundraiser.i_category();
                openFundraisers[i].name = fundraiser.s_name();
                if (fundraiser.getDescriptionsCount() > 0) {
                    openFundraisers[i].description = fundraiser.s_descriptions(0);
                }
                
                openFundraisers[i].endDate = fundraiser.i_endDate();
                openFundraisers[i].goalAmount = fundraiser.i_goalAmount();
                if (fundraiser.getImagesCount() > fundraiser.s_defaultImage()) {
                    openFundraisers[i].defaultImage = fundraiser.s_images(fundraiser.s_defaultImage());
                }
            }
        }
        return openFundraisers;
    }

    /* Donate to a fundraiser (lookup by ID) */
    function donateById(
        uint _fundraiserId,
        uint _amount,
        address _tokenAddress
    ) public {
        donateByAddress(s_fundraisers[_fundraiserId], _amount, _tokenAddress);
    }

    /* Donate to a fundraiser (lookup by address) */
    function donateByAddress(
        address _fundraiserAddress,
        uint _amount,
        address _tokenAddress
    ) public {
        require(_amount > 0, "Cannot donate 0");
        uint currentBalance = s_userBalances[msg.sender][_tokenAddress];
        require(_amount <= currentBalance, "Not enough balance");

        s_userBalances[msg.sender][_tokenAddress] = currentBalance - _amount;

        if (_tokenAddress == address(0)) {
            bool success = EcoFund(_fundraiserAddress).makeDonation{value : _amount}(msg.sender, _amount, _tokenAddress);
            require(success, "Transfer failed.");
        } else {
            // TODO
            revert EcoFundFactory__not_implemented();
        }
    }

    /* Get user balance */
    function getMyBalance(address _token) public view returns (uint balance) {
        return s_userBalances[msg.sender][_token];
    }

    /* Get user's recurring payments */
    function getMyRecurringPayments() public view returns (EcoFundModel.RecurringPaymentDisposition[] memory recurringPayments) {
        recurringPayments = new EcoFundModel.RecurringPaymentDisposition[](s_recurringPaymentsByOwner[msg.sender].length);
        for (uint i = 0; i < s_recurringPaymentsByOwner[msg.sender].length; i++) {
            recurringPayments[i] = s_recurringPayments[s_recurringPaymentsByOwner[msg.sender][i]];
        }
        return recurringPayments;
    }

    /* Create a recurring payment */
    function createRecurringPayment(
        address _targetFundraiser,
        address _tokenAddress,
        uint _amount,
        uint32 _intervalHours
    ) external returns (uint recurringPaymentId) {
        recurringPaymentId = s_counterRecurringPayments;
        s_counterRecurringPayments = s_counterRecurringPayments + 1;
        s_recurringPayments[recurringPaymentId].id = recurringPaymentId;
        s_recurringPayments[recurringPaymentId].owner = msg.sender;
        s_recurringPayments[recurringPaymentId].target = _targetFundraiser;
        s_recurringPayments[recurringPaymentId].tokenAddress = _tokenAddress;
        s_recurringPayments[recurringPaymentId].amount = _amount;
        s_recurringPayments[recurringPaymentId].intervalHours = _intervalHours;
        s_recurringPayments[recurringPaymentId].status = EcoFundModel.RecurringPaymentStatus.ACTIVE;

        s_recurringPaymentsByOwner[msg.sender].push(recurringPaymentId);

        executeRecurringPayment(recurringPaymentId);

        return recurringPaymentId;
    }

    /* Create a recurring payment */
    function cancelRecurringPayment(
        uint _id
    ) external {
        if (msg.sender != s_recurringPayments[_id].owner) {
            revert EcoFundFactory__deposit__token_not_allowed();
        }

        if (s_recurringPayments[_id].status == EcoFundModel.RecurringPaymentStatus.ACTIVE) {
            s_recurringPayments[_id].status = EcoFundModel.RecurringPaymentStatus.CANCELLED;
        }
    }

    /* Execute recurring payment - called internally on upkeep */
    // TODO fix reentrancy vulnerability - multiple upkeeps at the same time
    function executeRecurringPayment(uint _id) internal {
        uint executorBalance = s_userBalances[s_recurringPayments[_id].owner][s_recurringPayments[_id].tokenAddress];
        if (executorBalance >= s_recurringPayments[_id].amount) {
            s_userBalances[s_recurringPayments[_id].owner][s_recurringPayments[_id].tokenAddress] = executorBalance - s_recurringPayments[_id].amount;

            EcoFund fundraiser = EcoFund(s_recurringPayments[_id].target);
            if (fundraiser.s_status() == EcoFundModel.FundraiserStatus.ACTIVE && fundraiser.i_type() == EcoFundModel.FundraiserType.RECURRING_DONATION) {
                fundraiser.makeDonation{value : s_recurringPayments[_id].amount}(s_recurringPayments[_id].owner, s_recurringPayments[_id].amount, s_recurringPayments[_id].tokenAddress);
            }
        }
        s_recurringPayments[_id].lastExecution = block.timestamp;
    }

    /* Keepers integration */
    function checkUpkeep(bytes memory /* checkData */) public override view returns (
        bool upkeepNeeded,
        bytes memory /* performData */
    ) {
        bool intervalPassed = (block.timestamp - s_lastTimeStamp) > i_recurringInterval;
        bool hasFundraisersAndPayments = s_counterFundraisers > 0 && s_counterRecurringPayments > 0;

        // TODO optimize - return IDs of payments in performData
        bool hasPaymentsToExecute = false;
        for (uint id = 0; id < s_counterRecurringPayments; id++) {
            if (s_recurringPayments[id].status != EcoFundModel.RecurringPaymentStatus.ACTIVE) {
                continue;
            }

            if (EcoFund(s_recurringPayments[id].target).i_type() != EcoFundModel.FundraiserType.RECURRING_DONATION) {
                continue;
            }

            if (EcoFund(s_recurringPayments[id].target).s_status() != EcoFundModel.FundraiserStatus.ACTIVE) {
                continue;
            }

            if (s_userBalances[s_recurringPayments[id].owner][s_recurringPayments[id].tokenAddress] < s_recurringPayments[id].amount) {
                continue;
            }


            if (block.timestamp > s_recurringPayments[id].lastExecution + (s_recurringPayments[id].intervalHours * 60 * 60)) {
                hasPaymentsToExecute = true;
                break;
            }
        }

        upkeepNeeded = intervalPassed && hasFundraisersAndPayments && hasPaymentsToExecute;

        return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        for (uint id = 0; id < s_counterRecurringPayments; id++) {
            if (s_recurringPayments[id].status != EcoFundModel.RecurringPaymentStatus.ACTIVE) {
                continue;
            }

            if (EcoFund(s_recurringPayments[id].target).i_type() != EcoFundModel.FundraiserType.RECURRING_DONATION) {
                continue;
            }

            if (EcoFund(s_recurringPayments[id].target).s_status() != EcoFundModel.FundraiserStatus.ACTIVE) {
                continue;
            }

            if (s_userBalances[s_recurringPayments[id].owner][s_recurringPayments[id].tokenAddress] < s_recurringPayments[id].amount) {
                continue;
            }


            if (block.timestamp > s_recurringPayments[id].lastExecution + (s_recurringPayments[id].intervalHours * 60 * 60)) {
                executeRecurringPayment(id);
            }
        }
    }
}
