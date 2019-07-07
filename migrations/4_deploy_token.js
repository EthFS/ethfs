const {asciiToHex} = require('web3-utils')

const Kernel = artifacts.require('KernelImpl')
const Token = artifacts.require('Token')
const SimpleToken = artifacts.require('SimpleToken')

module.exports = async deployer => {
  await deployer.deploy(Token)
  await deployer.deploy(SimpleToken, 21e6)
  const simpleToken = await SimpleToken.deployed()
  await simpleToken.approve(Token.address, 21e6)
  const kernel = await Kernel.deployed()
  try {
    await kernel.mkdir(asciiToHex('/token'))
  } catch (e) {}
  await kernel.install(Token.address, asciiToHex('/bin/token'))
  await kernel.install(SimpleToken.address, asciiToHex('/token/simple'))
}
