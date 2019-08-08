const {enc} = require('../utils/enc')

module.exports = async ({kernel, args}) => {
  if (args.length > 1) {
    throw new Error('Too many arguments.')
  }
  await kernel.chdir(enc(args[0] || '/'))
}
