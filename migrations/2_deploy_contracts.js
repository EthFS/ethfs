const FileSystem = artifacts.require("FileSystemImpl");
const Kernel = artifacts.require("KernelImpl");
const SetupDirs = artifacts.require("SetupDirs");

const Copy = artifacts.require("Copy");
const Move = artifacts.require("Move");
const DeleteTree = artifacts.require("DeleteTree");
const HelloWorld = artifacts.require("HelloWorld");

module.exports = function(deployer) {
  deployer.deploy(FileSystem)
    .then(() => deployer.deploy(Kernel, FileSystem.address))
    .then(() => deployer.deploy(SetupDirs, Kernel.address))
    .then(() => deployer.deploy(Copy, Kernel.address))
    .then(() => deployer.deploy(Move, Kernel.address))
    .then(() => deployer.deploy(DeleteTree, Kernel.address))
    .then(() => deployer.deploy(HelloWorld, Kernel.address))
};
