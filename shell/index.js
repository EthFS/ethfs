const KernelImpl = artifacts.require('KernelImpl')

const enc = x => web3.utils.asciiToHex(x)
const dec = x => web3.utils.hexToAscii(x).replace(/\0+$/, '')

module.exports = async callback => {
  const kernel = await KernelImpl.deployed()
  await kernel.exec([enc('TestDapp')], [])
  const files = await kernel.list([])
  files.forEach(x => console.log(dec(x)))
  const path = [enc('test_file')]
  const keys = await kernel.list(path)
  await Promise.all(keys.map(async key => {
    const data = dec(await kernel.read2(path, key))
    console.log(dec(key), '=', data)
  }))
  await kernel.open(path, 0x0201);
  const fd = await kernel.result()
  await kernel.write(fd, enc("foo2"), enc("bar2"));
  await kernel.close(fd);
  callback()
}
