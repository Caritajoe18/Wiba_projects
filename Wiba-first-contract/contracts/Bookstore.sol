```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Importing OpenZeppelin's ReentrancyGuard to protect against reentrancy attacks
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Bookstore
/// @notice A simple bookstore where the owner can add/update books, 
///         and users can purchase them with ETH.
contract Bookstore is ReentrancyGuard {
    // Address of the contract owner
    address public owner;

    // Tracks the next available book ID for new books
    uint256 private nextBookId;

    // Structure defining a book's properties
    struct Book {
        uint256 id;       // Unique identifier
        string title;     // Book title
        string author;    // Author name
        uint256 price;    // Price in wei (1 ETH = 1e18 wei)
        uint256 stock;    // Number of copies available
        bool exists;      // Used to verify book existence
    }

    // Mapping from book ID to Book struct
    mapping(uint256 => Book) private books;

    // Tracks total number of copies sold for each book
    mapping(uint256 => uint256) public sales;

    // Event emitted when a new book is added
    event BookAdded(uint256 indexed bookId, string title, string author, uint256 price, uint256 stock);

    // Event emitted when book metadata or price is updated
    event BookUpdated(uint256 indexed bookId, string title, string author, uint256 price, uint256 stock);

    // Event emitted when a book is restocked
    event BookRestocked(uint256 indexed bookId, uint256 addedStock, uint256 newStock);

    // Event emitted when a book is purchased
    event BookPurchased(address indexed buyer, uint256 indexed bookId, uint256 quantity, uint256 totalPrice);

    // Event emitted when the owner withdraws ETH from the contract
    event Withdrawn(address indexed owner, uint256 amount);

    // Restricts function execution to only the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    // Constructor sets the deployer as the owner and initializes book ID counter
    constructor() {
        owner = msg.sender;
        nextBookId = 1;
    }

    /// @notice Adds a new book to the store (only owner can call)
    function addBook(
        string calldata title, 
        string calldata author, 
        uint256 priceWei, 
        uint256 stock
    ) external onlyOwner {
        require(priceWei > 0, "price must be > 0");
        require(bytes(title).length > 0, "title required");
        require(stock > 0, "stock must be > 0");

        uint256 bookId = nextBookId++;

        books[bookId] = Book({
            id: bookId,
            title: title,
            author: author,
            price: priceWei,
            stock: stock,
            exists: true
        });

        emit BookAdded(bookId, title, author, priceWei, stock);
    }

    /// @notice Updates book title, author, or price (only owner)
    function updateBook(
        uint256 bookId, 
        string calldata title, 
        string calldata author, 
        uint256 priceWei
    ) external onlyOwner {
        Book storage b = books[bookId];
        require(b.exists, "book not found");
        require(priceWei > 0, "price must be > 0");

        b.title = title;
        b.author = author;
        b.price = priceWei;

        emit BookUpdated(bookId, title, author, priceWei, b.stock);
    }

    /// @notice Adds more copies of an existing book (only owner)
    function restockBook(uint256 bookId, uint256 amount) external onlyOwner {
        require(amount > 0, "amount > 0");
        Book storage b = books[bookId];
        require(b.exists, "book not found");

        b.stock += amount;
        emit BookRestocked(bookId, amount, b.stock);
    }

    /// @notice Allows users to purchase a book with ETH (protected from reentrancy)
    function buyBook(uint256 bookId, uint256 quantity) external payable nonReentrant {
        require(quantity > 0, "quantity > 0");

        Book storage b = books[bookId];
        require(b.exists, "book not found");
        require(b.stock >= quantity, "not enough stock");

        uint256 totalPrice = b.price * quantity;
        require(msg.value >= totalPrice, "insufficient payment");

        // Reduce stock and update sales count
        b.stock -= quantity;
        sales[bookId] += quantity;

        // Refund any excess ETH sent by mistake
        if (msg.value > totalPrice) {
            uint256 refund = msg.value - totalPrice;
            (bool sent, ) = msg.sender.call{value: refund}("");
            require(sent, "refund failed");
        }

        emit BookPurchased(msg.sender, bookId, quantity, totalPrice);
    }

    /// @notice Withdraws all ETH balance to the owner (protected from reentrancy)
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "no balance");

        (bool sent, ) = owner.call{value: balance}("");
        require(sent, "withdraw failed");

        emit Withdrawn(owner, balance);
    }

    /// @notice Returns details of a single book
    function getBook(uint256 bookId)
        external
        view
        returns (
            uint256 id,
            string memory title,
            string memory author,
            uint256 price,
            uint256 stock,
            bool exists
        )
    {
        Book storage b = books[bookId];
        return (b.id, b.title, b.author, b.price, b.stock, b.exists);
    }

    /// @notice Returns an array of books within a given ID range
    function listBooks(uint256 startId, uint256 endId)
        external
        view
        returns (Book[] memory)
    {
        require(startId > 0 && endId >= startId, "invalid range");

        uint256 length = endId - startId + 1;
        Book[] memory result = new Book[](length);

        uint256 idx = 0;
        for (uint256 i = startId; i <= endId; i++) {
            Book storage b = books[i];
            result[idx++] = b;
        }

        return result;
    }

    // Allow the contract to receive ETH directly (e.g., accidental transfers)
    receive() external payable {}
    fallback() external payable {}
}
```
