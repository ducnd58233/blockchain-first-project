// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Marketplace is Ownable {
  using Counters for Counters.Counter;
  using EnumerableSet for EnumerableSet.AddressSet;

  struct Order {
    address seller;
    address buyer;
    uint256 tokenId;
    address paymentToken; // can be purchase by another token
    uint256 price;
  }

  Counters.Counter private _orderIdCount;
  IERC721 public immutable nftContract; // init once and only view
  mapping(uint256 => Order) orders;
  uint256 public feeDecimal;
  uint256 public feeRate;
  address public feeRecipient; // address receive fee transaction
  EnumerableSet.AddressSet private _supportedPaymentTokens;

  event OrderAdded(
    uint256 indexed orderId,
    address indexed seller,
    uint256 indexed tokenId,
    address paymentToken,
    uint256 price
  );

  event OrderCancelled(uint256 indexed orderId);

  // event: when have buyer purchase
  event OrderMatched(
    uint256 indexed orderId,
    address indexed seller,
    address indexed buyer,
    uint256 tokenId,
    address paymentToken,
    uint256 price
  );

  event FeeRateUpdated(uint256 feeDecimal, uint256 feeRate);

  modifier onlySupportedPaymentToken(address paymentToken_) {
    require(
      isPaymentTokenSupported(paymentToken_),
      "NFTMarketplace: unsupport payment token"
    );
    _;
  }

  constructor(
    address nftAddress_,
    uint256 feeDecimal_,
    uint256 feeRate_,
    address feeRecipient_
  ) {
    require(
      nftAddress_ != address(0),
      "NFTMarketplace: nftAddress_ is zero address"
    );
    nftContract = IERC721(nftAddress_);
    _updateFeeRecipient(feeRecipient_);
    _updateFeeRate(feeDecimal_, feeRate_);
    _orderIdCount.increment();
  }

  function _updateFeeRecipient(address feeRecipient_) internal {
    require(
      feeRecipient_ != address(0),
      "NFTMarketplace: feeRecipient_ is zero address"
    );
    feeRecipient = feeRecipient_;
  }

  // Only admin can update fee recipient
  function updateFeeRecipient(address feeRecipient_) external onlyOwner {
    _updateFeeRecipient(feeRecipient_);
  }

  function _updateFeeRate(uint256 feeDecimal_, uint256 feeRate_) internal {
    // fee rate needs < 100%
    // e.g: 0.1%: feeRate = 1 & feeDecimal_ = 1
    require(feeRate_ < 10**(feeDecimal_ + 2), "NFTMarketplace: bad fee rate");
    feeDecimal = feeDecimal_;
    feeRate = feeRate_;
    emit FeeRateUpdated(feeDecimal_, feeRate_);
  }

  // Only admin can update fee rate
  function updateFeeRate(uint256 feeDecimal_, uint256 feeRate_)
    external
    onlyOwner
  {
    _updateFeeRate(feeDecimal_, feeRate_);
  }

  function _calculateFee(uint256 orderId_) private view returns (uint256) {
    Order storage _order = orders[orderId_]; // use storage to call instance of struct
    if (feeRate == 0) {
      return 0;
    }
    return (feeRate * _order.price) / 10**(feeDecimal + 2);
  }

  function isSeller(uint256 orderId_, address seller_)
    public
    view
    returns (bool)
  {
    return orders[orderId_].seller == seller_;
  }

  function addPaymentToken(address paymentToken_) external onlyOwner {
    require(
      paymentToken_ != address(0),
      "NFTMarketplace: feeRecipient_ is zero address"
    );
    require(
      _supportedPaymentTokens.add(paymentToken_),
      "NFTMarketplace: already supported"
    );
  }

  function isPaymentTokenSupported(address paymentToken_)
    public
    view
    returns (bool)
  {
    return _supportedPaymentTokens.contains(paymentToken_);
  }

  function addOrder(
    uint256 tokenId_,
    address paymentToken_,
    uint256 price_
  ) public onlySupportedPaymentToken(paymentToken_) {
    require(
      nftContract.ownerOf(tokenId_) == _msgSender(),
      "NFTMarketplace: sender is not owner of token"
    );
    require(
      nftContract.isApprovedForAll(_msgSender(), address(this)) ||
        nftContract.getApproved(tokenId_) == address(this),
      "NFTMarketplace: The contract is unauthorized to manage this token"
    );
    require(price_ > 0, "NFTMarketplace: price must be greater than 0");
    uint256 _orderId = _orderIdCount.current();
    orders[_orderId] = Order(
      _msgSender(), // msg.sender
      address(0),
      tokenId_,
      paymentToken_,
      price_
    );
    _orderIdCount.increment();
    nftContract.transferFrom(_msgSender(), address(this), tokenId_); // approve marketplace use this tokenId
    emit OrderAdded(_orderId, _msgSender(), tokenId_, paymentToken_, price_);
  }

  function cancelOrder(uint256 orderId_) external {
    Order storage _order = orders[orderId_];
    require(_order.buyer == address(0), "NFTMarketplace: buyer must be zero"); // not sold yet
    require(_order.seller == _msgSender(), "NFTMarketplace: must be owner");
    uint256 _tokenId = _order.tokenId;
    delete orders[orderId_];
    nftContract.transferFrom(address(this), _msgSender(), _tokenId); // refund token to owner
    emit OrderCancelled(orderId_);
  }

  function executeOrder(uint256 orderId_) external {
    Order storage _order = orders[orderId_];
    require(_order.price > 0, "NFTMarketplace: order has been canceled");
    require(
      !isSeller(orderId_, _msgSender()),
      "NFTMarketplace: buyer must be different from seller"
    );
    require(_order.buyer == address(0), "NFTMarketplace: buyer must be zero");

    _order.buyer = _msgSender();
    uint256 _feeAmount = _calculateFee(orderId_);
    if (_feeAmount > 0) {
      IERC20(_order.paymentToken).transferFrom(
        _msgSender(),
        feeRecipient,
        _feeAmount
      );
    }
    IERC20(_order.paymentToken).transferFrom(
      _msgSender(),
      _order.seller,
      _order.price - _feeAmount
    );
    nftContract.transferFrom(address(this), _msgSender(), _order.tokenId); // transfer token from seller to buyer
    emit OrderMatched(
      orderId_,
      _order.seller,
      _order.buyer,
      _order.tokenId,
      _order.paymentToken,
      _order.price
    );
  }
}
