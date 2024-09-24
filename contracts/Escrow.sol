// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {

    // Struct for tracking buyer information
    struct Buyer {
        address buyerAddress;
        uint totalSpent;
        bool isConfirmed;
        uint refundBalance;
        uint penaltyAmount;
    }

    // Struct for tracking seller information
    struct Seller {
        address sellerAddress;
        uint totalEarned;
        bool isConfirmed;
        uint finalAmountToReceive;
        uint penaltyAmount;
    }

    // Struct for tracking an order
    struct Order {
        uint orderID;
        uint orderAmount;
        uint quantity;
        uint escrowBalance;
        OrderStatus status;
        uint creationTimestamp;
        uint expirationTimestamp;
        bool isDisputed;

        Buyer private buyer;
        Seller private seller;
    }

    // Enum for order status
    enum OrderStatus { Pending, Delivered, Confirmed, Disputed, Released, Refunded }

    // Mapping to store orders by ID
    mapping(uint => Order) public orders;

    // Counter for generating unique order IDs
    uint public orderCounter;

    // Penalty constants
    uint public constant penaltyRate = 2; // 2% deduction every 24 hours
    uint public constant penaltyInterval = 86400; // 24 hours in seconds

    // Events for order-related actions
    event OrderCreated(uint indexed orderID, address indexed buyer, address indexed seller, uint orderAmount, uint quantity);
    event PenaltyDeducted(uint orderID, uint penaltyAmount, uint remainingEscrowBalance);

    // Function to create a new order
    function createOrder(
        address _sellerAddress,
        uint _orderAmount,
        uint _quantity
    ) public {
        require(_sellerAddress != address(0), "Invalid seller address");
        require(_orderAmount > 0, "Order amount must be greater than zero");
        require(_quantity > 0, "Quantity must be greater than zero");

        // Increment order counter to generate unique orderID
        orderCounter++;

        // Create a new buyer and seller
        Buyer memory newBuyer = Buyer({
            buyerAddress: msg.sender,
            totalSpent: _orderAmount,
            isConfirmed: false,
            refundBalance: 0,
            penaltyAmount: 0
        });

        Seller memory newSeller = Seller({
            sellerAddress: _sellerAddress,
            totalEarned: 0,
            isConfirmed: false,
            finalAmountToReceive: 0,
            penaltyAmount: 0
        });

        // Create a new order
        orders[orderCounter] = Order({
            orderID: orderCounter,
            orderAmount: _orderAmount,
            quantity: _quantity,
            escrowBalance: _orderAmount,
            status: OrderStatus.Pending,
            creationTimestamp: block.timestamp,
            expirationTimestamp: block.timestamp + 30 days,
            isDisputed: false,
            buyer: newBuyer,
            seller: newSeller
        });

        // Emit event for order creation
        emit OrderCreated(orderCounter, msg.sender, _sellerAddress, _orderAmount, _quantity);
    }

    // Function to calculate and deduct penalty if deadline is missed
    function applyPenalty(uint orderID) public {
        Order storage order = orders[orderID];

        // Ensure the deadline has passed
        require(block.timestamp > order.expirationTimestamp, "Deadline not yet reached");

        // Calculate how many 24-hour periods have passed since the expiration timestamp
        uint timePassed = block.timestamp - order.expirationTimestamp;
        uint penaltyCycles = timePassed / penaltyInterval;

        // Ensure that at least one penalty cycle has passed
        require(penaltyCycles > 0, "No penalty to apply");

        // Calculate the penalty amount (2% per 24 hours)
        uint penaltyAmount = (order.orderAmount * penaltyRate * penaltyCycles) / 100;

        // Ensure the penalty doesn't exceed the escrow balance
        if (penaltyAmount > order.escrowBalance) {
            penaltyAmount = order.escrowBalance;
        }

        // Deduct the penalty from the escrow balance and add to buyer's refund
        order.escrowBalance -= penaltyAmount;
        order.buyer.penaltyAmount += penaltyAmount;
        order.buyer.refundBalance += penaltyAmount;

        // Emit event for penalty deduction
        emit PenaltyDeducted(orderID, penaltyAmount, order.escrowBalance);
    }

    // Function to get buyer details (only the buyer can access this)
    function getBuyerDetails(uint orderID) public view returns (address, uint, bool, uint, uint) {
        require(msg.sender == orders[orderID].buyer.buyerAddress, "Only the buyer can access their details");
        Buyer storage buyer = orders[orderID].buyer;
        return (
            buyer.buyerAddress,
            buyer.totalSpent,
            buyer.isConfirmed,
            buyer.refundBalance,
            buyer.penaltyAmount
        );
    }

    // Function to get seller details (only the seller can access this)
    function getSellerDetails(uint orderID) public view returns (address, uint, bool, uint, uint) {
        require(msg.sender == orders[orderID].seller.sellerAddress, "Only the seller can access their details");
        Seller storage seller = orders[orderID].seller;
        return (
            seller.sellerAddress,
            seller.totalEarned,
            seller.isConfirmed,
            seller.finalAmountToReceive,
            seller.penaltyAmount
        );
    }


}
