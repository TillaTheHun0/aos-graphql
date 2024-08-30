# GraphQL Lua

An Lua implementation of the GraphQL runtime.

Originally forked from
[this implementation](https://github.com/tarantool/graphql). Thank you to [bjornbytes](https://github.com/bjornbytes/graphql-lua) and the [tarantool team](https://github.com/tarantool/graphql) for the fantastic work on the runtime, up until this point.

<!-- toc -->

- [Prerequisites](#prerequisites)
- [Usage](#usage)

<!-- tocstop -->

## Prerequisites

When spinning up `aos`, you will need to specify the `ao` Module which includes
the GraphQL parser and lua bindings.

```sh
aos --module="<need_module>"
```

## Usage

First, install the module using [APM](https://apm.betteridea.dev/):

```sh
APM.install("@tilla/graphql")
```

Once installation has finished, you can `require('@tilla/graphql')` in order to
build your GraphQL types, schema, and execution.

> If you would like a turnkey GraphQL Server, you can use
> [`@tilla/graphql_server`](../server/), which has OOTB `aos` integration.

```lua
local parse = require('@tilla/graphql.parse')
local schema = require('@tilla/graphql.schema')
local types = require('@tilla/graphql.types')
local validate = require('@tilla/graphql.validate')
local execute = require('@tilla/graphql.execute')

--[[
  First define your types and resolvers

  Additional APIs:

  types.long
  types.list()
  types.enum()
  types.nonNull()
  types.nullable()
  types.scalar()
  types.inputObject()
]]

-- Create a type
local Person = types.object({
  name = 'Person',
  fields = {
    id = types.id.nonNull,
    firstName = types.string.nonNull,
    middleName = types.string,
    lastName = types.string.nonNull,
    age = types.int.nonNull
  }
})

-- Create a schema
local schema = schema.create({
  query = types.object({
    name = 'Query',
    fields = {
      person = {
        kind = Person,
        arguments = {
          id = types.id,
          defaultValue = 1
        },
        resolve = function(rootValue, arguments, context, info)
          if arguments.id ~= 1 then return nil end

          return {
            id = 1,
            firstName = 'Bob',
            lastName = 'Ross',
            age = 52
          }
        end
      }
    }
  })
})

--[[
  Now you can parse operations and execute your schema!
]]

-- Parse a query
local ast = parse [[
query getUser($id: ID) {
  person(id: $id) {
    firstName
    lastName
  }
}
]]

-- Validate a parsed query against a schema
validate(schema, ast)

-- Execution
local rootValue = {}
local contextValue = {}
local variables = { id = 1 }
local operationName = 'getUser'

execute(schema, ast, rootValue, contextValue, variables, operationName)

--[[
{
  person = {
    firstName = 'Bob',
    lastName = 'Ross'
  }
}
]]
```
