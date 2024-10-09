local graphql = require('@tilla/graphql.init')
local server = require('@tilla/graphql_server.init')

local types, _schema = graphql.types, graphql.schema

-- Dal

local bob = {
  id = 'id-1',
  firstName = 'Bob',
  lastName = 'Ross',
  age = 52,
  friends = {}
}

local jane = {
  id = 'id-2',
  firstName = 'Jane',
  middleName = 'Lorraine',
  lastName = 'Doe',
  age = 40,
  friends = {bob.id}
}

local john = {
  id = 'id-3',
  firstName = 'John',
  lastName = 'Locke',
  age = 44,
  friends = {jane.id, bob.id}
}
-- mock db
local db = { bob, jane, john }
-- primary index
local dbById = {}
for _, v in ipairs(db) do dbById[v.id] = v end

local function findPersonById (id)
  return dbById[id]
end

-- Schema

local person
person = types.object({
  name = 'Person',
  fields = function ()
    return {
      id = types.id.nonNull,
      firstName = types.string.nonNull,
      middleName = types.string,
      lastName = types.string.nonNull,
      age = types.int.nonNull,
      friends = {
        kind = types.list(person.nonNull).nonNull,
        resolve = function (parent, _, contextValue)
          local findPersonById = contextValue.findPersonById

          local p = findPersonById(parent.id)

          local friends = {}
          for _, id in ipairs(p.friends) do
            table.insert(friends, findPersonById(id))
          end

          return friends
        end
      }
    }
  end
})

local schema = _schema.create({
  query = types.object({
    name = 'Query',
    fields = {
      person = {
        kind = person,
        arguments = {
          id = {
            kind = types.id,
            defaultValue = 'id-1'
          }
        },
        resolve = function (_, arguments, contextValue)
          local findPersonById = contextValue.findPersonById
          return findPersonById(arguments.id)
        end
      },
      people = {
        kind = types.list(person.nonNull).nonNull,
        resolve = function (_, _, contextValue)
          local db = contextValue.db
          return db
        end
      }
    }
  })
})

Server = server.new({
  schema = schema,
  context = function ()
    return {
      findPersonById = findPersonById,
      db = db
    }
  end
})
