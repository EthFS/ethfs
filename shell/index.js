const fs = require('fs')
const contract = require('truffle-contract')
const HDWalletProvider = require('truffle-hdwallet-provider')
const cmds = require('./cmds')
const {dec} = require('./utils/enc')
const {create: createPrompt, prompt} = require('./utils/prompt')
const completer = require('./utils/completer')

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  let url = 'http://localhost:8545'
  if (process.argv[2]) {
    url = `https://${process.argv[2]}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
  }
  Kernel.setProvider(new HDWalletProvider(fs.readFileSync('.secret').toString().trim(), url))
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await Kernel.deployed()
  createPrompt(completer.bind(null, kernel))
  while (true) {
    const cwd = dec(await kernel.getcwd())
    const args = (await prompt(`${cwd}> `)).split(/\s+/).filter(x => x.length)
    const cmd = args.shift()
    try {
      if (cmds[cmd]) {
        await cmds[cmd](Kernel.web3, kernel, cmd, args)
      } else if (cmd === 'exit') {
        break
      } else if (cmd !== undefined) {
        await cmds.exec(Kernel.web3, kernel, cmd, args)
      }
    } catch (e) {
      console.log(e.message);
    }
  }
}

main().catch(console.log).then(process.exit)
