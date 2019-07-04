const {asciiToHex} = require('web3-utils')

const Kernel = artifacts.require('KernelImpl')
const Copy = artifacts.require('Copy')
const Move = artifacts.require('Move')
const DeleteTree = artifacts.require('DeleteTree')
const HelloWorld = artifacts.require('HelloWorld')

module.exports = async deployer => {
  const kernel = await Kernel.deployed()
  await kernel.mkdir(asciiToHex('/bin'))
  await deployer.deploy(Copy, Kernel.address)
  await deployer.deploy(Move, Kernel.address)
  await deployer.deploy(DeleteTree, Kernel.address)
  await deployer.deploy(HelloWorld, Kernel.address)
}
