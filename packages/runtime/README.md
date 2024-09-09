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
# Spin up a aos-sqlite-graphql process with 1-gb memory limit
aos --module="_wjbCuCyUTmKAseOfEj0NzrCNUgKcMqBGaSzNySzMoY"
```

## Usage

First, install the module using [APM](https://apm.betteridea.dev/):

```lua
APM.install("@tilla/graphql")
```

Once installation has finished, you can `require('@tilla/graphql.init')` in order to
build your GraphQL types, schema, and execution.

> If you would like a turnkey GraphQL Server, you can use
> [`@tilla/graphql_server`](../server/), which has OOTB `aos` integration.

```lua
local parse = require('@tilla/graphql.parse')
local schema = require('@tilla/graphql.schema')
local types = require('@tilla/graphql.types')
local validate = require('@tilla/graphql.validate')
local execute = require('@tilla/graphql.execute')

local Bob = {
  id = 'id-1',
  firstName = 'Bob',
  lastName = 'Ross',
  age = 52
}
local Jane = {
  id = 'id-2',
  firstName = 'Jane',
  lastName = 'Doe',
  age = 40
}
local John = {
  id = 'id-3',
  firstName = 'John',
  lastName = 'Locke',
  age = 44
}

-- Mock db
local db = { Bob, Jane, John }
-- Index by id
local dbById = {}
for k, v in ipairs(db) do dbById[v.id] = v end

local function findPersonById (id)
  return dbById[id]
end

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
        resolve = function(rootValue, arguments, contextValue, info)
          local findPersonById = contextValue.findPersonById
          return findPersonById(arguments.id)
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
query GetPerson($id: ID) {
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
local contextValue = { findPersonById = findPersonById }
local variables = { id = 1 }
local operationName = 'GetPerson'

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
