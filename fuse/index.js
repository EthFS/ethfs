const fs = require('fs')
const {errno} = require('os').constants
const contract = require('truffle-contract')
const HDWalletProvider = require('truffle-hdwallet-provider')
const {utf8ToHex, hexToUtf8} = require('web3-utils')
const fuse = require('fuse-bindings')

const {argv} = require('yargs')
  .usage('Usage: $0 -m [mount path] -n [network]')
  .demandOption(['m'])
  .describe('m', 'Path to mount filesystem on').alias('m', 'mount-path')
  .describe('n', `Network to connect to via Infura (e.g. 'rinkeby')`).alias('n', 'network')

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  const Constants = contract(require('../build/contracts/Constants'))
  let url = 'http://localhost:8545'
  if (argv.network) {
    url = `https://${argv.network}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
  }
  const provider = new HDWalletProvider(fs.readFileSync('.secret').toString().trim(), url)
  Kernel.setProvider(provider)
  Constants.setProvider(provider)
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await Kernel.deployed()
  const constants = await Constants.deployed()

  async function write(fd, key, buf, len) {
    let i = 0
    try {
      while (i < len) {
        const j = Math.min(len, i+8192)
        await kernel.write(fd, key, buf.slice(i, j))
        i = j
      }
      return [i]
    } catch (e) {
      return [i, -errno[e.reason]]
    }
  }

  function getattr({fileType, permissions, links, owner, entries, size, lastModified}) {
    let mode
    switch (Number(fileType)) {
      case 1:  // Regular
        mode = 0100644
        break
      case 2:  // Directory
        size = links = entries
        mode = 0040755
        break
      case 3:  // Symlink
        mode = 0120755
        break
    }
    lastModified = new Date(lastModified * 1e3)
    return {
      mtime: lastModified,
      atime: lastModified,
      ctime: lastModified,
      nlink: links,
      size,
      mode,
      uid: process.getuid ? process.getuid() : 0,
      gid: process.getgid ? process.getgid() : 0,
    }
  }

  const {mountPath} = argv
  fuse.mount(mountPath, {
    displayFolder: true,
    options: ['direct_io'],
    readdir: async (path, cb) => {
      try {
        const path2 = utf8ToHex(path)
        const {entries} = await kernel.stat(path2)
        const keys = []
        for (let i = 0; i < entries; i++) {
          keys.push(hexToUtf8(await kernel.readkeyPath(path2, i)))
        }
        cb(0, keys)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    getattr: async (path, cb) => {
      try {
        cb(0, getattr(await kernel.stat(utf8ToHex(path))))
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    fgetattr: async (path, fd, cb) => {
      try {
        cb(0, getattr(await kernel.fstat(fd)))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    open: async (path, flags, cb) => {
      try {
        if ((flags & 3) == 0) return cb(0, 0xffffffff)
        await kernel.open(utf8ToHex(path), flags)
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    create: async (path, mode, cb) => {
      try {
        await kernel.open(utf8ToHex(path), await constants._O_WRONLY() | await constants._O_CREAT())
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    read: async (path, fd, buf, len, pos, cb) => {
      try {
        let data
        if (fd == 0xffffffff) {
          data = await kernel.readPath(utf8ToHex(path), '0x')
        } else {
          data = await kernel.read(fd, '0x')
        }
        cb(Buffer.from(data.slice(2), 'hex').copy(buf, 0, pos, pos + len))
      } catch (e) {
        cb(0, -errno[e.reason])
      }
    },
    write: async (path, fd, buf, len, pos, cb) => {
      try {
        const {size} = await kernel.fstat(fd)
        if (pos < size) await kernel.truncate(fd, '0x', pos)
        cb(...await write(fd, '0x', buf, len))
      } catch (e) {
        cb(0, -errno[e.reason])
      }
    },
    truncate: async (path, size, cb) => {
      try {
        await kernel.open(utf8ToHex(path), await constants._O_WRONLY())
        const fd = Number(await kernel.result())
        await kernel.truncate(fd, '0x', size)
        await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    ftruncate: async (path, fd, size, cb) => {
      try {
        await kernel.truncate(fd, '0x', size)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    release: async (path, fd, cb) => {
      try {
        if (fd != 0xffffffff) await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    chmod: async (path, mode, cb) => {
      cb(0)
    },
    setxattr: async (path, name, buf, len, offset, flags, cb) => {
      try {
        await kernel.open(utf8ToHex(path), await constants._O_WRONLY())
        const fd = Number(await kernel.result())
        await kernel.truncate(fd, utf8ToHex(name), 0)
        const [, e] = await write(fd, utf8ToHex(name), buf, len)
        if (e) return cb(e)
        await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    getxattr: async (path, name, buf, len, offset, cb) => {
      try {
        const data = await kernel.readPath(utf8ToHex(path), utf8ToHex(name))
        const len2 = data.length/2 - 1
        if (len == 0) return cb(len2)
        if (len < len2) return cb(fuse.ERANGE)
        cb(buf.write(data.slice(2), offset, 'hex'))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    listxattr: async (path, buf, len, cb) => {
      try {
        const path2 = utf8ToHex(path)
        const {fileType, entries} = await kernel.stat(path2)
        if (fileType != 1) return cb(0)
        let i = 0
        for (let j = 0; j < entries; j++) {
          const data = await kernel.readkeyPath(path2, j)
          if (!data) continue
          if (len > 0) {
            i += buf.write(data.slice(2), i, 'hex')
            if (i == len) return cb(fuse.ERANGE)
            buf.write('00', i++, 'hex')
          } else {
            i += data.length/2
          }
        }
        cb(i)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    removexattr: async (path, name, cb) => {
      try {
        await kernel.open(utf8ToHex(path), await constants._O_WRONLY())
        const fd = Number(await kernel.result())
        await kernel.clear(fd, utf8ToHex(name))
        await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    link: async (src, dest, cb) => {
      try {
        await kernel.link(utf8ToHex(src), utf8ToHex(dest))
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    unlink: async (path, cb) => {
      try {
        await kernel.unlink(utf8ToHex(path))
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    symlink: async (src, dest, cb) => {
      try {
        await kernel.symlink(utf8ToHex(src), utf8ToHex(dest))
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    readlink: async (path, cb) => {
      try {
        cb(0, hexToUtf8(await kernel.readlink(utf8ToHex(path))))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    rename: async (src, dest, cb) => {
      try {
        await kernel.move(utf8ToHex(src), utf8ToHex(dest))
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    mkdir: async (path, mode, cb) => {
      try {
        await kernel.mkdir(utf8ToHex(path))
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    rmdir: async (path, cb) => {
      try {
        await kernel.rmdir(utf8ToHex(path))
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
  }, err => {
    if (err) throw err
    console.log('Filesystem mounted on ' + mountPath)
  })

  process.on('SIGINT', () => {
    fuse.unmount(mountPath, err => {
      if (err) {
        console.log('Filesystem at ' + mountPath + ' not unmounted', err)
      } else {
        console.log('Filesystem at ' + mountPath + ' unmounted')
        process.exit()
      }
    })
  })
}

main().catch(err => {
  console.log(err)
  process.exit()
})
