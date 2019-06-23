const Kernel = artifacts.require('KernelImpl')
const TestDapp = artifacts.require('TestDapp')

module.exports = async callback => {
  const kernel = await Kernel.deployed()
  const testDapp = await TestDapp.deployed()
  await testDapp.main(kernel.address)
  callback()
}
