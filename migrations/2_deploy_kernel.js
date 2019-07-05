const FileSystemLib = artifacts.require('FileSystemLib')
const FileSystemLib1 = artifacts.require('FileSystemLib1')
const FileSystemLib2 = artifacts.require('FileSystemLib2')
const FileSystemDisk = artifacts.require('FileSystemDisk')
const KernelLib = artifacts.require('KernelLib')
const Kernel = artifacts.require('KernelImpl')

module.exports = async deployer => {
  await deployer.deploy(FileSystemLib)
  await deployer.link(FileSystemLib, [FileSystemLib1, FileSystemLib2, FileSystemDisk])
  await deployer.deploy(FileSystemLib1)
  await deployer.deploy(FileSystemLib2)
  await deployer.link(FileSystemLib1, FileSystemDisk)
  await deployer.link(FileSystemLib2, FileSystemDisk)
  await deployer.deploy(FileSystemDisk)
  await deployer.deploy(KernelLib)
  await deployer.link(KernelLib, Kernel)
  await deployer.deploy(Kernel, FileSystemDisk.address)
}
