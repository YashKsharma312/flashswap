const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber, utils } = require("ethers");
describe("Uniswap Contract", function () {
  let owner,
   addr1,
    addr2,
     MyToken1,
      MyToken2,
       UniswapV2Contract,
        FactoryContract,
         WethContract,
          UniswapV2ERC20Contract,
           UniswapV2PairContract,
            UniswapV2flashContract;
beforeEach(async function () {
[owner, addr1, addr2] = await ethers.getSigners();
const Token1 = await ethers.getContractFactory("MyToken1");
MyToken1 = await Token1.deploy();
await MyToken1.deployed();
const Token2 = await ethers.getContractFactory("MyToken2");
MyToken2 = await Token2.deploy();
await MyToken2.deployed();
const factory = await ethers.getContractFactory("UniswapV2Factory");
FactoryContract = await factory.deploy(owner.address);
await FactoryContract.deployed();
const weth = await ethers.getContractFactory("weth");
WethContract = await weth.deploy();
await WethContract.deployed();
const UniswapV2ERC20 = await ethers.getContractFactory("UniswapV2ERC20");
UniswapV2ERC20Contract = await UniswapV2ERC20.deploy();
await UniswapV2ERC20Contract.deployed();
const UniswapV2Pair = await ethers.getContractFactory("UniswapV2Pair");
UniswapV2PairContract = await UniswapV2Pair.deploy();
await UniswapV2PairContract.deployed();
const UniswapV2 = await ethers.getContractFactory("UniswapV2Router02");
UniswapV2Contract = await UniswapV2.deploy(FactoryContract.address,WethContract.address);
await UniswapV2Contract.deployed();
const UniswapV2flash = await ethers.getContractFactory("Flashswap");
UniswapV2flashContract = await UniswapV2flash.deploy(MyToken2.address,FactoryContract.address);
await UniswapV2flashContract.deployed();
})
it("adding liquidity", async function () {
  await MyToken1.mint(owner.address,100000);
  await MyToken2.mint(owner.address,100000);
  expect(await MyToken1.balanceOf(owner.address)).to.equal(100000);
  expect(await MyToken2.balanceOf(owner.address)).to.equal(100000);
  await MyToken1.approve(UniswapV2Contract.address, 100000);
  await MyToken2.approve(UniswapV2Contract.address, 100000);
  await UniswapV2Contract.addLiquidity(
    MyToken1.address,
    MyToken2.address,
    10000,
    15000,
    900,
    1400,
    owner.address,
    1769900000
  );
  expect(await MyToken1.balanceOf(owner.address)).to.equal(100000 - 10000);
  expect(await MyToken2.balanceOf(owner.address)).to.equal(100000 - 15000);
  await UniswapV2Contract.swapExactTokensForTokens(
    900,
    1000,
    [MyToken1.address,MyToken2.address],
    owner.address,
    1769000000
  );
  expect(await MyToken1.balanceOf(owner.address)).to.lessThan(100000 - 10000);
  expect(await MyToken2.balanceOf(owner.address)).to.greaterThan(100000 - 15000);

  const fee = Math.round(((100 * 3) / 997)) + 1;
  await MyToken1.transfer(UniswapV2flashContract.address, fee);
  await UniswapV2flashContract.testFlashSwap(MyToken1.address, 100);
  const flashswapBalance = await MyToken1.balanceOf(UniswapV2flashContract.address);
  expect(flashswapBalance.eq(BigNumber.from("0"))).to.be.true;
});
})