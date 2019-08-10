const fs = require('fs')
const contract = require('truffle-contract')
const HDWalletProvider = require('truffle-hdwallet-provider')
const {asciiToHex, hexToAscii} = require('web3-utils')
const fuse = require('fuse-bindings')

const mountPath = process.argv[2]

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  const Constants = contract(require('../build/contracts/Constants'))
  let url = 'http://localhost:8545'
  if (process.argv[3]) {
    url = `https://${process.argv[3]}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
  }
  const provider = new HDWalletProvider(fs.readFileSync('.secret').toString().trim(), url)
  Kernel.setProvider(provider)
  Constants.setProvider(provider)
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await Kernel.deployed()
  const constants = await Constants.deployed()
  const {web3} = Kernel

  fuse.mount(mountPath, {
    readdir: async (path, cb) => {
      path = asciiToHex(path)
      const {entries} = await kernel.stat(path)
      const keys = []
      for (let i = 0; i < entries; i++) {
        keys.push(await kernel.readkeyPath(path, i))
      }
      cb(0, keys.map(hexToAscii))
    },
    getattr: async (path, cb) => {
      try {
        let {
          fileType,
          permissions,
          links,
          owner,
          entries,
          lastModified,
        } = await kernel.stat(asciiToHex(path))
        let size = entries
        let mode
        const Contract = 1
        const Data = 2
        const Directory = 3
        switch (fileType.toNumber()) {
          case Contract:
            const code = await web3.eth.getCode(owner)
            size = code.length / 2 - 1
            mode = 0100755
            break
          case Data:
            mode = 0100644
            break
          case Directory:
            links = entries
            mode = 0040755
            break
        }
        lastModified = new Date(lastModified.toNumber() * 1e3)
        return cb(0, {
          mtime: lastModified,
          atime: lastModified,
          ctime: lastModified,
          nlink: links,
          size,
          mode,
          uid: process.getuid ? process.getuid() : 0,
          gid: process.getgid ? process.getgid() : 0,
        })
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
  }, err => {
    if (err) throw err
    console.log('filesystem mounted on ' + mountPath)
  })
}

process.on('SIGINT', () => {
  fuse.unmount(mountPath, err => {
    if (err) {
      console.log('filesystem at ' + mountPath + ' not unmounted', err)
    } else {
      console.log('filesystem at ' + mountPath + ' unmounted')
      process.exit()
    }
  })
})

main().catch(err => {
  console.log(err)
  process.exit()
})
