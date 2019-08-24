pragma solidity >= 0.5.8;

import '../interface/Kernel.sol';
import './KernelLib.sol';

contract KernelImpl is Kernel {
  using KernelLib for KernelLib.KernelArea;
  KernelLib.KernelArea m_kernelArea;

  constructor(FileSystem fileSystem) public {
    m_kernelArea.init(fileSystem);
  }

  function result() external view returns (uint) {
    return m_kernelArea.result();
  }

  function open(bytes calldata path, uint flags) external returns (uint) {
    return m_kernelArea.open(path, flags);
  }

  function readkey(uint fd, uint index) external view returns (bytes memory) {
    return m_kernelArea.readkey(fd, index);
  }

  function readkeyPath(bytes calldata path, uint index) external view returns (bytes memory) {
    return m_kernelArea.readkeyPath(path, index);
  }

  function read(uint fd, bytes calldata key) external view returns (bytes memory) {
    return m_kernelArea.read(fd, key);
  }

  function readPath(bytes calldata path, bytes calldata key) external view returns (bytes memory) {
    return m_kernelArea.readPath(path, key);
  }

  function write(uint fd, bytes calldata key, bytes calldata value) external {
    m_kernelArea.write(fd, key, value);
  }

  function truncate(uint fd, bytes calldata key, uint len) external {
    m_kernelArea.truncate(fd, key, len);
  }

  function clear(uint fd, bytes calldata key) external {
    m_kernelArea.clear(fd, key);
  }

  function close(uint fd) external {
    m_kernelArea.close(fd);
  }

  function link(bytes calldata source, bytes calldata target) external {
    m_kernelArea.link(source, target);
  }

  function unlink(bytes calldata path) external {
    m_kernelArea.unlink(path);
  }

  function symlink(bytes calldata source, bytes calldata target) external {
    m_kernelArea.symlink(source, target);
  }

  function readlink(bytes calldata path) external view returns (bytes memory) {
    return m_kernelArea.readlink(path);
  }

  function move(bytes calldata source, bytes calldata target) external {
    m_kernelArea.move(source, target);
  }

  function copy(bytes calldata source, bytes calldata target) external {
    m_kernelArea.copy(source, target);
  }

  function chown(bytes calldata path, address owner, address group) external {
    m_kernelArea.chown(path, owner, group);
  }

  function chmod(bytes calldata path, uint16 mode) external {
    m_kernelArea.chmod(path, mode);
  }

  function getcwd() external view returns (bytes memory) {
    return m_kernelArea.getcwd();
  }

  function chdir(bytes calldata path) external {
    m_kernelArea.chdir(path);
  }

  function mkdir(bytes calldata path) external {
    m_kernelArea.mkdir(path);
  }

  function rmdir(bytes calldata path) external {
    m_kernelArea.rmdir(path);
  }

  function stat(bytes calldata path) external view returns (FileSystem.FileType fileType, uint16 mode, uint ino, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    return m_kernelArea.stat(path);
  }

  function lstat(bytes calldata path) external view returns (FileSystem.FileType fileType, uint16 mode, uint ino, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    return m_kernelArea.lstat(path);
  }

  function fstat(uint fd) external view returns (FileSystem.FileType fileType, uint16 mode, uint ino, uint links, address owner, address group, uint entries, uint size, uint lastModified) {
    return m_kernelArea.fstat(fd);
  }
}
