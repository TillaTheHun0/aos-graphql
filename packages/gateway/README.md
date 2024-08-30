# Arweave GraphQL Gateway Lua 

An implementation of the Arweave GraphQL Gateway, to be ran within
[ao](https://ao.arweave.dev), with OOTB integration for
[`aos`](https://github.com/permaweb/aos).

Index transactions as `ao` Messages, then query them using the Arweave GraphQL
Gateway schema.

<!-- toc -->

- [Prerequisites](#prerequisites)
- [Usage](#usage)
  - [Standalone Gateway](#standalone-gateway)
  - [Indexing](#indexing)
  - [`aos` Handlers](#aos-handlers)
    - [Options](#options)
- [Outstanding Issues](#outstanding-issues)

<!-- tocstop -->

## Prerequisites

You will need to have `aos` and it's built-in primitives ie. `json`, `bint`, and
`base64`

> If using persistence based on `sqlite`, you will need `sqlite` and associate
> lua bindings as part of your `ao` Module.
>
> As a convenience during development, these are copied as `libs` from
> [here](../../ao_libs)

You will need to have the
[Lua GraphQL Runtime Implementation available](../runtime) You will also need to
have [Lua GraphQL Server Implementation available](../server/)

## Usage

First, install using [APM](https://apm.betteridea.dev/):

```sh
APM.install("@tilla/graphql_arweave_gateway")
```

Once installation has finished, you can
`require("@tilla/graphql_arweave_gateway")` in order to create your Arweave
Gateway.

### Standalone Gateway

You can create a standalone Arweave GraphQL Indexer+Gateway:

```lua
Gateway = require('@tilla/graphql_arweave_gateway').new()

-- save a transaction to be indexed
Gateway.saveTransaction(msg)

-- send an operation to the GraphQL Server
Gateway.gql:resolve([[
  query GetTransactions {
    transactions {
      edges {
        node {
          id
          tags {
            name
            value
          }
          owner {
            address
          }
        }
      }
    }
  }
]])
```

### Indexing

Indexing is done using `sqlite`. In the future, we may add support for
implementing indexing using other types of persistence.

> TODO: add docs on custom persistence types

### `aos` Handlers

This implementation has OOTB support for `aos` and its `Handlers` api:

```lua
Gateway = require('@tilla/graphql_arweave_gateway').aos()
```

In addition to the [`GraphQL.Server` Handler](../server/README.md#aos-handler)
that will handle `GraphQL.Operation` messages, a `GraphQL.Indexer` is added
directly after `GraphQL.Server` that will index any messages that satisfy the
`MatchSpec`.

> Make sure to add the appropriate `assignables` to your `aos` process that will
> configure it to accept expected assigned messages.

#### Options

When creating an `aos` Gateway without options, a default `MatchSpec` is used
for determining whether or not to intercept and index the incoming message:

- The message is not a `Cron` message
- The message is not an `Eval` targeting this process

Alternatively, to customize the Indexing behavior, you may provide a custom
`MatchSpec`, so as to only index messages that satisy the provided `MatchSpec`:

```lua
Gateway = require('@tilla/graphql_arweave_gateway').aos({
  match = function (msg) return msg.Action === 'Index-Me' end
})
```

If you are okay with the default `MatchSpec`, but would like the message to
instead continue to flow through your subsequent Handlers, you can provide a
short-hand option, `continue`, to inform the `Indexer` to continue handler
execution after Indexing is complete:

```lua
Gateway = require('@tilla/graphql_arweave_gateway').aos({ continue = true })
```

## Outstanding Issues

1. Some values available on Arweave Gateways are not available on `ao` messages
   and so cannot be resolved by the Graph. For now, these values will always be
   set to `nil`:

- `fee`
- `quantity`
- `bundledIn`
- `block` (timestamp, id, previous -- we _do_ have `height`)

2. `block` and `blocks` queries are currently not implemented due to not being
   comprehensively available on `ao`
