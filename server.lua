(function ()
  local parse = require('.graphql.parse')
  local schema = require('.graphql.schema')
  local types = require('.graphql.types')
  local validate = require('.graphql.validate')
  local execute = require('.graphql.execute')

  local function reduce (fn, initial, t)
    assert(type(fn) == "function", "first argument should be a function that accepts (result, value, key)")
    local result = initial
    for k, v in pairs(t) do
      if result == nil then
        result = v
      else
        result = fn(result, v, k)
      end
    end
    return result
  end

  local function map (fn, t)
    return reduce(
      function (result, v, k)
        result[k] = fn(v, k)
        return result
      end,
      {},
      t
    )
  end

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

  -- Mock db primary index
  local dbById = reduce(
    function (acc, v) acc[v.id] = v; return acc end,
    {},
    db
  )

  -- Create a type
  Person = types.object({
    name = 'Person',
    fields = function ()
      return {
        id = types.id.nonNull,
        firstName = types.string.nonNull,
        lastName = types.string.nonNull,
        age = {
          kind = types.int.nonNull,
          resolve = function (parent, _, contextValue)
            print(contextValue)
            return parent.age + 23
          end
        },
        friends = {
          kind = types.list(Person.nonNull).nonNull,
          resolve = function (rootValue)
            local person = dbById[rootValue.id]
            print("person", person)
            return map(
              function (id) return { id = id } end,
              person.friends or {}
            )
          end
        }
      }
    end
  })

  -- Create a Query
  local PersonQuery = {
    kind = Person,
    arguments = {
      id = types.id
    },
    resolve = function (rootValue, arguments, contextValue)
      print(contextValue)
      return dbById[arguments.id or 'id-3']
    end
  }

  local PersonsQuery = {
    kind = types.list(Person.nonNull).nonNull,
    resolve = function (rootValue)
      return db
    end
  }

  -- Create the schema
  local Schema = schema.create({
    query = types.object({
      name = 'Query',
      fields = {
        person = PersonQuery,
        persons = PersonsQuery
      }
    })
  })

  local server = function (_schema)
    return function (operation, variables)
      -- TODO: arguments seem to break parsing
      local ast = parse(operation)

      -- Validate a parsed query against a schema
      validate(_schema, ast)

      -- TODO: Shouldn't this be nil?
      local rootValue = {}
      local contextValue = { foo = 'bar' }
      -- TODO: Does this lock down the operation to specific named operations?
      -- TODO: can we grab from ast?
      local operationName = nil

      local result = execute(_schema, ast, rootValue, contextValue, variables, operationName)
      return result
    end
  end

  return server(Schema)
end)()
