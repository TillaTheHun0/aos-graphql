# aos-graphql

> [!CAUTION] **This is an experimental repo, and under active development**
>
> **As such, this repo may become out-of-date and may not work out-of-the-box,
> and no Tier 1 support from the AO dev team is offered for this repository.**

This is a PoC for implementing the GraphQL Runtime in ao.

<!-- toc -->

- [Goals](#goals)
- [Modules](#modules)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Repl Usage](#repl-usage)
- [Known Outstanding Issues](#known-outstanding-issues)

<!-- tocstop -->

## Goals

The goal is to demonstrate a functioning GraphQL runtime running inside an ao
Process. This involves parsing a GraphQL operation, validating it against a
schema, resolving it, then returning the result.

Additionally, we'd like to build a simple GraphQL server that is able to accept
an operation and then resolve it using the GraphQL runtime.

Finally, we'd like to build a PoC of the Arweave GraphQL Gateway and an Indexer
that can index incoming messages and then query against using the Arweave
GraphQL Gateway API.

## Modules

- [`runtime`](./packages/runtime): the GraphQL runtime Lua implementation, with
  a parser written in C and accompanied Lua bindings.
- [`server`](./packages/server): a GraphQL server Lua implementation, with OOTB
  integration with `aos` via it's `Handlers` API.
- [`gateway`](./packages/gateway): a Arweave GraphQL Gateway Lua implementation,
  with OOTB integration with `aos` via it's `Handlers` API.

## Prerequisites

- `ao` dev-cli `0.1.3`
- `cmake` and `make`
- If running the `repl.js`, you'll need `NodeJS 22+` and `npm`

## Getting Started

Initialize the `aos` submodule using `git submodule update --init`. You can
update the submodule to latest by running `git submodule update --remote`.

Then either use `cmake`, or if you have `npm`, simply run `npm run build:sandbox` to
produce the wasm with a built-in graphql runtime, server, and gateway implementation,
as well as SQLite bindings. The WASM produced can be used, turnkey, with the repl.

> If using the `repl.js` you'll need to also install dependencies using `npm i`

## Repl Usage

You can `npm run dev` to start the repl with hot wasm reloading.

Run `gateway` to configure a gateway for local development (see
[gateway.lua](./gateway.lua))

Run `sample-gql` for a sample gql server (see [server.lua](./server.lua))

## Known Outstanding Issues
