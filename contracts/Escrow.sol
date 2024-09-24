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
        uint deliveryTimestamp;  // Expected delivery timestamp set by seller
        bool isDisputed;

        Buyer private buyer;
        Seller private seller;
    }

    // Enum for order status
    enum OrderStatus { Pending, Confirmed, Delivered, Disputed, Released, Refunded }

    // Mapping to store orders by ID
    mapping(uint => Order) public orders;

    // Counter for generating unique order IDs
    uint public orderCounter;

    // Penalty constants
    uint public constant penaltyRate = 2; // 2% penalty per 24 hours
    uint public constant penaltyInterval = 86400; // 24 hours in seconds

    // Events for order-related actions
    event OrderCreated(uint indexed orderID, address indexed buyer, address indexed seller, uint orderAmount, uint quantity);
    event DeliveryConfirmed(uint indexed orderID, uint deliveryPeriod);
    event FundsLocked(uint indexed orderID, uint amountLocked);
    event PenaltyApplied(uint indexed orderID, uint penaltyAmount, uint totalRefunded);

    // Function to create a new order (no money sent at this stage)
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
            totalSpent: 0,  // Funds not yet locked
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
            escrowBalance: 0, // No funds locked yet
            status: OrderStatus.Pending,
            creationTimestamp: block.timestamp,
            deliveryTimestamp: 0, // Placeholder until seller confirms delivery period
            isDisputed: false,
            buyer: newBuyer,
            seller: newSeller
        });

        // Emit event for order creation
        emit OrderCreated(orderCounter, msg.sender, _sellerAddress, _orderAmount, _quantity);
    }

    // Function for the seller to confirm delivery with a specified delivery period
    function confirmDeliveryBySeller(uint orderID, uint deliveryPeriodInDays) public {
        Order storage order = orders[orderID];

        // Ensure only the seller of the order can call this function
        require(msg.sender == order.seller.sellerAddress, "Only the seller can confirm delivery");

        // Ensure the order is still pending
        require(order.status == OrderStatus.Pending, "Order must be in pending state");

        // Set the delivery timestamp based on the period specified by the seller
        order.deliveryTimestamp = block.timestamp + (deliveryPeriodInDays * 1 days);

        // Update the order status to Confirmed
        order.status = OrderStatus.Confirmed;

        // Emit event for delivery confirmation
        emit DeliveryConfirmed(orderID, deliveryPeriodInDays);
    }

    // Function for the buyer to send money into the contract (after seller confirms)
    function fundOrder(uint orderID) public payable {
        Order storage order = orders[orderID];

        // Ensure the buyer is the one funding the order
        require(msg.sender == order.buyer.buyerAddress, "Only the buyer can fund the order");

        // Ensure the order has been confirmed by the seller
        require(order.status == OrderStatus.Confirmed, "Order must be confirmed by the seller first");

        // Ensure the buyer sends the exact order amount
        require(msg.value == order.orderAmount, "Buyer must transfer the exact order amount");

        // Lock the funds in escrow
        order.escrowBalance = msg.value;

        // Update buyer's total spent
        order.buyer.totalSpent = msg.value;

        // Emit event for funds being locked
        emit FundsLocked(orderID, msg.value);
    }

    // Function to apply the 2% penalty for every 24 hours after delivery deadline
    function applyPenalty(uint orderID) public {
        Order storage order = orders[orderID];

        // Ensure the delivery deadline has passed
        require(block.timestamp > order.deliveryTimestamp, "Delivery deadline has not passed yet");

        // Calculate how many 24-hour intervals have passed since the delivery timestamp
        uint timePassed = block.timestamp - order.deliveryTimestamp;
        uint penaltyIntervals = timePassed / penaltyInterval;

        // Calculate the penalty (2% for each interval)
        uint penaltyAmount = (order.orderAmount * penaltyRate * penaltyIntervals) / 100;

        // Ensure that the penalty doesn't exceed the escrow balance
        if (penaltyAmount > order.escrowBalance) {
            penaltyAmount = order.escrowBalance;
        }

        // Deduct the penalty from the escrow balance and add it to the buyer's refund balance
        order.escrowBalance -= penaltyAmount;
        order.buyer.penaltyAmount += penaltyAmount;
        order.buyer.refundBalance += penaltyAmount;

        // Emit event for penalty application
        emit PenaltyApplied(orderID, penaltyAmount, order.buyer.refundBalance);
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

    // Additional functions and logic to handle disputes and fund release will be added later
}
