// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./EcoFundModel.sol";
import "./EcoFundFactory.sol";
import "./RateConverter.sol";

error EcoFund__not_implemented();
error EcoFund__after_endDate();

contract EcoFund {
    using RateConverter for uint256;

    /* Immutable state variables */
    uint public immutable i_id;
    address public immutable i_owner;
    EcoFundModel.FundraiserType public immutable i_type;
    EcoFundModel.FundraiserCategory public immutable i_category;
    uint public immutable i_endDate;
    uint public immutable i_goalAmount;
    EcoFundFactory private immutable i_factory;

    /* State variables */
    string[] public s_descriptions;
    string[] public s_images;
    uint public s_defaultImage;
    string public s_name;
    EcoFundModel.FundraiserStatus public s_status;
    mapping(address => uint) public s_balances;
    mapping(address => mapping(address => uint)) public s_donors;

    /* Modifiers */
    modifier onlyOwner {
        require(msg.sender == i_owner, "You must be the owner of the fundraiser to perform this operation");
        _;
    }

    /* Create a new instance of a fundraiser */
    constructor(
        uint _id,
        address _owner,
        EcoFundModel.FundraiserType _type,
        EcoFundModel.FundraiserCategory _category,
        string memory _name,
        string memory _initialDescription,
        uint _endDate,
        uint _goalAmount
    ) {
        i_id = _id;
        i_owner = _owner;
        i_type = _type;
        i_category = _category;
        s_name = _name;
        s_descriptions.push(_initialDescription);
        i_factory = EcoFundFactory(msg.sender);
        i_endDate = _endDate;
        i_goalAmount = _goalAmount; // in USD cents! 1 USD = 100 _goalAmount
        s_status = EcoFundModel.FundraiserStatus.ACTIVE;
    }

    /* Donate funds to the fundraiser */
    function makeDonation(address _donorAddress, uint _amount, address _tokenAddress) external payable returns (bool) {
        require(s_status == EcoFundModel.FundraiserStatus.ACTIVE, "You cannot donate to a fundraiser that is not active");
        require(_amount > 0, "Cannot deposit 0");
        if (i_endDate > 0 && block.timestamp > i_endDate) {
            revert EcoFund__after_endDate();
        }

        if (_tokenAddress == address(0)) {
            // ETH deposit
            require(msg.value == _amount);
            s_donors[_donorAddress][address(0)] = s_donors[_donorAddress][address(0)] + _amount;
            s_balances[address(0)] = s_balances[address(0)] + _amount;
        } else {
            // TODO
            revert EcoFund__not_implemented();
        }

        finalizeDonation();

        return true;

        // TODO emit
    }

    /* Withdraw funds from the contract */
    function withdrawFunds(uint _amount, address _tokenAddress) public onlyOwner {
        require(_amount > 0, "Cannot withdraw 0");
        uint currentBalance = s_balances[_tokenAddress];
        require(_amount <= currentBalance, "Sorry, can't withdraw more than total donations");

        s_balances[_tokenAddress] = currentBalance - _amount;

        if (_tokenAddress == address(0)) {
            (bool success, ) = msg.sender.call{value: _amount}("");
            require(success, "Transfer failed.");
        } else {
            // TODO
            revert EcoFund__not_implemented();
        }

        // TODO emit
    }

    /* Add a picture */
    function addImage(string memory _picture, bool _makeDefault) external onlyOwner {
        s_images.push(_picture);
        if (_makeDefault == true) {
            s_defaultImage = s_images.length - 1;
        }
    }

    /* Set picture as default */
    function setDefaultPicture(uint _pictureIdx) external onlyOwner {
        require(_pictureIdx < s_images.length, "Image not found");
        s_defaultImage = _pictureIdx;
    }

    /* Update description */
    function setDefaultPicture(string memory _description) external onlyOwner {
        s_descriptions.push(_description);
    }

    /* Close fundraiser and revert all donations */
    function closeAndRevertDonations() public onlyOwner {
        require(s_status == EcoFundModel.FundraiserStatus.ACTIVE, "You can only close active fundraisers");
        // TODO return donations
        s_status = EcoFundModel.FundraiserStatus.CLOSED;
    }

    /* Get all details */
    function getAllDetails() public view returns (
        uint id,
        address owner,
        EcoFundModel.FundraiserType fType,
        EcoFundModel.FundraiserCategory category,
        uint endDate,
        uint goalAmount,
        string[] memory descriptions,
        string[] memory images,
        uint defaultImage,
        string memory name,
        EcoFundModel.FundraiserStatus status,
        uint balances
    ) {
        return (
            i_id,
            i_owner,
            i_type,
            i_category,
            i_endDate,
            i_goalAmount,
            s_descriptions,
            s_images,
            s_defaultImage,
            s_name,
            s_status,
            s_balances[address(0)]
        );
    }

    function finalizeDonation() internal {
        if (i_goalAmount > 0) {
            uint totalDonationsInCents = s_balances[address(0)].getConversionRate(i_factory.s_priceFeed());
            if (totalDonationsInCents >= i_goalAmount) {
                s_status = EcoFundModel.FundraiserStatus.FULLY_FUNDED;
            }
        }
    }

    function getImagesCount() public view returns (uint) {
        return s_images.length;
    }

    function getDescriptionsCount() public view returns (uint) {
        return s_descriptions.length;
    }
}
