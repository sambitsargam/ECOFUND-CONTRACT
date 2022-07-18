// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.7;

library EcoFundModel {
    enum FundraiserType {
        ONE_TIME_DONATION,
        RECURRING_DONATION,
        LOAN
    }

    enum FundraiserStatus {
        ACTIVE,
        FULLY_FUNDED,
        REPAYING,
        REPAID,
        CLOSED
    }

    enum FundraiserCategory {
        AGRI,
        POL,
        PLANT,
        COMMUNITY,
        ANIMALS,
        ENV
    }

    enum RecurringPaymentStatus {
        ACTIVE,
        CANCELLED
    }

    struct RecurringPaymentDisposition {
        uint id;
        address owner;
        address target;
        address tokenAddress;
        uint amount;
        uint32 intervalHours;
        uint lastExecution;
        RecurringPaymentStatus status;
    }

    struct FundraiserItem {
        uint id;
        address addr;
        address owner;
        EcoFundModel.FundraiserType fType;
        EcoFundModel.FundraiserCategory category;
        uint endDate;
        uint goalAmount;
        string description;
        string defaultImage;
        string name;
        EcoFundModel.FundraiserStatus status;
    }
}
