const Web3 = require('web3')
const {asciiToHex, hexToAscii} = require('web3-utils')
const contract = require('truffle-contract')
const prompt = require('./prompt')

const enc = x => asciiToHex(x)
const dec = x => hexToAscii(x).replace(/\0+$/, '')
const pathenc = x => x.split('/').map(enc)

async function ls(kernel, args) {
  if (!args.length) args = ['.']
  await args.reduce(async (promise, x) => {
    await promise
    const keys = await kernel.list(pathenc(x))
    keys.map(dec).forEach(x => console.log(x))
  }, Promise.resolve())
}

async function cd(kernel, args) {
  if (args.length > 1) {
    throw new Error('Too many arguments.')
  }
  await kernel.chdir(pathenc(args[0] || '/'))
}

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  Kernel.setProvider(new Web3.providers.HttpProvider('http://localhost:7545'))
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await Kernel.deployed()
  while (true) {
    const args = (await prompt('> ')).split(/\s+/).filter(x => x.length)
    const cmd = args.shift()
    try {
      switch (cmd) {
        case 'ls':
          await ls(kernel, args)
          break
        case 'cd':
          await cd(kernel, args)
          break
        default:
          console.log('Unrecognized command:', cmd)
          break
      }
    } catch (e) {
      console.log(e.message);
    }
  }
}

main()
