const KernelImpl = artifacts.require('KernelImpl')

module.exports = async callback => {
  const kernel = await KernelImpl.deployed()
  await kernel.exec(['TestDapp'].map(web3.utils.fromAscii), [])
  callback()
}
