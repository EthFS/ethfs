const {asciiToHex, hexToAscii} = require('web3-utils')

module.exports = {
  enc: x => asciiToHex(x),
  dec: x => hexToAscii(x).replace(/\0+$/, ''),
  pathenc: x => (x || '').split('/').map(asciiToHex),
}
