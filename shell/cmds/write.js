const {enc} = require('../utils/enc')
const {prompt} = require('../utils/prompt')

module.exports = async ({kernel, constants, args}) => {
  if (!args.length) {
    return console.log('Need a filename(s).');
  }
  console.log("Enter a JSON array or object. To cancel, type '!'.");
  let input = ''
  for (let i = 1;; i++) {
    const line = await prompt(`${i}: `.padStart(5, ' '))
    if (line === '!') return
    input += line
    try {
      const data = JSON.parse(input)
      if (typeof data !== 'object') {
        return console.log('Data is not an array/object.');
      }
      break
    } catch (e) {}
  }
  const data = JSON.parse(input)
  await args.reduce(async (promise, x) => {
    await promise
    const path = enc(x)
    await kernel.open(path, Number(await constants._O_WRONLY()) | Number(await constants._O_CREAT()))
    const fd = await kernel.result()
    await Object.keys(data).reduce(async (promise, key) => {
      await promise
      let value = data[key]
      if (typeof value !== 'string') {
        value = JSON.stringify(value)
      }
      await kernel.write(fd, enc(key), enc(value))
    }, Promise.resolve())
    await kernel.close(fd)
  }, Promise.resolve())
}
