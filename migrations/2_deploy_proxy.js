const FsDisk = artifacts.require('FsDisk')
const Kernel = artifacts.require('KernelImpl')

module.exports = async deployer => {
  await deployer.deploy(FsDisk)
  await deployer.deploy(Kernel, FsDisk.address)
}
