const KernelImpl = artifacts.require('KernelImpl')

const enc = x => web3.utils.asciiToHex(x)
const dec = x => web3.utils.hexToAscii(x).replace(/\0+$/, '')
const pathenc = x => x ? x.split('/').map(enc) : []

async function ls(kernel, path, isData) {
  path = pathenc(path)
  const keys = await kernel.list(path)
  await Promise.all(keys.map(async key => {
    if (isData) {
      const data = dec(await kernel.read2(path, key))
      console.log(dec(key), '=', data)
    } else {
      console.log(dec(key))
    }
  }))
}

module.exports = async callback => {
  const kernel = await KernelImpl.deployed()
  await kernel.exec(pathenc('TestDapp'), [])
  await ls(kernel, '')
  await ls(kernel, 'test_file', true)
  await kernel.open(pathenc('test_file'), 0x0201)
  let fd = await kernel.result()
  await kernel.write(fd, enc('foo2'), enc('bar2'))
  await kernel.close(fd)
  try {
    await kernel.mkdir(pathenc('test_dir'))
  } catch (e) {}
  await kernel.open(pathenc('test_dir/test_file'), 0x0201)
  fd = await kernel.result()
  await kernel.write(fd, enc('foo2'), enc('bar2'))
  await kernel.close(fd)
  await ls(kernel, 'test_dir')
  callback()
}
