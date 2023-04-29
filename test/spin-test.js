const { expect } = require("chai");
const { ethers } = require('hardhat');

const SUPER_ADMIN_ADDRESS = "0x871091a42C953703A1ba0220282788Ea2300fA94"
const ADMIN_ADDRESS1 = "0x871091a42C953703A1ba0220282788Ea2300fA94"
const ADDRESSES = [
    
]
describe("Spin contract", function () {
    let hardhatSpin;
    before(async () => {
        const [owner] = await ethers.getSigners();
        const Spin = await ethers.getContractFactory("Spin");
        hardhatSpin = await Spin.deploy(SUPER_ADMIN_ADDRESS);
        await hardhatSpin.deployed();
    })

    it("admin create", async function () {
        hardhatSpin.adminCreate(ADMIN_ADDRESS1, "10", true);
        hardhatSpin.adminCreate(ADMIN_ADDRESS1, "20", false);
    });
});