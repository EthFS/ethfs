const {asciiToHex} = require('web3-utils')

const Kernel = artifacts.require('KernelImpl')
const Copy = artifacts.require('Copy')
const Move = artifacts.require('Move')
const DeleteTree = artifacts.require('DeleteTree')
const HelloWorld = artifacts.require('HelloWorld')

module.exports = async deployer => {
  await deployer.deploy(Copy)
  await deployer.deploy(Move)
  await deployer.deploy(DeleteTree)
  await deployer.deploy(HelloWorld)
  const kernel = await Kernel.deployed()
  try {
    await kernel.mkdir(asciiToHex('/bin'))
  } catch (e) {}
  await kernel.install(Copy.address, asciiToHex('/bin/cp'))
  await kernel.install(Move.address, asciiToHex('/bin/mv'))
  await kernel.install(DeleteTree.address, asciiToHex('/bin/deltree'))
  await kernel.install(HelloWorld.address, asciiToHex('/bin/hello_world'))
}
