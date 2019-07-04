const {enc} = require('../utils/enc')

module.exports = async (web3, kernel, cmd, args) => {
  if (args.length !== 2) {
    return console.log('install <address> target_file')
  }
  const address = args.shift()
  const target = enc(args.shift())
  await kernel.install(address, target)
}
