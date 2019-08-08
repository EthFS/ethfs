const fs = require('fs')
const contract = require('truffle-contract')
const HDWalletProvider = require('truffle-hdwallet-provider')
const cmds = require('./cmds')
const {dec} = require('./utils/enc')
const {create: createPrompt, prompt} = require('./utils/prompt')
const completer = require('./utils/completer')

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  const Constants = contract(require('../build/contracts/Constants'))
  let url = 'http://localhost:8545'
  if (process.argv[2]) {
    url = `https://${process.argv[2]}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
  }
  const provider = new HDWalletProvider(fs.readFileSync('.secret').toString().trim(), url)
  Kernel.setProvider(provider)
  Constants.setProvider(provider)
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await Kernel.deployed()
  const constants = await Constants.deployed()
  createPrompt(completer.bind(null, kernel))
  while (true) {
    const cwd = dec(await kernel.getcwd())
    const args = (await prompt(`${cwd}> `)).split(/\s+/).filter(x => x.length)
    const cmd = args.shift()
    if (cmd === undefined) continue
    if (cmd === 'exit') break
    let f = cmds[cmd]
    if (!f) f = cmds.exec
    try {
      await f({web3: Kernel.web3, kernel, constants, cmd, args})
    } catch (e) {
      console.log(e.message)
    }
  }
}

main().catch(console.log).then(process.exit)
