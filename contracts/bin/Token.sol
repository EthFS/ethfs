pragma solidity >= 0.5.8;

import 'openzeppelin-solidity/contracts/token/ERC20/IERC20.sol';
import '../interface/App.sol';

contract Token is App {
  function main(Kernel kernel, uint[] calldata argi, bytes calldata args) external returns (uint) {
    require(argi.length >= 1, 'Usage: token send <path to token> <target> <amount>');
    bytes memory p = args;
    uint index = argi[0];
    assembly { p := add(p, index) }
    (bytes memory arg) = abi.decode(p, (bytes));
    bytes4 cmd = bytes4(keccak256(arg));
    if (cmd == bytes4(keccak256('send'))) {
      require(argi.length == 4, 'Usage: token send <path to token> <target> <amount>');
      p = args;
      index = argi[1];
      assembly { p := add(p, index) }
      (bytes memory tokenPath) = abi.decode(p, (bytes));
      p = args;
      index = argi[2];
      assembly { p := add(p, index) }
      (address recipient) = abi.decode(p, (address));
      p = args;
      index = argi[3];
      assembly { p := add(p, index) }
      (uint amount) = abi.decode(p, (uint));
      (FileSystem.FileType fileType,,,,, address token,,) = kernel.stat(tokenPath);
      require(fileType == FileSystem.FileType.Contract, 'File is not a contract');
      require(IERC20(token).transfer(recipient, amount), 'Transfer failed');
    } else {
      revert('Usage: token send <path to token> <target> <amount>');
    }
  }
}
