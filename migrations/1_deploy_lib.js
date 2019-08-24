const FsLib = artifacts.require('FsLib')
const FsLib1 = artifacts.require('FsLib1')
const FsDisk = artifacts.require('FsDisk')
const KernelLib = artifacts.require('KernelLib')
const Kernel = artifacts.require('KernelImpl')

module.exports = async deployer => {
  await deployer.deploy(FsLib)
  await deployer.link(FsLib, [FsLib1, FsDisk])
  await deployer.deploy(FsLib1)
  await deployer.link(FsLib1, FsDisk)
  await deployer.deploy(KernelLib)
  await deployer.link(KernelLib, Kernel)
}
