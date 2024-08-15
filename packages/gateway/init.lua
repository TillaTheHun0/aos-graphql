local server = require('.graphql.server.init')

local utils = require('.graphql.gateway.utils')
local api = require('.graphql.gateway.api')
local schema = require('.graphql.gateway.schema.init')

local function createServer (kind)
  return function (args)
    local pType, pClient = args.persistence.type, args.persistence.client
    local dal

    -- Create Data Access Layer
    if pType == 'sqlite_json' then
      dal = require('.graphql.gateway.dal.sqlite_json.init')({ client = pClient })
    else
      assert(false, string.format('Persistence engine "%s" not implemented. Valid types are: [sqlite_json]', pType))
    end

    -- Compose Business logic on top of data access layer
    local apis = api.createApis({ dal = dal })

    -- Create the GraphQL Server
    local gql = server[kind]({
      schema = schema,
      context = function (info)
        -- Expose apis on contextValue to all resolvers
        local contextValue = utils.mergeAll({ info, apis })
        return contextValue
      end
    })

    -- We expose this api, so that transactions used to power the graph can be saved
    gql.saveTransaction = apis.saveTransaction

    if kind == 'aos' then
      --[[
        TODO: add handler to treat incoming msgs as transactions
        to save in persistence
      ]]

      Handlers.append()
    end

    return gql
  end
end

local create = createServer('create')
local aos = createServer('aos')

return { create = create, aos = aos }
