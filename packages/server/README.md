# GraphQL Server Lua

A GraphQL Server implementation with OOTB integration with the [`aos` Handlers api](https://github.com/permaweb/aos/blob/main/process/handlers.md)

<!-- toc -->

- [Prerequisites](#prerequisites)
- [Usage](#usage)
  - [Usage with `aos`](#usage-with-aos)
  - [Provide Context](#provide-context)

<!-- tocstop -->

## Prerequisites

- The GraphQL runtime implementation [here](../runtime)

## Usage

Create a standalone GraphQL Server:

```lua
local server = require('@tilla/graphql_server')

-- Your graphql schema
local schema = {...}

local gql = server.create({ schema = schema })

local operation = [[
  query GetPerson ($id: ID!) {
    person (id: $id) {
      firstName
      lastName
    }
  }
]]

local result = gql(operation, { id = "id-1" })
--[[
{
   person = {
     firstName = "John",
     lastName = "Locke"
  }
}
]]
```

### Usage with `aos`

This GraphQL Server has OOTB support for `aos` and its `Handlers` api:


```lua
local server = require('.graphql.server.init')

-- Your graphql schema
local schema = {...}

--[[
  This will add a handler named "graphql" that will receive
  any "Action" = "GraphQL" msgs the aos process receives.
  The result of the operation will be sent back as a message
  whose Data contains the result of the operation

  The following msg payloads are supported:

  -- With operation as a tag and optional variables as Data
  {
    ...
    Tags = {
      { name = "Operation", value: "query GetPerson ($id: ID!) { person (id: $id) { firstName, lastName } }" }
    },
    Data = { id = "id-1" }
  }

  -- With operation as Data
  {
    Data = query { person(id: "id-1") { firstName, lastName } }
  }
]]
local gql = server.aos({ schema = schema })

-- You can still send operations directly to your server returned
local result = gql(
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

### Provide Context

When creating a server, in addition to providing `schema`, you can also provide a function called `context`. This function will be invoked each time an operation is resolved. `context` return value will then be passed as the `contextValue` argument (aka. 3rd argument) to each resolver invoked in order to resolve the query.

`contextValue` can be used to inject dependencies into your resolvers ie. business logic apis, database connections, etc.

```lua

-- Some api
function findPerson (id) ... end

local gql = server.create({
  schema = schema,
  context = function (info)
    local contextValue = { findPerson = findPerson, userId = info.userId }
    return contextValue
  end
})

local result = gql(
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

- When using `server.create`, `info` provided to `context` will be the 3rd argument provided to the server function
- When using `server.aos`, `info` provided to `context` will be a table containing `{ msg, ao }` for the current message being evaluated
