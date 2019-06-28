const {enc} = require('../utils/enc')

module.exports = async (kernel, cmd, args) => {
  if (args.length < 2) {
    console.log('ln source_file target_file')
    console.log('ln source_file ... target_dir')
    return
  }
  const target = enc(args.pop())
  await args.reduce(async (promise, x) => {
    await promise
    await kernel.link(enc(x), target)
  }, Promise.resolve())
}
