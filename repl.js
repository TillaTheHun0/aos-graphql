import readline from 'node:readline'
import { createReadStream } from 'node:fs'
import { Readable } from 'node:stream'

import AoLoader from '@permaweb/ao-loader'

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

async function replWith ({ stream, env }) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  })

  function createEval (line) {
    return {
      Id: 'message',
      Target: env.Process.Id,
      From: env.Process.Owner,
      Owner: env.Process.Owner,
      'Block-Height': '1000',
      Module: env.Module.Id,
      Tags: [
        { name: 'Action', value: 'Eval' }
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

  return (init) => trampoline(() => repl(init))
    .finally(() => rl.close())
}

replWith({
  stream: await binaryStream(!!process.env.USE_AOS),
  env: {
    Process: {
      Id: 'PROCESS_TEST',
      Owner: 'OWNER',
      Tags: [
        { name: 'Module', value: 'aos-graphql' }
      ]
    },
    Module: {
      Id: 'MODULE_TEST',
      Owner: 'OWNER',
      Tags: []
    }
  }
}).then((start) => start(null))
