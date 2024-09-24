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

});
