// import { expect } from "chai";
// import { network } from "hardhat";

// const { ethers } = await network.connect();

// describe("Bookstore", function () {
//   let bookstore;
//   let owner, alice, bob;

//   beforeEach(async function () {
//     [owner, alice, bob] = await ethers.getSigners();
//     const Bookstore = await ethers.getContractFactory("Bookstore");
//     bookstore = await Bookstore.deploy();
//     await bookstore.deployed();
//   });

//   it("owner can add and update book, buyers can purchase", async function () {
//     // add a book: price 0.01 ETH, stock 10
//     const price = ethers.utils.parseEther("0.01");
//     await bookstore.connect(owner).addBook("1984", "George Orwell", price, 10);

//     // get book
//     const book = await bookstore.getBook(1);
//     expect(book.id).to.equal(1);
//     expect(book.title).to.equal("1984");

//     // purchase 2 copies by alice
//     const qty = 2;
//     const total = price.mul(qty);
//     await bookstore.connect(alice).buyBook(1, qty, { value: total });

//     // stock should reduce
//     const after = await bookstore.getBook(1);
//     expect(after.stock).to.equal(8);

//     // try overpay and get refund: bob sends extra
//     const qty2 = 1;
//     const total2 = price.mul(qty2);
//     const overpay = total2.add(ethers.utils.parseEther("0.005"));
//     const aliceBalanceBefore = await bob.getBalance();
//     const tx = await bookstore.connect(bob).buyBook(1, qty2, { value: overpay });
//     const receipt = await tx.wait();

//     // withdraw by owner
//     const contractBalance = await ethers.provider.getBalance(bookstore.address);
//     expect(contractBalance).to.equal(price.mul(3)); // 2 + 1 purchases
//     // withdraw
//     await bookstore.connect(owner).withdraw();
//     const newContractBalance = await ethers.provider.getBalance(bookstore.address);
//     expect(newContractBalance).to.equal(0);
//   });

//   it("prevents purchase when insufficient funds or stock", async function () {
//     const price = ethers.utils.parseEther("0.02");
//     await bookstore.connect(owner).addBook("Clean Code", "Robert Martin", price, 1);

//     // not enough ETH
//     await expect(
//       bookstore.connect(alice).buyBook(1, 1, { value: ethers.utils.parseEther("0.01") })
//     ).to.be.revertedWith("insufficient payment");

//     // buy the only copy
//     await bookstore.connect(alice).buyBook(1, 1, { value: price });

//     // now stock is 0
//     await expect(
//       bookstore.connect(bob).buyBook(1, 1, { value: price })
//     ).to.be.revertedWith("not enough stock");
//   });
// });
