const fs = require('fs')
const Web3 = require('web3')
const contract = require('truffle-contract')
const HDWalletProvider = require('truffle-hdwallet-provider')
const cmds = require('./cmds')
const prompt = require('./utils/prompt')

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  let provider = new Web3.providers.HttpProvider('http://localhost:7545')
  if (process.argv[2]) {
    provider = new HDWalletProvider(
      fs.readFileSync('.secret').toString().trim(),
      `https://${process.argv[2]}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
    )
  }
  Kernel.setProvider(provider)
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await Kernel.deployed()
  while (true) {
    const args = (await prompt('> ')).split(/\s+/).filter(x => x.length)
    const cmd = args.shift()
    try {
      if (cmds[cmd]) {
        await cmds[cmd](kernel, cmd, args)
      } else {
        await exec(kernel, cmd, args)
      }
    } catch (e) {
      console.log(e.message);
    }
  }
}

main().catch(console.log).then(process.exit)
