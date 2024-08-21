import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import readline from 'node:readline'
import { createReadStream, readFileSync } from 'node:fs'
import { Readable } from 'node:stream'
import { randomInt, randomUUID } from 'node:crypto'

import chalk from 'chalk'
import AoLoader from '@permaweb/ao-loader'

const __dirname = dirname(fileURLToPath(import.meta.url))

function binaryStream (USE_AOS) {
  if (USE_AOS) {
    console.log('Using aos base module...')
    return fetch('https://arweave.net/raw/xT0ogTeagEGuySbKuUoo_NaWeeBv1fZ4MqgDdKVKY0U').then(res => res.body)
  }
  return Promise.resolve(Readable.toWeb(createReadStream('./process.wasm')))
}

async function trampoline (init) {
  let result = init
  while (typeof result === 'function') result = await result()
  return result
}

function wasmResponse (stream) {
  return new Response(stream, { headers: { 'Content-Type': 'application/wasm' } })
}

async function replWith ({ ASSIGNABLE, stream, env }) {
  let messageCount = 0
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  })

  async function maybeAllowAssignments (init) {
    if (!ASSIGNABLE) return init

    console.log(chalk.gray(`Adding assignable: '${ASSIGNABLE}'`))
    const allowAllAssignmentsMessage = {
      Id: 'allow-assignments',
      Target: env.Process.Id,
      From: env.Process.Owner,
      Owner: env.Process.Owner,
      'Block-Height': randomInt(1_000_000, 1_500_000),
      Module: env.Module.Id,
      Tags: [
        { name: 'Action', value: 'Eval' }
      ],
      Data: `
        ao.addAssignable('assignable', ${ASSIGNABLE})
      `
    }

    const { Memory } = await handle(init, allowAllAssignmentsMessage, env)
    return Memory
  }

  function createEval (line) {
    if (line === 'sample-gql') {
      console.log(chalk.blue('Initializing sample GraphQL Server at ao.server...'))
      console.log(chalk.blue(`
Example:

ao.server('query GetPerson ($id: ID!) { person (id: $id) { firstName, lastName, age } }', { id = "id-2" })
ao.server('query GetPersons { persons { firstName, lastName } }')
`))
      const init = readFileSync(join(__dirname, 'server.lua'), 'utf-8')
      line = `ao.server = ao.server or ${init}`
    } else if (line === 'gateway') {
      console.log(chalk.green('Initializing Arweave GraphQL Gatewway at ao.server...'))
      console.log(chalk.green(`
Example:

ao.server('query { transaction (id: "540a3be5-dca2-47bf-97bc-27c754acc945") { id } }')
`))
      const init = readFileSync(join(__dirname, 'gateway.lua'), 'utf-8')
      line = `local gql, apis = ${init}; ao.server = gql; ao.apis = apis;`
    } else if (line.startsWith('query') || line.startsWith('mutation')) {
      line = `return ao.server('${line}')`
    }

    const id = randomUUID()
    console.log(`Sending msg: ${chalk.bgBlue(id)}`)

    return {
      Id: id,
      Target: env.Process.Id,
      From: env.Process.Owner,
      Owner: env.Process.Owner,
      'Block-Height': randomInt(1_000_000, 1_500_000),
      Module: env.Module.Id,
      Tags: [
        { name: 'Action', value: 'Eval' },
        { name: 'Message-Count', value: ++messageCount }
      ],
      Data: line
    }
  }

  const handle = await WebAssembly.compileStreaming(wasmResponse(stream))
    .then((module) => AoLoader(
      (info, receiveInstance) => WebAssembly.instantiate(module, info).then(receiveInstance),
      {
        format: 'wasm64-unknown-emscripten-draft_2024_02_15',
        memoryLimit: '2-gb',
        computeLimit: 9_000_000_000_000,
        inputEncoding: 'JSON-1',
        outputEncoding: 'JSON-1'
      }
    ))

  const repl = (memory) => new Promise((resolve, reject) =>
    rl.question(
      'aos-graphql' + '> ',
      async function (line) {
        if (line === 'exit') return resolve()

        try {
          const message = createEval(line)
          const { Memory, Output, Error } = await handle(memory, message, env)
          if (Error) console.error(Error)
          if (Output?.data) console.log(Output?.data)
          // prompt for next input into repl
          return resolve(() => repl(Memory))
        } catch (err) {
          console.error('Error: ', err)
          reject(err)
        }
      }
    )
  )

  return (init) => Promise.resolve(init)
    .then(maybeAllowAssignments)
    .then((init) => trampoline(() => repl(init)))
    .finally(() => rl.close())
}

replWith({
  /**
   * Assignable that allows all assignments
   */
  ASSIGNABLE: 'function (msg) return true end',
  stream: await binaryStream(!!process.env.USE_AOS),
  env: {
    Process: {
      Id: 'PROCESS_TEST',
      Owner: randomUUID(),
      Tags: [
        { name: 'Module', value: 'aos-graphql' }
      ]
    },
    Module: {
      Id: 'MODULE_TEST',
      Owner: randomUUID(),
      Tags: []
    }
  }
}).then((start) => start(null))
