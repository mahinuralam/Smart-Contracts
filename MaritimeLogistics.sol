// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

contract MaritimeLogistics {
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
        bool paid;
        bool locked;
        uint amount;
    }

    struct ShippingInfo {
        uint productId;
        string logisticsInfo;
        bool exportApplied;
        bool exportApproved;
        bool importApplied;
        bool importApproved;
    }

    mapping(uint => Product) public products;
    mapping(address => uint) public pendingRefunds;
    mapping(uint => mapping(address => BuyerRequest)) public buyerRequests;
    mapping(uint => mapping(address => PaymentStatus)) public paymentStatuses;
    mapping(uint => mapping(address => ShippingInfo)) public shippingInfos;

    event ProductListed(uint productId, string name, uint price, address seller);
    event PurchaseRequested(uint productId, address buyer);
    event PurchaseApproved(uint productId, address buyer);
    event PaymentMade(uint productId, address buyer, uint amount);
    event ProductShipped(uint productId);
    event ProductReceived(uint productId, address buyer);
    event RefundIssued(uint productId, address buyer, uint amount);
    event ExportClearanceApplied(uint productId, address logistics);
    event ExportClearanceApproved(uint productId, address logistics);
    event ImportClearanceApplied(uint productId, address logistics);
    event ImportClearanceApproved(uint productId, address logistics);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlySeller(uint productId) {
        require(msg.sender == products[productId].seller, "Only the seller can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function listProduct(string memory name, uint price) public {
        productIdCounter++;
        products[productIdCounter] = Product(productIdCounter, name, price, payable(msg.sender), false, false);
        emit ProductListed(productIdCounter, name, price, msg.sender);
    }

    function requestPurchase(uint productId) public {
        require(!products[productId].shipped, "Product has already been shipped");
        require(msg.sender != owner, "Owner cannot buy products");
        buyerRequests[productId][msg.sender] = BuyerRequest(true, false);
        emit PurchaseRequested(productId, msg.sender);
    }

    function approvePurchase(uint productId, address buyer) public onlySeller(productId) {
        require(buyerRequests[productId][buyer].requested, "Purchase request not found");
        buyerRequests[productId][buyer].approved = true;
        emit PurchaseApproved(productId, buyer);
    }

    function payForProduct(uint productId) public payable {
        require(buyerRequests[productId][msg.sender].approved, "Purchase not approved");
        require(msg.value == products[productId].price, "Incorrect payment amount");
        paymentStatuses[productId][msg.sender] = PaymentStatus(true, true, msg.value);
        emit PaymentMade(productId, msg.sender, msg.value);
    }

    function shipProduct(uint productId) public onlySeller(productId) {
        require(products[productId].price == pendingRefunds[msg.sender], "Payment must be locked before shipping");
        products[productId].shipped = true;
        emit ProductShipped(productId);
    }

    function confirmReceipt(uint productId) public {
        require(products[productId].shipped, "Product has not been shipped");
        Product storage product = products[productId];
        product.received = true;
        paymentStatuses[productId][msg.sender].locked = false;
        product.seller.transfer(product.price);
        pendingRefunds[product.seller] -= product.price;
        emit ProductReceived(productId, msg.sender);
    }

    function applyForExportClearance(uint productId, string memory info) public onlySeller(productId) {
        ShippingInfo storage shippingInfo = shippingInfos[productId][msg.sender];
        shippingInfo.exportApplied = true;
        shippingInfo.logisticsInfo = info;
        emit ExportClearanceApplied(productId, msg.sender);
    }

    function approveExportClearance(uint productId, address logistics) public onlyOwner {
        ShippingInfo storage shippingInfo = shippingInfos[productId][logistics];
        require(shippingInfo.exportApplied, "Export clearance not applied for");
        shippingInfo.exportApproved = true;
        emit ExportClearanceApproved(productId, logistics);
    }

    function applyForImportClearance(uint productId, string memory info) public {
        ShippingInfo storage shippingInfo = shippingInfos[productId][msg.sender];
        require(shippingInfo.exportApproved, "Export clearance not approved");
        shippingInfo.importApplied = true;
        shippingInfo.logisticsInfo = info;
        emit ImportClearanceApplied(productId, msg.sender);
    }

    function approveImportClearance(uint productId, address logistics) public onlyOwner {
        ShippingInfo storage shippingInfo = shippingInfos[productId][logistics];
        require(shippingInfo.importApplied, "Import clearance not applied for");
        shippingInfo.importApproved = true;
        emit ImportClearanceApproved(productId, logistics);
    }

    function issueRefund(uint productId, address payable buyer) public onlyOwner {
        require(!products[productId].received, "Product already received");
        uint refundAmount = paymentStatuses[productId][buyer].amount;
        require(refundAmount > 0, "No payment to refund");
        buyer.transfer(refundAmount);
        pendingRefunds[buyer] = 0;
        paymentStatuses[productId][buyer].paid = false;
        emit RefundIssued(productId, buyer, refundAmount);
    }

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    fallback() external payable {
        revert("Call to non-existent function");
    }
}
