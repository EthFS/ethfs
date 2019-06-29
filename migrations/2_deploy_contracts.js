const FileSystem = artifacts.require("FileSystemImpl");
const Kernel = artifacts.require("KernelImpl");

const SetupDirs = artifacts.require("SetupDirs");
const TestDapp = artifacts.require("TestDapp");

const Copy = artifacts.require("Copy");
const Move = artifacts.require("Move");

module.exports = function(deployer) {
  deployer.deploy(FileSystem)
    .then(() => deployer.deploy(Kernel, FileSystem.address))
    .then(() => deployer.deploy(SetupDirs, Kernel.address))
    .then(() => deployer.deploy(TestDapp, Kernel.address))
    .then(() => deployer.deploy(Copy, Kernel.address))
    .then(() => deployer.deploy(Move, Kernel.address))
};
