const Web3 = require('web3')
const {asciiToHex, hexToAscii} = require('web3-utils')
const contract = require('truffle-contract')
const prompt = require('./prompt')

const enc = x => asciiToHex(x)
const dec = x => hexToAscii(x).replace(/\0+$/, '')

function pathenc(path) {
  if (path === '/') path = ''
  return path.split('/').map(enc)
}

async function ls(kernel, args) {
  await args.reduce(async (promise, x) => {
    await promise
    const keys = await kernel.list(pathenc(x))
    keys.map(dec).forEach(x => console.log(x))
  }, Promise.resolve())
}

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  Kernel.setProvider(new Web3.providers.HttpProvider('http://localhost:7545'))
  const kernel = await Kernel.deployed()
  while (true) {
    const args = (await prompt('> ')).split(/\s+/).filter(x => x.length)
    const cmd = args.shift()
    try {
      switch (cmd) {
        case 'ls': {
          await ls(kernel, args)
          break
        }
        default: {
          console.log('Unrecognized command:', cmd)
          break
        }
      }
    } catch (e) {
      console.log(e.message);
    }
  }
}

main()
