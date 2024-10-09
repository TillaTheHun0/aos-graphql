(function ()
  -- START APM
  require('.graphql.runtime')
  require('.graphql.server')
  -- END APM

  local graphql = require('@tilla/graphql')
  local server = require('@tilla/graphql_server')

  local _schema, types = graphql.schema, graphql.types

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

  -- primary index
  local dbById = {}
  for _, v in ipairs(db) do dbById[v.id] = v end

  local function findPersonById (id)
    return dbById[id]
  end

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

  Gql = server.aos({
    schema = schema,
    context = function ()
      return {
        findPersonById = findPersonById,
        db = db
      }
    end
  })
end)()
