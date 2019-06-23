const FileSystem = artifacts.require("FileSystemImpl");
const Kernel = artifacts.require("KernelImpl");
const TestDapp = artifacts.require("TestDapp");

module.exports = function(deployer) {
  deployer.deploy(FileSystem)
    .then(() => deployer.deploy(Kernel, FileSystem.address));
  deployer.deploy(TestDapp);
};
