local parse = require('.graphql.parse')
local schema = require('.graphql.schema')
local types = require('.graphql.types')
local validate = require('.graphql.validate')
local execute = require('.graphql.execute')

-- Mock store of Persons, indexed by id
local db = {
  ['id-1'] = {
    id = 'id-1',
    firstName = 'Bob',
    lastName = 'Ross',
    age = 52
  },
  ['id-2'] = {
    id = 'id-2',
    firstName = 'Jane',
    lastName = 'Doe',
    age = 40
  },
  ['id-3'] = {
    id = 'id-3',
    firstName = 'John',
    lastName = 'Locke',
    age = 44
  }
}

-- Create a type
local Person = types.object({
  name = 'Person',
  fields = {
    id = types.id.nonNull,
    firstName = types.string.nonNull,
    lastName = types.string.nonNull,
    age = types.int.nonNull
  }
})

-- Create a Query
local PersonQuery = {
  kind = Person,
  arguments = {
    id = types.id
  },
  resolve = function (rootValue, arguments)
    return db[arguments.id]
  end
}

-- Create the schema
local Schema = schema.create({
  query = types.object({
    name = 'Query',
    fields = {
      person = PersonQuery
    }
  })
})

local server = function (_schema)
  return function (operation, variables)
    local ast = parse(operation)

    -- Validate a parsed query against a schema
    validate(_schema, ast)

    print(ast)

    -- TODO: Shouldn't this be nil?
    local rootValue = {}
    -- TODO: Can we grab from ast?
    local operationName = 'Foo'

    local result = execute(_schema, ast, rootValue, variables, operationName)
    return result
  end
end

return server(Schema)
