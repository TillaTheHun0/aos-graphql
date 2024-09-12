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
    - [Assignments](#assignments)
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

You can install both using APM:

```lua
APM.install("@tilla/graphql")
APM.install("@tilla/graphql_server")
```

## Usage

First, install using [APM](https://apm.betteridea.dev/):

```lua
APM.install("@tilla/graphql_arweave_gateway")
```

Once installation has finished, you can
`require("@tilla/graphql_arweave_gateway.init")` in order to create your Arweave
Gateway.

### Standalone Gateway

You can create a standalone Arweave GraphQL Indexer+Gateway:

```lua
Gateway = require('@tilla/graphql_arweave_gateway.init').new()

-- index a transaction
Gateway:index(msg)

-- resolve an operation using the Gateway GraphQL Server
Gateway:resolve([[
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

To index a transaction manually, simply call `Gateway:index(tx)`. The
transaction is expected to be in this shape:

```lua
local Tx = {
  id = '...', -- required
  anchor = '...',
  signature = '...',
  owner = '...',
  fee = 123,
  quantity = 123,
  tags = {
    { name = 'Foo', value = 'Bar' }
  },
  timestamp = 1726175553589
  target = '...',
  bundle_Id = '...'
  --[[
    Block information can either be provided as a 'Block' field
    or as top-lvl fields prefixed with 'Block-' ie. 'Block-Height'
  ]]
  block = {
    Id = '...',
    Height = 123,
    Timestamp = 1726175553589,
    Previous = '...'
  }
}
```

> When creating a gateway using `Gateway.aos()`, an `aos` Handler is added that
> will automatically map and index certain incoming `Messages`. See
> [below](#aos-handlers)

#### Indexing Implementation

By default, indexing is done using an implementation built on top of `sqlite`.
In the future, we may add support for implementing indexing using other types of
persistence.

When creating a `Gateway`, you can alternatively provide your own indexing
implementation. The gateway will then use this to index any data when calling
`Gateway:index(tx)` and to resolve graphql operations using
`Gateway.resolve(operation, variables)`:

```lua
local Gateway = gateway.new({
  dal = {
    type = 'your_imple_name',
    impl = {
      findTransactionById = function (id) ... end
      findTransactions = function (crteria) ... end
      saveTransaction = function (tx) ... end
    }
  }
})

--criteria passed to findTransactions will look like:
{
  ids = {...}, -- optional
  recipients = {...}, -- optional
  owners = {...}, -- optional
  block = { min = 123, max = 123 }, -- optional
  bundledIn = '...', --optional
  tags = { -- optional
    { name = 'Foo', values = {'Bar', 'Buzz'} },
    { name = 'Bar', values = {'Fizz', 'Buzz'}, op = 'NEQ' }
  },
  limit = 10, -- will always be 1 <= limit <= 1000
  sort = 'desc' -- always 'desc' or 'asc'
  after = { id = '...', timestamp = '...', height = 123 } -- optional
}

-- tx will be shaped like the Transaction example above
```

### `aos` Handlers

This implementation has OOTB support for `aos` and its `Handlers` api:

```lua
Gateway = require('@tilla/graphql_arweave_gateway.init').aos()
```

In addition to the [`GraphQL.Server` Handler](../server/README.md#aos-handler)
that will handle `GraphQL.Operation` messages, a `GraphQL.Indexer` is added
directly after `GraphQL.Server` that will index any messages that satisfy the
`MatchSpec`.

#### Assignments

If the process will be indexing `assignments` it receives, be sure to add the
appropriate `assignables` `MatchSpec` to allow/deny the desired assignments:

```lua
ao.addAssignable('all', function (msg) return msg.Action == 'Index-Me' end)
```

#### Options

When creating an `aos` Gateway without options, a default `MatchSpec` is used
for determining whether or not to intercept and index the incoming message:

- The message is not a `Cron` message
- The message is not an `Eval` targeting this process
- The message is not an `APM` message

Alternatively, to customize the Indexing behavior, you may provide a custom
`MatchSpec`, so as to only index messages that satisy the provided `MatchSpec`:

```lua
Gateway = require('@tilla/graphql_arweave_gateway.init').aos({
  match = function (msg) return msg.Action === 'Index-Me' end
})
```

If you are okay with the default `MatchSpec`, but would like the message to
instead continue to flow through your subsequent Handlers, you can provide a
short-hand option, `continue`, to inform the `Indexer` to continue handler
execution after Indexing is complete:

```lua
Gateway = require('@tilla/graphql_arweave_gateway.init').aos({ continue = true })
```

## Outstanding Issues

1. Some values available on Arweave Gateways are not natively available on `ao`
   messages.

- `fee`
- `quantity`
- `bundledIn`
- `block` (timestamp, id, previous -- we _do_ have `height`)

If you'd like those values indexed, then you will need to map those values from
native fields off of the `ao` message ie. `Data` or `Tags`, before calling
`Gateway:index`. You can see the expected input shape for indexing
[above](#indexing)

2. `block` and `blocks` queries are currently not implemented due to not being
   comprehensively available on `ao`
