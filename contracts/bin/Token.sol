pragma solidity >= 0.5.8;

import 'openzeppelin-solidity/contracts/token/ERC20/IERC20.sol';
import '../interface/App.sol';

contract Token is App {
  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length >= 1, 'Usage: token send <path to token> <target>');
    bytes memory arg = new bytes(argi[0]);
    for (uint i; i < arg.length; i++) arg[i] = args[i];
    bytes4 cmd = bytes4(keccak256(arg));
    if (cmd == bytes4(keccak256('send'))) {
      require(argi.length == 3, 'Usage: token send <path to token> <target>');
      arg = new bytes(argi[1] - argi[0]);
      for (uint i; i < arg.length; i++) arg[i] = args[argi[0]+i];
      bytes memory tokenAddress = arg;
      arg = new bytes(argi[2] - argi[1]);
      for (uint i; i < arg.length; i++) arg[i] = args[argi[1]+i];
      bytes memory target = arg;
      (FileSystem.FileType fileType,,,,, address token,,) = kernel.stat(tokenAddress);
      require(fileType == FileSystem.FileType.Contract, 'File is not a contract');
      (,,,,, address recipient,,) = kernel.stat(target);
      uint amount = 100;
      require(IERC20(token).transfer(recipient, amount), 'Transfer failed');
    } else {
      revert('Usage: token send <path to token> <target>');
    }
  }
}
