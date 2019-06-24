const KernelImpl = artifacts.require('KernelImpl')
const {asciiToHex, hexToAscii} = web3.utils

function trim(s) {
  return s.replace(/\0+$/, '')
}

module.exports = async callback => {
  const kernel = await KernelImpl.deployed()
  await kernel.exec(['TestDapp'].map(asciiToHex), [])
  console.log((await kernel.list([])).map(hexToAscii).map(trim))
  callback()
}
