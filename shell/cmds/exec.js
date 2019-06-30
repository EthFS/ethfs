const {enc} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  let i = 0
  const argi = []
  args.forEach(x => {
    argi.push(i)
    i += x.length
  })
  await kernel.exec(enc(cmd), argi, enc(args.join('')))
}
