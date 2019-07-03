const FileSystemLib = artifacts.require('FileSystemLib')
const FileSystemLib1 = artifacts.require('FileSystemLib1')
const FileSystemLib2 = artifacts.require('FileSystemLib2')
const FileSystemDisk = artifacts.require('FileSystemDisk')
const Kernel = artifacts.require('KernelImpl')
const SetupDirs = artifacts.require('SetupDirs')

const Copy = artifacts.require('Copy')
const Move = artifacts.require('Move')
const DeleteTree = artifacts.require('DeleteTree')
const HelloWorld = artifacts.require('HelloWorld')

module.exports = async deployer => {
  await deployer.deploy(FileSystemLib)
  await deployer.link(FileSystemLib, [FileSystemLib1, FileSystemLib2, FileSystemDisk])
  await deployer.deploy(FileSystemLib1)
  await deployer.deploy(FileSystemLib2)
  await deployer.link(FileSystemLib1, FileSystemDisk)
  await deployer.link(FileSystemLib2, FileSystemDisk)
  await deployer.deploy(FileSystemDisk)
  await deployer.deploy(Kernel, FileSystemDisk.address)
  await deployer.deploy(SetupDirs, Kernel.address)
  await deployer.deploy(Copy, Kernel.address)
  await deployer.deploy(Move, Kernel.address)
  await deployer.deploy(DeleteTree, Kernel.address)
  await deployer.deploy(HelloWorld, Kernel.address)
}
