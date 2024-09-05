# GraphQL Server Lua

A GraphQL Server implementation with OOTB integration with the
[`aos` Handlers api](https://github.com/permaweb/aos/blob/main/process/handlers.md)

<!-- toc -->

- [Prerequisites](#prerequisites)
- [Usage](#usage)
  - [Standalone Server](#standalone-server)
  - [`aos` Handler](#aos-handler)
  - [Message Payloads](#message-payloads)
  - [Provide Context](#provide-context)

<!-- tocstop -->

## Prerequisites

- The GraphQL runtime implementation [here](../runtime)

## Usage

First, install the module using [APM](https://apm.betteridea.dev/):

```sh
APM.install("@tilla/graphql_server")
```

Once installation has finished, you can `require('@tilla/graphql_server.init')` in
order to create your GraphQL Server to server your `schema`.

### Standalone Server

You can create a standalone GraphQL Server:

```lua
local GraphQLServer = require('@tilla/graphql_server.init')

-- Your graphql schema
local schema = {...}

local gql = GraphQLServer.new({ schema = schema })

local operation = [[
  query GetPerson ($id: ID!) {
    person (id: $id) {
      firstName
      lastName
    }
  }
]]

local result = gql:resolve(operation, { id = "id-1" })
--[[
{
   person = {
     firstName = "John",
     lastName = "Locke"
  }
}
]]

-- Or just validate the operation against your schema
local ast = gql:validate(operation)
```

### `aos` Handler

This GraphQL Server has OOTB support for `aos` and its `Handlers` api:

```lua
-- Your graphql schema
local schema = {...}

local gql = require('@tilla/graphql_server.init').aos({ schema = schema })
```

This will add an `aos` handler named `GraphQL.Server` that will handle any
`Action = "GraphQL.Operation"` msgs received by the process.

The resolved graphql operation will be sent back as a message, whose `Data`
contains the result of the operation.

You can also still send operations directly to your `gql` server:

```lua
-- You can still send operations directly to your server
local result = gql:resolve(
[[
  query GetPerson ($id: ID!) {
    person (id: $id) {
      firstName
      lastName
    }
  }
]],
{ id = "id-1" }
)
--[[
{
   person = {
     firstName = "John",
     lastName = "Locke"
  }
}
]]
```

### Message Payloads

The following message payloads are supported by the `GraphQL.Server` Handler:

With `Operation` tag and `Data` as optional operation `variables`:

```lua
Gateway = "<some_gateway_id>"
Operation = [[
  query GetPerson ($id: ID!) {
    person (id: $id) {
      firstName,
      lastName 
    }
  }
]]
Send({ Target = Gateway, Action = "GraphQL.Operation", Operation = Operation,  Data = { id = "id-1" } })
```

If there are no `variables`, you can simply provide your `Operation` as `Data`:

```lua
Gateway = "<some_gateway_id>"
Operation = [[
  query GetPersons {
    persons {
      firstName,
      lastName 
    }
  }
]]
Send({ Target = Gateway, Action = "GraphQL.Operation", Data = Operation })
-- Or as a tag
Send({ Target = Gateway, Action = "GraphQL.Operation", Operation = Operation })
```

### Provide Context

When creating a server, in addition to providing `schema`, you can also provide
a function called `context`, which will be invoked each time an operation is
resolved. `context`'s return value will then be passed as the `contextValue`
argument (aka. 3rd argument) to each resolver invoked during resolution.

`contextValue` is great for injecting dependencies into your resolvers ie.
business logic apis, database connections, etc.

```lua
-- Some api
function findPerson (id) ... end

local gql = GraphQLServer.new({
  schema = schema,
  context = function (info)
    local contextValue = { findPerson = findPerson, userId = info.userId }
    return contextValue
  end
})

local result = gql:resolve(
[[
  query GetPerson ($id: ID!) {
    person (id: $id) {
      firstName
      lastName
    }
  }
]],
{ id = "id-1" },
{ userId = "id-4" }
)

-- Later on in the person resolver
function PersonQueryResolver (_, arguments, contextValue)
  local findPerson = contextValue.findPerson
  return findPerson(arguments.id)
end
```

- When using `new`, the `info` provided to `context` will be the 3rd argument
  provided to the `gql:resolve`
- When using `aos`, the `info` provided to `context` will be a table containing
  `{ msg, ao }` for the current message being evaluated
