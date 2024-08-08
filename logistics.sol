// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract MLogisticsContract {
    address public owner;
    uint public productIdCounter = 0;


    struct Product {
        uint id;
        string name;
        uint price;
        address payable seller;
        bool shipped;
        bool received;
    }


    struct BuyerRequest {
        bool requested;
        bool approved;
    }


    struct PaymentStatus {
        bool requestPayment;
        bool transferPayment;
        bool lockPayment;
        uint amount;
    }


    struct shippingInfo {
        uint productId;
        string productInfo;
    }


    struct productCustomsStatus {
        uint productId;
        bool productExportClearanceApply;
        bool clearanceExportStatus;
        bool productImportClearanceApply;
        bool clearanceImporttStatus;
    }


    mapping(uint => Product) public products;
    mapping(address => uint) public pendingRefunds;
    mapping(uint => mapping(address => BuyerRequest)) public buyerRequests;
    mapping(uint => mapping(address => PaymentStatus)) public buyerPayment;
    mapping(uint => mapping(address => shippingInfo)) public productShippingInfo;
    mapping(uint => mapping(address => productCustomsStatus)) public CustomsStatus;


    event Listed(uint productId, address seller, uint price);
    event Sold(uint productId, address buyer);
    event Shipped(uint productId);
    event Received(uint productId);
    event Refunded(uint productId, address buyer);
    event PaymentTransferred(uint productId, address buyer, uint256 amount);
    event ShippingInfoToLogistics(uint productId, address buyer);




    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }


    constructor() {
        owner = msg.sender;
    }


    function addBuyReuqest(uint productId) public {
        Product storage product = products[productId];
        require(!product.shipped, "Product already shipped");
        require(msg.sender != owner, "Can not buy");
        buyerRequests[productId][msg.sender] = BuyerRequest(true, false);
    }


    function approveBuyerRequest(uint productId, address buyer) public {
        require(msg.sender == products[productId].seller, "Caller is not the seller.");
        require(buyerRequests[productId][buyer].requested, "No request found.");
        buyerRequests[productId][buyer].approved = true;
        buyerPayment[productId][buyer].requestPayment = true;
    }


    function buyerTransferPayment(uint productId) public payable {
        // Ensure there is an approved request for the product
        require(buyerRequests[productId][msg.sender].approved, "Request not approved.");


        // Ensure the payment hasn't been transferred already
        require(!buyerPayment[productId][msg.sender].transferPayment, "Payment already transferred.");


        // Assuming you have a way to get the price of the product, e.g., from the Product struct
        uint256 productPrice = products[productId].price;
        require(msg.value == productPrice, "Incorrect payment amount.");


        // Update the payment status
        buyerPayment[productId][msg.sender].transferPayment = true;
        buyerPayment[productId][msg.sender].lockPayment = true; // You lock the payment by simply not transferring it immediately
        buyerPayment[productId][msg.sender].amount = msg.value; // Record the payment amount


        // Optionally, emit an event to log this action
        emit PaymentTransferred(productId, msg.sender, msg.value);
    }


    // logistics applies for export clearance from customs
    function applyCustomsExportClearance(uint productId) public {
        require(msg.sender != owner, "Can not buy");
        CustomsStatus[productId][msg.sender].productExportClearanceApply = true;
    }


    // Customs Approvies export clearance
    function approveCustomsExportClearance(uint productId, address logistics) public {
        require(msg.sender != owner, "Can not buy");
        require(CustomsStatus[productId][logistics].productExportClearanceApply == true, "Apply for customs clearance");
        CustomsStatus[productId][logistics].clearanceExportStatus = true;
    }


    // logistics applies for import clearance from customs
    function applyCustomsImportClearance(uint productId) public {
        require(msg.sender != owner, "Can not buy");
        require(CustomsStatus[productId][msg.sender].productExportClearanceApply == true, "Apply for customs clearance");
        CustomsStatus[productId][msg.sender].productImportClearanceApply = true;
    }


    // Customs Approvies import clearance
    function approveCustomsImportClearance(uint productId, address logistics, bool clearance) public {
        require(msg.sender != owner, "Can not buy");
        require(CustomsStatus[productId][logistics].productExportClearanceApply == true, "Apply for customs clearance");
        CustomsStatus[productId][logistics].clearanceExportStatus = clearance;
    }




    function listProduct(string memory name, uint price) public {
        productIdCounter++;
        products[productIdCounter] = Product(productIdCounter, name, price, payable(msg.sender), false, false);
        emit Listed(productIdCounter, msg.sender, price);
    }


    // buyer providing shipping information to logistics
    function provideShippingInfoToLogistics(uint productId, string memory Info, address buyer) public {
        require(msg.sender == owner, "Can not buy");
        productShippingInfo[productId][buyer] = shippingInfo(productId, Info);


        emit ShippingInfoToLogistics(productId, msg.sender);
    }


    function confirmShipment(uint productId) public payable {
        Product storage product = products[productId];
        
        require(msg.sender == product.seller, "Not seller");
        require(msg.value == product.price, "Incorrect value");
        require(product.seller != address(0), "Product not found");
        require(!product.shipped, "Product already shipped");

        product.shipped = true;
       
        emit Shipped(productId);

        // Lock funds until confirmation of shipping and receipt
        pendingRefunds[msg.sender] += msg.value;
        emit Sold(productId, msg.sender);
    }


    function confirmReceived(uint productId) public {
        Product storage product = products[productId];
        require(product.shipped, "Product not shipped");
       
        // Transfer funds from buyer to seller
        product.seller.transfer(product.price);
        pendingRefunds[msg.sender] -= product.price;
        product.received = true;
        emit Received(productId);
    }


    function refundBuyer(uint productId) public onlyOwner {
        Product storage product = products[productId];
        require(!product.received, "Product already received");


        address payable buyer = payable(msg.sender);
        uint refundAmount = pendingRefunds[buyer];
        require(refundAmount > 0, "No refund available");


        buyer.transfer(refundAmount);
        pendingRefunds[buyer] = 0;
        emit Refunded(productId, buyer);
    }


    // Function to handle receiving ether when no data is sent
    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }


    // Fallback function to handle all other cases
    fallback() external payable {
        revert("Call to non-existent function");
    }


    // Helper function to check refund balance
    function getRefundBalance(address buyer) public view returns (uint) {
        return pendingRefunds[buyer];
    }
}


