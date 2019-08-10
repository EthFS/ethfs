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
      try {
        const path2 = asciiToHex(path)
        const {entries} = await kernel.stat(path2)
        const keys = []
        for (let i = 0; i < entries; i++) {
          keys.push(await kernel.readkeyPath(path2, i))
        }
        cb(0, keys.map(hexToAscii))
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    getattr: async (path, cb) => {
      try {
        const path2 = asciiToHex(path)
        let {
          fileType,
          permissions,
          links,
          owner,
          entries,
          lastModified,
        } = await kernel.stat(path2)
        let size, mode
        const Contract = 1
        const Data = 2
        const Directory = 3
        switch (Number(fileType)) {
          case Contract:
            const code = await web3.eth.getCode(owner)
            size = code.length / 2 - 1
            mode = 0100755
            break
          case Data:
            try {
              const data = hexToAscii(await kernel.readPath(path2, '0x00'))
              size = data.length
            } catch (e) {
              size = 0
            }
            mode = 0100644
            break
          case Directory:
            size = links = entries
            mode = 0040755
            break
        }
        lastModified = new Date(Number(lastModified) * 1e3)
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
    open: async (path, flags, cb) => {
      try {
        await kernel.open(asciiToHex(path), flags)
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    create: async (path, mode, cb) => {
      try {
        await kernel.open(asciiToHex(path), Number(await constants._O_WRONLY()) | Number(await constants._O_CREAT()))
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    read: async (path, fd, buf, len, pos, cb) => {
      try {
        let data = hexToAscii(await kernel.read(fd, '0x00'))
        data = data.slice(pos, pos + len)
        if (!data) return cb(0)
        buf.write(data)
        cb(data.length)
      } catch (e) {
        cb(0)
      }
    },
    write: async (path, fd, buf, len, pos, cb) => {
      try {
        const data = '0x' + buf.slice(0, len).toString('hex')
        await kernel.write(fd, '0x00', data)
        cb(len)
      } catch (e) {
        cb(0)
      }
    },
    ftruncate: async (path, fd, size, cb) => {
      try {
        if (size) {
          let data = hexToAscii(await kernel.read(fd, '0x00'))
          data = data.slice(0, size)
          await kernel.write(fd, '0x00', asciiToHex(data))
        } else {
          await kernel.clear(fd, '0x00')
        }
        cb(0)
      } catch (e) {
        cb(0)
      }
    },
    release: async (path, fd, cb) => {
      try {
        await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    link: async (src, dest, cb) => {
      try {
        await kernel.link(asciiToHex(src), asciiToHex(dest))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    unlink: async (path, cb) => {
      try {
        await kernel.unlink(asciiToHex(path))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    mkdir: async (path, mode, cb) => {
      try {
        await kernel.mkdir(asciiToHex(path))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    rmdir: async (path, cb) => {
      try {
        await kernel.rmdir(asciiToHex(path))
        cb(0)
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
