// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * ArtGallery.sol
 *
 * - Multi-edition artworks implemented using ERC1155
 * - Artists create artworks (title, price, quantity, category, uri)
 * - Contract mints initial quantity into the contract (marketplace stock)
 * - Buyers purchase (payable) and receive tokens
 * - Artists can update and soft-delete their artwork
 * - Artists can withdraw proceeds
 */

// This extension adds tracking for the total supply of each token ID
// (how many have been minted and burned).
// It also provides helper functions like `totalSupply(id)` and `exists(id)`.
// Very useful when you want to know how many editions of an artwork exist.
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// It provides a safe and clean way to handle counters that can increment, decrement, or reset.
// Useful for auto-incrementing IDs (like artwork IDs) without manual bookkeeping.
import "@openzeppelin/contracts/utils/Counters.sol";

contract ArtGallery is ERC1155Supply, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _artworkIdCounter;

    struct Artwork {
        uint256 id;
        address creator;
        string title;
        string category;
        string uri; // metadata URI for the token id
        uint256 priceWei; // price per edition in wei
        uint256 totalQuantity; // total minted editions
        uint256 available; // stock currently held by marketplace (contract)
        bool deleted; // soft delete
        uint256 createdAt;
        uint256 updatedAt;
    }

    // id -> Artwork
    mapping(uint256 => Artwork) private artworks;
    // creator => withdrawable balance
    mapping(address => uint256) public proceeds;

    // events
    event ArtworkCreated(
        uint256 indexed id,
        address indexed creator,
        string title,
        uint256 priceWei,
        uint256 quantity
    );
    event ArtworkUpdated(uint256 indexed id, address indexed creator);
    event ArtworkDeleted(uint256 indexed id, address indexed creator);
    event ArtworkBought(
        uint256 indexed id,
        address indexed buyer,
        uint256 amount,
        uint256 totalPrice
    );
    event ProceedsWithdrawn(address indexed artist, uint256 amount);

    constructor(string memory defaultURI) ERC1155(defaultURI) {}

    modifier onlyCreator(uint256 id) {
        require(artworks[id].creator == msg.sender, "Not the artwork creator");
        _;
    }

    modifier exists(uint256 id) {
        require(artworks[id].creator != address(0), "Artwork does not exist");
        _;
    }

    /**
     * Create new artwork.
     * Mints `quantity` of token id to the contract itself (marketplace stock).
     */
    function createArtwork(
        string calldata _uri,
        string calldata _title,
        string calldata _category,
        uint256 _priceWei,
        uint256 _quantity
    ) external returns (uint256) {
        require(_quantity > 0, "Quantity must be > 0");
        require(_priceWei > 0, "Price must be > 0");

        _artworkIdCounter.increment();
        uint256 newId = _artworkIdCounter.current();

        artworks[newId] = Artwork({
            id: newId,
            creator: msg.sender,
            title: _title,
            category: _category,
            uri: _uri,
            priceWei: _priceWei,
            totalQuantity: _quantity,
            available: _quantity,
            deleted: false,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        // mint editions to the contract to act as marketplace stock
        _mint(address(this), newId, _quantity, "");
        // set uri for this token id
        _setURIForToken(newId, _uri);

        emit ArtworkCreated(newId, msg.sender, _title, _priceWei, _quantity);
        return newId;
    }

    /**
     * Internal helper to set per-token URI (ERC1155 uses single URI; we override standard URI behavior by storing per-id URIs).
     * We will simply store URIs in the Artwork struct and return via uri(uint256).
     */
    function _setURIForToken(
        uint256 /*id*/,
        string memory /*_uri*/
    ) internal virtual {
        // no-op here because we'll override uri() to fetch from artworks mapping
        // Kept for clarity / extension
    }

    /**
     * Override ERC1155 uri to return the artwork-specific uri if set.
     */
    function uri(uint256 id) public view override returns (string memory) {
        if (artworks[id].creator != address(0)) {
            return artworks[id].uri;
        }
        return super.uri(id);
    }

    /**
     * Update artwork metadata and optionally increase quantity (mint more editions to marketplace stock)
     * Only the creator can update.
     */
    function updateArtwork(
        uint256 id,
        string calldata newUri,
        string calldata newTitle,
        string calldata newCategory,
        uint256 newPriceWei,
        uint256 addQuantity // additional editions to mint (can be zero)
    ) external exists(id) onlyCreator(id) {
        Artwork storage a = artworks[id];
        require(!a.deleted, "Artwork deleted");

        if (bytes(newUri).length > 0) a.uri = newUri;
        if (bytes(newTitle).length > 0) a.title = newTitle;
        if (bytes(newCategory).length > 0) a.category = newCategory;
        if (newPriceWei > 0) a.priceWei = newPriceWei;

        if (addQuantity > 0) {
            a.totalQuantity += addQuantity;
            a.available += addQuantity;
            _mint(address(this), id, addQuantity, "");
        }

        a.updatedAt = block.timestamp;
        emit ArtworkUpdated(id, msg.sender);
    }

    /**
     * Soft-delete an artwork. Tokens that remain owned by marketplace can still be bought,
     * but creator can't update after delete. Alternatively, you can prevent further buying by also requiring available > 0 checks elsewhere.
     */
    function deleteArtwork(uint256 id) external exists(id) onlyCreator(id) {
        Artwork storage a = artworks[id];
        a.deleted = true;
        a.updatedAt = block.timestamp;
        emit ArtworkDeleted(id, msg.sender);
    }

    /**
     * Public buy function. Buyer pays exact amount (priceWei * amount).
     * Transfers tokens from contract stock to buyer and records proceeds for artist.
     */
    function buyArtwork(
        uint256 id,
        uint256 amount
    ) external payable exists(id) {
        require(amount > 0, "Amount must be > 0");
        Artwork storage a = artworks[id];
        require(!a.deleted, "Artwork deleted");
        require(a.available >= amount, "Not enough available stock");

        uint256 totalPrice = a.priceWei * amount;
        require(msg.value == totalPrice, "Incorrect ETH sent");

        // decrement available stock
        a.available -= amount;

        // transfer the token(s) from contract to buyer
        // contract must be approved / safeTransferFrom from itself is fine here
        _safeTransferFrom(address(this), msg.sender, id, amount, "");

        // record proceeds for artist
        proceeds[a.creator] += msg.value;

        emit ArtworkBought(id, msg.sender, amount, totalPrice);
    }

    /**
     * Allow the artist to withdraw accumulated proceeds.
     */
    function withdrawProceeds() external {
        uint256 bal = proceeds[msg.sender];
        require(bal > 0, "No proceeds available");

        proceeds[msg.sender] = 0;
        (bool ok, ) = payable(msg.sender).call{value: bal}("");
        require(ok, "Withdraw transfer failed");

        emit ProceedsWithdrawn(msg.sender, bal);
    }

    /**
     * Helper getters
     */
    function getArtwork(
        uint256 id
    ) external view exists(id) returns (Artwork memory) {
        return artworks[id];
    }

    /**
     * Return simple list of artwork ids (from 1..current). Useful for frontends to iterate.
     * Note: This returns all IDs; filtering by creator/client should be done off-chain. For large collections, add pagination in further versions.
     */
    function totalArtworks() public view returns (uint256) {
        return _artworkIdCounter.current();
    }

    function listArtworks(
        uint256 startId,
        uint256 endId
    ) external view returns (Artwork[] memory) {
        require(startId >= 1 && startId <= endId, "Invalid range");
        uint256 last = _artworkIdCounter.current();
        if (endId > last) endId = last;
        uint256 len = endId - startId + 1;
        Artwork[] memory arr = new Artwork[](len);
        for (uint256 i = 0; i < len; i++) {
            arr[i] = artworks[startId + i];
        }
        return arr;
    }

    // Admin functions (owner) — e.g., emergency withdraw of tokens or ETH — optional
    function adminWithdrawETH(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero address");
        (bool ok, ) = payable(to).call{value: amount}("");
        require(ok, "transfer failed");
    }

    function adminWithdrawToken(
        address to,
        uint256 id,
        uint256 amount
    ) external onlyOwner {
        _safeTransferFrom(address(this), to, id, amount, "");
    }

    // Receive / fallback
    receive() external payable {}
}
