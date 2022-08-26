const { expect } = require("chai");
const { ethers } = require("hardhat");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

describe("Hello World", function () {
  const message = "Hello world !!!"
  const message2 = "Bye world !!!"

  it("Should return message correctly", async function () {
    const HelloWorld = await ethers.getContractFactory('HelloWorld') // same name with contract name
    const helloWorld = await HelloWorld.deploy(message) // deploy: call constructor
    await helloWorld.deployed() // wait for contract finished deploy
    expect(await helloWorld.printHelloWorld()).to.be.equal(message)

    await helloWorld.updateMessage(message2)
    expect(await helloWorld.printHelloWorld()).to.be.equal(message2)
  })
})
