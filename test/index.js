const KernelImpl = artifacts.require('KernelImpl')
const {asciiToHex, hexToAscii} = web3.utils

const enc = x => asciiToHex(x)
const dec = x => hexToAscii(x).replace(/\0+$/, '')

async function ls(kernel, path, isData) {
  const keys = await kernel.list(path)
  await Promise.all(keys.map(async key => {
    if (isData) {
      const data = dec(await kernel.readPath(path, key))
      console.log(dec(key), '=', data)
    } else {
      console.log(dec(key))
    }
  }))
}

module.exports = async callback => {
  const kernel = await KernelImpl.deployed()
  await kernel.exec(enc('/bin/TestDapp'), [])
  await ls(kernel, enc('/'))
  await ls(kernel, enc('/test_file'), true)
  await kernel.open(enc('/test_file'), 0x0101)
  let fd = await kernel.result()
  await kernel.write(fd, enc('foo2'), enc('bar2'))
  await kernel.close(fd)
  try {
    await kernel.mkdir(enc('/test_dir'))
  } catch (e) {}
  await kernel.chdir(enc('/test_dir'))
  await kernel.open(enc('test_file'), 0x0101)
  fd = await kernel.result()
  await kernel.write(fd, enc('foo2'), enc('bar2'))
  await kernel.close(fd)
  await ls(kernel, [])
  callback()
}
