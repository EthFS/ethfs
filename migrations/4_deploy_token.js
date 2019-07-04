const {asciiToHex} = require('web3-utils')

const Kernel = artifacts.require('KernelImpl')
const Token = artifacts.require('Token')
const SimpleToken = artifacts.require('SimpleToken')

module.exports = async deployer => {
  const kernel = await Kernel.deployed()
  await kernel.mkdir(asciiToHex('/token'))
  await deployer.deploy(Token, Kernel.address)
  await deployer.deploy(SimpleToken, 21e6)
  await kernel.install(SimpleToken.address, asciiToHex('/token/simple'))
}
