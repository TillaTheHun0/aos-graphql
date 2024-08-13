(function ()
  local graphql = require('.graphql.init')

  local schema, types = graphql.schema, graphql.types

  local server = require('.graphql.server.init')

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
    age = 40,
    friends = {Bob.id}
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
        age = types.int.nonNull,
        friends = {
          kind = types.list(Person.nonNull).nonNull,
          resolve = function (parent, _, contextValue)
            local person = contextValue.dbById[parent.id]
            return map(
              function (id) return contextValue.dbById[id] end,
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
    resolve = function (_, arguments, contextValue)
      return contextValue.dbById[arguments.id or 'id-3']
    end
  }

  local PersonsQuery = {
    kind = types.list(Person.nonNull).nonNull,
    resolve = function (_, _, contextValue)
      return contextValue.db
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

  local gql = server.create({
    schema = Schema,
    context = function () return { db = db, dbById = dbById } end
  })

  return gql
end)()
