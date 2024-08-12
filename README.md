# aos-graphql

> [!CAUTION]
> **This is an experimental repo, and under active development**
>
> **As such, this repo may become out-of-date and may not work out-of-the-box, and no Tier 1 support from
> the AO dev team is offered for this repository.**

This is a PoC for implementing the GraphQL Runtime in ao.

## Goals

The goal is to demonstrate a functioning GraphQL server running inside an ao Process. This involves receive a GraphQL operation, parsing it, resolving it, then returning the result as a Lua table.

## Prerequisites

- `ao` dev-cli `0.1.3`
- `cmake` and `make` 
- If running the `repl.js`, you'll need `NodeJS 22+` and `npm`

## Getting Started

Initialize the `aos` submodule using `git submodule update --init`. You can update the submodule to latest by running `git submodule update --remote`.

Then either use `cmake`, or if you have `npm`, simply run `npm run build` to produce the wasm with a built-in graphql runtime implementation

> If using the `repl.js` you'll need to also install dependencies using `npm i`

## How it works

The Lua implementation of the GraphQL runtime is located in the `graphql` folder.

The Lua implementation depends on a a [pure C implementation](./parser/libgraphqlparser) of a GraphQL operation parser, `libgraphqlparser`, copied from [The GraphQL foundation here](https://github.com/graphql/libgraphqlparser).

Lua requires bindings in order to invoke the C parser, which is implemented [here](./parser/luagraphqlparser)

When running the root `cmake`:

- The C implementation is compiled into a static library (`.a`)
- The Lua bindings are then compiled, along with the compiled C implementation into a static library `.a`
- The Lua implementation of the GraphQL runtime, along with the `.a` are copied in `aos/process/graphql` and `aos/process/libs`
- The `ao` dev-cli is used to build the aos process code into a `process.wasm`, which is then copied to the root of the repo, to be loaded by the `repl.js`, if desired.

## Sample GraphQL

A sample graphql server is implemented in `server.lua` and can be hotloaded via the `repl.js` using executing `sample-gql`

## Known Outstanding Issues
