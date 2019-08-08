const ABICoder = require('web3-eth-abi')
const {enc} = require('../utils/enc')

const encode = (type, x) => Buffer.from(ABICoder.encodeParameter(type, x).slice(2), 'hex')

module.exports = async ({kernel, cmd, args}) => {
  if (!cmd.includes('/')) {
    cmd = '/bin/' + cmd
  }
  args = args.map(x => {
    try {
      if (x.match(/^\d+$/)) {
        return encode('uint256', x)
      }
    } catch (e) {}
    try {
      return encode('address', x)
    } catch (e) {}
    try {
      return encode('bytes', x)
    } catch (e) {}
    return encode('string', x)
  })
  let i = 0
  const argi = []
  args.forEach(x => {
    argi.push(i + 64)
    i += x.length
  })
  args = Buffer.concat(args, i)
  args = '0x'+args.toString('hex')
  await kernel.exec(enc(cmd), argi, ABICoder.encodeParameter('bytes', args))
}
