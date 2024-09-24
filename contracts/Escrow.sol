// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Escrow {

    // Struct for tracking buyer information
    struct Buyer {
        address buyerAddress;
        uint totalSpent;
        bool hasConfirmedReceipt;
        uint refundBalance;
        uint penaltyAmount;
    }

    // Struct for tracking seller information
    struct Seller {
        address sellerAddress;
        uint totalEarned;
        bool hasDelivered;
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
    enum OrderStatus { Pending, SellerConfirmed, BuyerFunded, Delivered, BuyerConfirmed, Released, Refunded, cancelled }

    // Mapping to store orders by ID
    mapping(uint => Order) public orders;

    // Counter for generating unique order IDs
    uint public orderCounter;

    // Penalty constants
    uint public constant penaltyRate = 2; // 2% penalty per 24 hours
    uint public constant penaltyInterval = 86400; // 24 hours in seconds
    uint public constant cancellationFee = 5; // 5% cancellation fee for deposited orders


    // Events for order-related actions
    event OrderCreated(uint indexed orderID, address indexed buyer, address indexed seller, uint orderAmount, uint quantity);
    event SellerConfirmed(uint indexed orderID, uint deliveryPeriod);
    event BuyerFunded(uint indexed orderID, uint amountLocked);
    event OrderDeliveredBySeller(uint indexed orderID);
    event ReceiptConfirmedByBuyer(uint indexed orderID);
    event FundsReleased(uint indexed orderID, uint amountReleased, uint penaltyDeducted);
    event OrderCanceled(uint indexed orderID, uint refundAmount, uint cancellationFee);


    // Function to create a new order (buyer creates the order)
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
            hasConfirmedReceipt: false,
            refundBalance: 0,
            penaltyAmount: 0
        });

        Seller memory newSeller = Seller({
            sellerAddress: _sellerAddress,
            totalEarned: 0,
            hasDelivered: false,
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

    // Function for the seller to confirm availability and delivery date
    function confirmOrderBySeller(uint orderID, uint deliveryPeriodInDays) public {
        Order storage order = orders[orderID];

        // Ensure only the seller of the order can call this function
        require(msg.sender == order.seller.sellerAddress, "Only the seller can confirm the order");

        // Ensure the order is still pending
        require(order.status == OrderStatus.Pending, "Order must be in pending state");

        // Set the delivery timestamp based on the period specified by the seller
        order.deliveryTimestamp = block.timestamp + (deliveryPeriodInDays * 1 days);

        // Update the order status to SellerConfirmed
        order.status = OrderStatus.SellerConfirmed;

        // Emit event for seller confirmation
        emit SellerConfirmed(orderID, deliveryPeriodInDays);


        // Emit event for seller confirmation
        emit SellerConfirmed(orderID, deliveryPeriodInDays);
    }

    // Function for the buyer to send money into the contract after seller confirmation
    function fundOrder(uint orderID) public payable {
        Order storage order = orders[orderID];

        // Ensure the buyer is the one funding the order
        require(msg.sender == order.buyer.buyerAddress, "Only the buyer can fund the order");

        // Ensure the order has been confirmed by the seller
        require(order.status == OrderStatus.SellerConfirmed, "Order must be confirmed by the seller first");

        // Ensure the buyer sends the exact order amount
        require(msg.value == order.orderAmount, "Buyer must transfer the exact order amount");

        // Lock the funds in escrow
        order.escrowBalance = msg.value;

        // Update buyer's total spent
        order.buyer.totalSpent = msg.value;

        // Update the order status to BuyerFunded
        order.status = OrderStatus.BuyerFunded;

        // Emit event for buyer funding
        emit BuyerFunded(orderID, msg.value);
    }

    // Function for the seller to confirm they have delivered the order
    function deliverOrderBySeller(uint orderID) public {
        Order storage order = orders[orderID];

        // Ensure only the seller of the order can call this function
        require(msg.sender == order.seller.sellerAddress, "Only the seller can confirm delivery");

        // Ensure the order has been funded by the buyer
        require(order.escrowBalance > 0, "Order must be funded by the buyer");

        // Mark the order as delivered by the seller
        order.seller.hasDelivered = true;
        order.status = OrderStatus.Delivered;

        // Emit event for delivery confirmation by seller
        emit OrderDeliveredBySeller(orderID);
    }

  // Function for the buyer to confirm receipt and release funds to seller
    function confirmReceiptByBuyer(uint orderID) public {
        Order storage order = orders[orderID];

        // Ensure only the buyer of the order can call this function
        require(msg.sender == order.buyer.buyerAddress, "Only the buyer can confirm receipt");

        // Ensure the seller has confirmed delivery
        require(order.status == OrderStatus.Delivered, "Seller must confirm delivery first");

        // Apply penalty if the seller delivered late
        applyPenalty(orderID);

        // Calculate the amount to be sent to the seller (after penalties)
        uint amountToSeller = order.escrowBalance - order.buyer.penaltyAmount;

        // Transfer the funds to the seller
        payable(order.seller.sellerAddress).transfer(amountToSeller);

        // Mark the order as fully processed and funds released
        order.status = OrderStatus.Released;
        order.seller.finalAmountToReceive = amountToSeller;

        // Emit event for receipt confirmation by buyer and fund release
        emit ReceiptConfirmedByBuyer(orderID);
        emit FundsReleased(orderID, amountToSeller, order.buyer.penaltyAmount);
    }

    // Function to apply the 2% penalty for every 24 hours after delivery deadline
    function applyPenalty(uint orderID) internal {
        Order storage order = orders[orderID];

        // Ensure the delivery deadline has passed
        if (block.timestamp > order.deliveryTimestamp) {
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
        }
    }

    // Function to cancel the order
        function cancelOrder(uint orderID) public {
            Order storage order = orders[orderID];

            // Only the buyer can cancel the order
            require(msg.sender == order.buyer.buyerAddress, "Only the buyer can cancel the order");

            // Ensure the order is not already canceled, delivered, or completed
            require(order.status != OrderStatus.Delivered && order.status != OrderStatus.Released && order.status != OrderStatus.Canceled, "Order cannot be canceled at this stage");

            uint refundAmount;
            uint fee = 0;

            // Check if the buyer has funded the contract
            if (order.escrowBalance == 0) {
                // Case 1: Buyer cancels before funding the contract (no cancellation fee)
                refundAmount = 0; // No funds were deposited yet, so no refund.
            } else {
                // Case 2: Buyer cancels after funding the contract (5% cancellation fee)
                fee = (order.escrowBalance * cancellationFee) / 100; // 5% of the deposited amount
                refundAmount = order.escrowBalance - fee;

                // Transfer the fee to the seller
                payable(order.seller.sellerAddress).transfer(fee);

                // Refund the remaining amount to the buyer
                payable(order.buyer.buyerAddress).transfer(refundAmount);
            }

            // Mark the order as canceled
            order.status = OrderStatus.Canceled;

            // Emit event for order cancellation
            emit OrderCanceled(orderID, refundAmount, fee);
        }


}
