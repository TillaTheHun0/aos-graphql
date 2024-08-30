import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import readline from 'node:readline'
import { createReadStream, readFileSync } from 'node:fs'
import { Readable } from 'node:stream'
import { randomInt, randomUUID } from 'node:crypto'

import chalk from 'chalk'
import luaJson from 'lua-json'
import AoLoader from '@permaweb/ao-loader'

const __dirname = dirname(fileURLToPath(import.meta.url))

function binaryStream (USE_AOS) {
  if (USE_AOS) {
    console.log('Using aos base module...')
    return fetch('https://arweave.net/raw/xT0ogTeagEGuySbKuUoo_NaWeeBv1fZ4MqgDdKVKY0U').then(res => res.body)
  }
  return Promise.resolve(Readable.toWeb(createReadStream('./process.wasm')))
}

function toTable (obj) {
  const t = luaJson.format({ ...obj, TagArray: obj.Tags }, { spaces: 0, eol: '', singleQuote: true })
  /**
   * HACK
   *
   * - remove 'return' from beginning
   * - remove dangling commas before closing } in tables
   */
  return t
    .substring('return'.length)
    .replace(/,}/g, '}')
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
    let Action = 'Eval'
    const tags = [
      { name: 'Message-Count', value: `${++messageCount}` }
    ]

    if (line === 'sample-gql') {
      console.log(chalk.blue('Initializing sample GraphQL Server...'))
      console.log(chalk.blue([
        'Example:',
        '',
        'Gql:resolve(\'query GetPerson ($id: ID!) { person (id: $id) { firstName, lastName, age } }\', { id = "id-2" })',
        'Gql:resolve(\'query GetPersons { persons { firstName, lastName } }\''
      ].join('\n')))
      const init = readFileSync(join(__dirname, 'server.lua'), 'utf-8')
      line = init
    } else if (line === 'gateway') {
      console.log(chalk.green('Initializing Arweave GraphQL Gateway...'))
      const init = readFileSync(join(__dirname, 'gateway.lua'), 'utf-8')
      line = init
    } else if (line.startsWith('query') || line.startsWith('mutation')) {
      const [operation, variables] = line.split('|').map(l => l.trim())
      Action = 'GraphQL.Operation'
      tags.push({ name: 'Content-Type', value: 'application/json' })
      tags.push({ name: 'Operation', value: operation })
      line = variables ? JSON.stringify(JSON.parse(variables)) : '1234'
    }

    const id = randomUUID()

    return {
      Id: id,
      Target: env.Process.Id,
      From: env.Process.Owner,
      Owner: env.Process.Owner,
      'Block-Height': randomInt(1_000_000, 1_500_000),
      Module: env.Module.Id,
      Tags: [
        { name: 'Action', value: Action },
        ...tags
      ],
      Timestamp: new Date().getTime(),
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
        if (line.startsWith('msg-')) {
          console.log(toTable(createEval(line.substring('msg-'.length))))
          // prompt for next input into repl
          return resolve(() => repl(memory))
        }

        try {
          const message = createEval(line)
          const { Memory, Messages, Output, Error } = await handle(memory, message, env)
          if (Error) console.error(Error)
          if (Output?.data) console.log(Output?.data)
          if (Messages && Messages.length) Messages.forEach((m) => console.log(m))
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
