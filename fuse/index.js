const fs = require('fs')
const {errno} = require('os').constants
const contract = require('@truffle/contract')
const HDWalletProvider = require('@truffle/hdwallet-provider')
const {utf8ToHex, hexToUtf8} = require('web3-utils')
const Fuse = require('fuse-native')

const {argv} = require('yargs')
  .usage('Usage: $0 -p [mount path] -n [network] -k [address]')
  .demandOption(['p'])
  .describe('p', 'Path to mount filesystem on').alias('p', 'mount-path').nargs('p', 1)
  .describe('n', `Network to connect to (e.g. 'rinkeby')`).alias('n', 'network').nargs('n', 1)
  .describe('k', 'Address of kernel to use').alias('k', 'kernel').nargs('k', 1)

const constants = {}
require('../build/contracts/Constants')
  .ast.nodes[1].nodes.filter(x => x.value)
  .forEach(x => constants[x.name.slice(1)] = x.value.value)

async function main() {
  const Kernel = contract(require('../build/contracts/KernelImpl'))
  let url = 'http://localhost:8545'
  if (argv.network == 'harmony') {
    url = 'https://api.s0.t.hmny.io'
  } else if (argv.network) {
    url = `https://${argv.network}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
  }
  Kernel.setProvider(new HDWalletProvider(fs.readFileSync('.secret').toString().trim(), url))
  const accounts = await Kernel.web3.eth.getAccounts()
  Kernel.defaults({from: accounts[0]})
  const kernel = await(argv.kernel ? Kernel.at(argv.kernel) : Kernel.deployed())

  const addressMap = getAddressMap(accounts[0])
  addressMap.toUid = {}
  addressMap.toGid = {}
  for (let uid in addressMap.uid) {
    addressMap.toUid[addressMap.uid[uid]] = uid
  }
  for (let gid in addressMap.gid) {
    addressMap.toGid[addressMap.gid[gid]] = gid
  }

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

  function getattr({mode, links, owner, group, entries, size, lastModified}) {
    lastModified = new Date(lastModified * 1e3)
    return {
      mtime: lastModified,
      atime: lastModified,
      ctime: lastModified,
      nlink: links,
      size,
      mode,
      uid: addressMap.toUid[owner] !== undefined ? addressMap.toUid[owner] : process.getuid ? process.getuid() : 0,
      gid: addressMap.toGid[group] !== undefined ? addressMap.toGid[group] : process.getgid ? process.getgid() : 0,
    }
  }

  const {mountPath} = argv
  const fuse = new Fuse(mountPath, {
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
        cb(Fuse.ENOENT)
      }
    },
    getattr: async (path, cb) => {
      try {
        cb(0, getattr(await kernel.lstat(utf8ToHex(path))))
      } catch (e) {
        cb(Fuse.ENOENT)
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
        await kernel.open(utf8ToHex(path), constants.O_WRONLY | constants.O_CREAT)
        await kernel.chmod(utf8ToHex(path), mode)
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
        await kernel.open(utf8ToHex(path), constants.O_WRONLY)
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
    chown: async (path, uid, gid, cb) => {
      try {
        const nullAddress = '0x0000000000000000000000000000000000000000'
        const owner = uid < 0 ? nullAddress : addressMap.uid[uid]
        const group = gid < 0 ? nullAddress : addressMap.gid[gid]
        await kernel.chown(utf8ToHex(path), owner, group)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    chmod: async (path, mode, cb) => {
      try {
        await kernel.chmod(utf8ToHex(path), mode)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    setxattr: async (path, name, buf, pos, flags, cb) => {
      try {
        await kernel.open(utf8ToHex(path), constants.O_WRONLY)
        const fd = Number(await kernel.result())
        await kernel.truncate(fd, utf8ToHex(name), 0)
        const [, e] = await write(fd, utf8ToHex(name), buf, buf.length)
        if (e) return cb(e)
        await kernel.close(fd)
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    getxattr: async (path, name, pos, cb) => {
      try {
        const data = await kernel.readPath(utf8ToHex(path), utf8ToHex(name))
        cb(0, Buffer.from(data.slice(2), 'hex'))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    listxattr: async (path, cb) => {
      try {
        const path2 = utf8ToHex(path)
        const {fileType, entries} = await kernel.lstat(path2)
        if (fileType != 1) return cb(0)
        const keys = []
        for (let i = 0; i < entries; i++) {
          const data = await kernel.readkeyPath(path2, i)
          if (!data) continue
          keys.push(hexToUtf8(data))
        }
        cb(0, keys)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    removexattr: async (path, name, cb) => {
      try {
        await kernel.open(utf8ToHex(path), constants.O_WRONLY)
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
        await kernel.chmod(utf8ToHex(path), mode)
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
  }, {
    autoCache: true,
    displayFolder: true,
    timeout: false,
  })
  fuse.mount(err => {
    if (err) throw err
    console.log('Filesystem mounted on ' + mountPath)
  })

  process.on('SIGINT', () => {
    fuse.unmount(err => {
      if (err) {
        console.log('Filesystem at ' + mountPath + ' not unmounted', err)
      } else {
        console.log('Filesystem at ' + mountPath + ' unmounted')
        process.exit()
      }
    })
  })
}

function getAddressMap(defaultAddress) {
  try {
    return JSON.parse(fs.readFileSync('./address_map.json'))
  } catch (e) {}
  const uid = process.getuid ? process.getuid() : 0
  const gid = process.getgid ? process.getgid() : 0
  const addressMap = {
    uid: {[uid]: defaultAddress},
    gid: {[gid]: defaultAddress},
  }
  fs.writeFileSync('./address_map.json', JSON.stringify(addressMap, 0, 2) + '\n')
  return addressMap
}

main().catch(err => {
  console.log(err)
  process.exit()
})
