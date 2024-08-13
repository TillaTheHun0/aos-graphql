local server = require('.graphql.server.init')

local utils = require('.graphql.gateway.utils')
local api = require('.graphql.gateway.api')
local schema = require('.graphql.gateway.schema.init')

local function createServer (kind)
  return function (args)
    local persistence = args.persistence
    local dal

    -- Create Data Access Layer
    if persistence.type == 'sqlite' then
      dal = require('.graphql.gateway.dal.sqlite')({ client = persistence.client })
    else
      assert(false, 'Persistence engine "' .. persistence.type .. '" not supported. Valid options are: [sqlite]')
    end

    -- Compose Business logic on top of data access layer
    local apis = api.createApis({ dal = dal })

    -- Create the GraphQL Server
    return server[kind]({
      schema = schema,
      context = function (info)
        -- Expose apis on contextValue to all resolvers
        local contextValue = utils.mergeAll({ info, apis })
        return contextValue
      end
    })
  end
end

local create = createServer('create')
local aos = createServer('aos')

return { create = create, aos = aos }
