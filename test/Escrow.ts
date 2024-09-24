// test/Escrow.test.ts
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

describe("Escrow", function () {
  // Fixture to deploy the Escrow and MockERC20 contracts
  async function deployEscrowFixture() {
    const [deployer, buyer, seller] = await hre.ethers.getSigners();

    // Deploy a mock ERC20 token (simulating USDC)
    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const mockUSDC = await MockERC20.deploy(ethers.parseUnits("100000", 6)); // Mint 100,000 mock USDC

    // Deploy the Escrow contract
    const Escrow = await hre.ethers.getContractFactory("Escrow");
    const escrow = await Escrow.deploy();
   

    return { escrow, mockUSDC, deployer, buyer, seller };
  }

  describe("Deployment", function () {
    it("Should deploy the Escrow and MockERC20 contracts correctly", async function () {
      const { escrow, mockUSDC, deployer, buyer, seller } = await loadFixture(deployEscrowFixture);

      // Validate contract deployments
      expect(await escrow.getAddress()).to.properAddress;
      expect(await mockUSDC.getAddress()).to.properAddress;

      // Ensure deployer has the mock USDC tokens
      const deployerBalance = await mockUSDC.balanceOf(deployer.address);
      expect(deployerBalance).to.equal(ethers.parseUnits("100000", 6)); // 100,000 mock USDC
    });
  });

  describe("createOrder", function () {
    it("Should revert if the seller address is the zero address", async function () {
      const { escrow, buyer } = await loadFixture(deployEscrowFixture);

      // Attempt to create an order with address(0) as the seller and expect it to revert
      await expect(
        escrow.connect(buyer).createOrder(ethers.ZeroAddress, ethers.parseUnits("100", 6), 1)
      ).to.be.revertedWith("Invalid seller address");
    });

    it("Should revert if the order amount is zero", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Attempt to create an order with zero order amount and expect it to revert
      await expect(
        escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("0", 6), 1)
      ).to.be.revertedWith("Order amount must be greater than zero");
    });

    it("Should revert if the quantity is zero", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Attempt to create an order with a quantity of zero and expect it to revert
      await expect(
        escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("100", 6), 0)
      ).to.be.revertedWith("Quantity must be greater than zero");
    });
  });

  describe("confirmOrderBySeller", function () {
    it("Should revert if the caller is not the seller", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Buyer creates an order
      await escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("100", 6), 1);
  
      // Attempt to confirm the order by a non-seller (in this case, the buyer) and expect it to revert
      await expect(
        escrow.connect(buyer).confirmOrderBySeller(1, 5) // 5 days as delivery period
      ).to.be.revertedWith("Only the seller can confirm the order");
    });

    it("Should revert if the order is not in the pending state", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Buyer creates an order
      await escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("100", 6), 1);
  
      // Seller confirms the order (this puts the order in 'SellerConfirmed' state)
      await escrow.connect(seller).confirmOrderBySeller(1, 5); // 5 days delivery period
  
      // Attempt to confirm the order again by the seller and expect it to revert
      await expect(
        escrow.connect(seller).confirmOrderBySeller(1, 5)
      ).to.be.revertedWith("Order must be in pending state");
    });
  });

  describe("fundOrder", function () {
    it("Should revert if the caller is not the buyer", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Buyer creates an order
      await escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("100", 6), 1);
  
      // Attempt to fund the order by the seller (instead of the buyer) and expect it to revert
      await expect(
        escrow.connect(seller).fundOrder(1, { value: ethers.parseUnits("100", 6) })
      ).to.be.revertedWith("Only the buyer can fund the order");
    });

    it("Should revert if the order is not confirmed by the seller", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Buyer creates an order
      await escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("100", 6), 1);
  
      // Attempt to fund the order before the seller confirms it and expect it to revert
      await expect(
        escrow.connect(buyer).fundOrder(1, { value: ethers.parseUnits("100", 6) })
      ).to.be.revertedWith("Order must be confirmed by the seller first");
    });

    it("Should revert if the buyer does not transfer the exact order amount", async function () {
      const { escrow, buyer, seller } = await loadFixture(deployEscrowFixture);
  
      // Buyer creates an order
      await escrow.connect(buyer).createOrder(seller.address, ethers.parseUnits("100", 6), 1);
  
      // Seller confirms the order
      await escrow.connect(seller).confirmOrderBySeller(1, 5);
  
      // Buyer attempts to fund the order but sends an incorrect amount
      await expect(
        escrow.connect(buyer).fundOrder(1, { value: ethers.parseUnits("50", 6) }) // Sending 50 instead of 100
      ).to.be.revertedWith("Buyer must transfer the exact order amount");
    });
    
  });
  
  

});
