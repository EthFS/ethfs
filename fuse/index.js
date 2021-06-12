const fs = require('fs')
const {errno} = require('os').constants
const Fuse = require('fuse-native')
const {
  ethers,
  constants: {MaxUint256},
  utils: {arrayify, toUtf8Bytes, toUtf8String},
} = require('ethers')
const KernelImpl = require('../build/contracts/KernelImpl')

const {argv} = require('yargs')
  .usage('Usage: $0 -p [mount path] -n [network] -k [address]')
  .demandOption(['p'])
  .describe('p', 'Path to mount filesystem on').alias('p', 'mount-path').nargs('p', 1)
  .describe('n', `Network to connect to (e.g. 'rinkeby')`).alias('n', 'network').nargs('n', 1)
  .describe('k', 'Address of kernel to use').alias('k', 'kernel').nargs('k', 1).string('k')

const constants = {}
require('../build/contracts/Constants')
  .ast.nodes[1].nodes.filter(x => x.value)
  .forEach(x => constants[x.name.slice(1)] = x.value.value)

async function main() {
  let url = 'http://localhost:8545'
  switch (argv.network) {
  case 'harmony-s0':
    url = 'https://api.harmony.one'
    break
  case 'harmony-s1':
    url = 'https://s1.api.harmony.one'
    break
  default:
    if (argv.network) {
      url = `https://${argv.network}.infura.io/v3/59389cd0fe54420785906cf571a7d7c0`
    }
  }
  const privateKey = fs.readFileSync('.secret').toString().trim()
  const provider = new ethers.providers.JsonRpcProvider(url)
  const signer = new ethers.Wallet(privateKey, provider)
  const {chainId} = await provider.getNetwork()
  const address = argv.kernel || KernelImpl.networks[chainId].address
  const kernel = new ethers.Contract(address, KernelImpl.abi, signer)

  const addressMap = getAddressMap(signer.getAddress())
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
        const tx = await kernel.write(fd, key, buf.slice(i, j))
        await tx.wait()
        i = j
      }
      return [i]
    } catch (e) {
      return [i, -errno[e.reason]]
    }
  }

  function getattr({mode, links, owner, group, nEntries, size, lastModified}) {
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

  class MyFuse extends Fuse {
    _fuseOptions() { return super._fuseOptions() + ',sync_read' }
  }

  const {mountPath} = argv
  const fuse = new MyFuse(mountPath, {
    readdir: async (path, cb) => {
      try {
        const path2 = toUtf8Bytes(path)
        const {nEntries} = await kernel.stat(path2)
        const keys = []
        for (let i = 0; i < nEntries; i++) {
          keys.push(toUtf8String(await kernel.readkeyPath(path2, i)))
        }
        cb(0, keys)
      } catch (e) {
        cb(Fuse.ENOENT)
      }
    },
    getattr: async (path, cb) => {
      try {
        cb(0, getattr(await kernel.lstat(toUtf8Bytes(path))))
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
        const tx = await kernel.open(toUtf8Bytes(path), flags)
        await tx.wait()
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    create: async (path, mode, cb) => {
      try {
        let tx = await kernel.open(toUtf8Bytes(path), constants.O_WRONLY | constants.O_CREAT)
        await tx.wait()
        tx = await kernel.chmod(toUtf8Bytes(path), mode)
        await tx.wait()
        cb(0, Number(await kernel.result()))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    read: async (path, fd, buf, len, pos, cb) => {
      try {
        let data
        if (fd == 0xffffffff) {
          data = await kernel.readPath(toUtf8Bytes(path), '0x', pos, len)
        } else {
          data = await kernel.read(fd, '0x', pos, len)
        }
        data = arrayify(data)
        buf.set(data)
        cb(data.length)
      } catch (e) {
        cb(0, -errno[e.reason])
      }
    },
    write: async (path, fd, buf, len, pos, cb) => {
      try {
        const {size} = await kernel.fstat(fd)
        if (pos < size) {
          const tx = await kernel.truncate(fd, '0x', pos)
          await tx.wait()
        }
        cb(...await write(fd, '0x', buf, len))
      } catch (e) {
        cb(0, -errno[e.reason])
      }
    },
    truncate: async (path, size, cb) => {
      try {
        let tx = await kernel.open(toUtf8Bytes(path), constants.O_WRONLY)
        await tx.wait()
        const fd = Number(await kernel.result())
        tx = await kernel.truncate(fd, '0x', size)
        await tx.wait()
        tx = await kernel.close(fd)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    ftruncate: async (path, fd, size, cb) => {
      try {
        const tx = await kernel.truncate(fd, '0x', size)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    release: async (path, fd, cb) => {
      try {
        if (fd != 0xffffffff) {
          const tx = await kernel.close(fd)
          await tx.wait()
        }
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
        const tx = await kernel.chown(toUtf8Bytes(path), owner, group)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    chmod: async (path, mode, cb) => {
      try {
        const tx = await kernel.chmod(toUtf8Bytes(path), mode)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    setxattr: async (path, name, buf, pos, flags, cb) => {
      try {
        let tx = await kernel.open(toUtf8Bytes(path), constants.O_WRONLY)
        await tx.wait()
        const fd = Number(await kernel.result())
        tx = await kernel.truncate(fd, toUtf8Bytes(name), 0)
        await tx.wait()
        const [, e] = await write(fd, toUtf8Bytes(name), buf, buf.length)
        if (e) return cb(e)
        tx = await kernel.close(fd)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    getxattr: async (path, name, pos, cb) => {
      try {
        const data = await kernel.readPath(toUtf8Bytes(path), toUtf8Bytes(name), 0, MaxUint256)
        cb(0, Buffer.from(arrayify(data)))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    listxattr: async (path, cb) => {
      try {
        const path2 = toUtf8Bytes(path)
        const {fileType, nEntries} = await kernel.lstat(path2)
        if (fileType != 1) return cb(0)
        const keys = []
        for (let i = 0; i < nEntries; i++) {
          const data = await kernel.readkeyPath(path2, i)
          if (data === '0x') continue
          keys.push(toUtf8String(data))
        }
        cb(0, keys)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    removexattr: async (path, name, cb) => {
      try {
        let tx = await kernel.open(toUtf8Bytes(path), constants.O_WRONLY)
        await tx.wait()
        const fd = Number(await kernel.result())
        tx = await kernel.clear(fd, toUtf8Bytes(name))
        await tx.wait()
        tx = await kernel.close(fd)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    link: async (src, dest, cb) => {
      try {
        const tx = await kernel.link(toUtf8Bytes(src), toUtf8Bytes(dest))
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    unlink: async (path, cb) => {
      try {
        const tx = await kernel.unlink(toUtf8Bytes(path))
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    symlink: async (src, dest, cb) => {
      try {
        const tx = await kernel.symlink(toUtf8Bytes(src), toUtf8Bytes(dest))
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    readlink: async (path, cb) => {
      try {
        cb(0, toUtf8String(await kernel.readlink(toUtf8Bytes(path))))
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    rename: async (src, dest, cb) => {
      try {
        const tx = await kernel.move(toUtf8Bytes(src), toUtf8Bytes(dest))
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    mkdir: async (path, mode, cb) => {
      try {
        let tx = await kernel.mkdir(toUtf8Bytes(path))
        await tx.wait()
        tx = await kernel.chmod(toUtf8Bytes(path), mode)
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
    rmdir: async (path, cb) => {
      try {
        const tx = await kernel.rmdir(toUtf8Bytes(path))
        await tx.wait()
        cb(0)
      } catch (e) {
        cb(-errno[e.reason])
      }
    },
  }, {
    autoCache: true,
    displayFolder: true,
    maxRead: 32768,
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
