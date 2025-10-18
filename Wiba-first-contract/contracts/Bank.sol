// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Simple Fintech Wallet System
/// @notice Users can create accounts, deposit, withdraw, and transfer ETH to other users within the contract.
contract Fintech {
    /// @dev Struct to represent a user account
    struct Account {
        address owner;   // Owner address
        uint256 balance; // ETH balance stored in the contract
        bool exists;     // Whether account exists
    }

    /// @dev Mapping from user address to their account
    mapping(address => Account) private accounts;

    /// @notice Event emitted when a new account is created
    event AccountCreated(address indexed owner);

    /// @notice Event emitted when user deposits ETH
    event Deposit(address indexed owner, uint256 amount);

    /// @notice Event emitted when user withdraws ETH
    event Withdrawal(address indexed owner, uint256 amount);

    /// @notice Event emitted when user transfers ETH to another account
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice Create a new account
    function createAccount() external {
        require(!accounts[msg.sender].exists, "Account already exists for this user");

        accounts[msg.sender] = Account({
            owner: msg.sender,
            balance: 0,
            exists: true
        });

        emit AccountCreated(msg.sender);
    }

    /// @notice Deposit  into your account
    function deposit() external payable {
        require(accounts[msg.sender].exists, "No account found");
        require(msg.value > 0, "Deposit must be greater than zero");

        accounts[msg.sender].balance += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw ETH from your account
    /// @param amount The amount of ETH (in wei) to withdraw
    function withdraw(uint256 amount) external {
        Account storage acc = accounts[msg.sender];
        require(acc.exists, "No account found");
        require(amount > 0, "Invalid amount");
        require(acc.balance >= amount, "Insufficient balance");

        acc.balance -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(msg.sender, amount);
    }

    /// @notice Transfer funds from your account to another user's account
    /// @param recipient The address of the recipient
    /// @param amount The amount of ETH (in wei) to transfer
    function transfer(address recipient, uint256 amount) external {
        require(recipient != address(0), "Invalid recipient");
        require(accounts[msg.sender].exists, "Sender has no account");
        require(accounts[recipient].exists, "Recipient has no account");

        Account storage sender = accounts[msg.sender];
        Account storage receiver = accounts[recipient];

        require(sender.balance >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be > 0");

        sender.balance -= amount;
        receiver.balance += amount;

        emit Transfer(msg.sender, recipient, amount);
    }

    /// @notice Get your fintech account balance
    function getBalance() external view returns (uint256) {
        require(accounts[msg.sender].exists, "No account found");
        return accounts[msg.sender].balance;
    }

    /// @notice Fallback function to accept ETH (for safety)
    receive() external payable {
        revert("Use deposit() to add funds");
    }
}
