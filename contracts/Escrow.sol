// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract Escrow {

    // Struct for tracking buyer information
    struct Buyer {
        address buyerAddress;
        uint totalSpent;
        uint refundBalance; // Amount to be refunded due to penalties or other reasons
        uint penaltyAmount; // Penalty applied to the buyer due to delays
        bool isConfirmed; // Has the buyer confirmed receipt?
    }

    // Struct for tracking seller information
    struct Seller {
        address sellerAddress;
        uint totalEarned;
        uint finalAmountToReceive; // Final amount seller will receive after deductions
        uint penaltyAmount; // Penalty applied to the seller (if any)
        bool isConfirmed; // Has the seller confirmed delivery?
    }
    
    // Struct for tracking an order
    struct Order {
        uint orderID;
        Buyer buyer;
        Seller seller;
        uint orderAmount;
        uint escrowBalance;
        OrderStatus status;
        uint creationTimestamp;
        uint expirationTimestamp;
        bool isDisputed;
    }
    
    // Enum for order status
    enum OrderStatus { Pending, Delivered, Confirmed, Disputed, Released, Refunded }

    // Struct for delay-based penalties
    struct Penalty {
        uint expirationTime;
        uint delayStartTimestamp;
        uint lastPenaltyAppliedTimestamp;
        uint deductionBalance;
        uint finalAmountToSeller;
        uint refundToBuyer;
        bool penaltyAccrued;
        bool penaltyThresholdReached;
    }
    
    // Struct for dispute information
    struct Dispute {
        DisputeStatus status;
        string resolution;
        uint disputeTimestamp;
    }

    // Enum for dispute status
    enum DisputeStatus { None, Pending, Resolved }
    
    // Struct for security and configuration
    struct EscrowConfig {
        uint escrowFee; // e.g., 2% fee in basis points (200 = 2%)
        address feeRecipient;
        bool paused;
        address emergencyAdmin;
    }

    // Main mapping to store orders by ID
    mapping(uint => Order) public orders;

    // Mapping to store penalties for each order
    mapping(uint => Penalty) public penalties;
    
    // Mapping to store dispute information for each order
    mapping(uint => Dispute) public disputes;

    // Escrow contract configuration
    EscrowConfig public escrowConfig;

    // Time-based constants
    uint public constant penaltyWindow = 86400; // 24 hours in seconds
    uint public delayPenaltyRate = 2; // 2% per 24 hours delay
    uint public maxPenaltyCap = 50; // Maximum 50% penalty cap

    // Events (to log key actions)
    event OrderCreated(uint orderID, address buyer, address seller, uint orderAmount);
    event FundsDeposited(uint orderID, uint amount);
    event DeliveryConfirmed(uint orderID);
    event ReceiptConfirmed(uint orderID);
    event DisputeInitiated(uint orderID);
    event FundsReleased(uint orderID, uint amountToSeller, uint amountToBuyer);

    // Constructor to initialize escrow configuration
    constructor(uint _escrowFee, address _feeRecipient, address _emergencyAdmin) {
        escrowConfig = EscrowConfig({
            escrowFee: _escrowFee,
            feeRecipient: _feeRecipient,
            paused: false,
            emergencyAdmin: _emergencyAdmin
        });
    }
    
    // Additional functions for managing orders, penalties, and disputes will be added here
}
