const fs = require('fs')
const contract = require('truffle-contract')
const HDWalletProvider = require('truffle-hdwallet-provider')
const {utf8ToHex, hexToUtf8} = require('web3-utils')
const fuse = require('fuse-bindings')

const mountPath = process.argv[2]
if (!mountPath) return console.log('Please specify mount path')

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

  async function write(fd, key, buf, len) {
    let i = 0
    try {
      while (i < len) {
        const j = Math.min(len, i+8192)
        await kernel.write(fd, key, buf.slice(i, j))
        i = j
      }
    } catch (e) {}
    return i
  }

  fuse.mount(mountPath, {
    displayFolder: true,
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
        const path2 = utf8ToHex(path)
        let {
          fileType,
          permissions,
          links,
          owner,
          entries,
          size,
          lastModified,
        } = await kernel.stat(path2)
        let mode
        switch (Number(fileType)) {
          case 1:  // Regular
            mode = 0100644
            break
          case 2:  // Directory
            size = links = entries
            mode = 0040755
            break
        }
        lastModified = new Date(lastModified * 1e3)
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
        if ((flags & 3) == 0) return cb(0, 0xffffffff)
        await kernel.open(utf8ToHex(path), flags)
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    create: async (path, mode, cb) => {
      try {
        await kernel.open(utf8ToHex(path), await constants._O_WRONLY() | await constants._O_CREAT())
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(fuse.ENOENT)
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
        cb(0)
      }
    },
    write: async (path, fd, buf, len, pos, cb) => {
      try {
        const {size} = await kernel.fstat(fd)
        if (pos < size) await kernel.truncate(fd, '0x', pos)
        cb(await write(fd, '0x', buf, len))
      } catch (e) {
        cb(0)
      }
    },
    ftruncate: async (path, fd, size, cb) => {
      try {
        await kernel.truncate(fd, '0x', size)
        cb(0)
      } catch (e) {
        cb(0)
      }
    },
    release: async (path, fd, cb) => {
      try {
        if (fd != 0xffffffff) await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
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
        await write(fd, utf8ToHex(name), buf, len)
        await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
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
        cb(fuse.ENOENT)
      }
    },
    listxattr: async (path, buf, len, cb) => {
      try {
        const path2 = utf8ToHex(path)
        const {entries} = await kernel.stat(path2)
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
        cb(fuse.ENOENT)
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
        cb(fuse.ENOENT)
      }
    },
    link: async (src, dest, cb) => {
      try {
        await kernel.link(utf8ToHex(src), utf8ToHex(dest))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    unlink: async (path, cb) => {
      try {
        await kernel.unlink(utf8ToHex(path))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    rename: async (src, dest, cb) => {
      try {
        await kernel.move(utf8ToHex(src), utf8ToHex(dest))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    mkdir: async (path, mode, cb) => {
      try {
        await kernel.mkdir(utf8ToHex(path))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
    rmdir: async (path, cb) => {
      try {
        await kernel.rmdir(utf8ToHex(path))
        cb(0)
      } catch (e) {
        cb(fuse.ENOENT)
      }
    },
  }, err => {
    if (err) throw err
    console.log('Filesystem mounted on ' + mountPath)
  })
}

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

main().catch(err => {
  console.log(err)
  process.exit()
})
