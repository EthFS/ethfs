const {enc} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  if (!cmd.includes('/')) {
    cmd = '/bin/' + cmd
  }
  let i = 0
  const argi = []
  args.forEach(x => argi.push(i += x.length))
  await kernel.exec(enc(cmd), argi, enc(args.join('')))
}
