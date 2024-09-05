local graphql = require('@tilla/graphql.init')

local parse = graphql.parse
local validate = graphql.validate
local execute = graphql.execute

local Server = {
  _version = '0.0.2',
  constants = {
    aos = {
      ServerHandler = 'GraphQL.Server',
      MessageAction = 'GraphQL.Operation'
    }
  }
}
Server.__index = Server

Server.new = function (args)
  local self = setmetatable({}, Server)
  self.schema = args.schema
  self.context = args.context or function () return {} end

  return self
end

--[[
  Construct a graphql server, and prepend an aos Handler
  to handle GraphQL operation messages
]]
Server.aos = function (args)
  args.context = args.context or function (c) return c or {} end

  local gql = Server.new({
    schema = args.schema,
    context = function (info)
      info = info or {}
      local contextValue = args.context({ msg = info.msg, ao = info.ao })
      return contextValue
    end
  })

  Handlers.prepend(
    gql.constants.aos.ServerHandler,
    function (msg) return msg.Tags.Action == gql.constants.aos.MessageAction end,
    function (msg)
      local operation, variables
      if msg.Tags.Operation then
        operation = msg.Tags.Operation
        variables = msg.Data
      else
        operation = msg.Data
      end

      if type(variables) ~= 'table' then variables = {} end

      local info = { msg = msg, ao = ao }
      local result = gql:resolve(operation, variables, info)

      ao.send({ Target = msg.From, Data = result })
    end
  )

  return gql
end

function Server:validate (operation)
  local ast = parse(operation)
  validate(self.schema, ast)
  return ast
end

function Server:resolve (operation, variables, info)
  local contextValue = self.context(info)

  -- Validate a parsed operation against the schema
  local ast = self:validate(operation)

  local rootValue = nil
  -- TODO: Does this lock down the operation to specific named operations?
  -- TODO: derive from ast
  local operationName = nil

  local result = execute(self.schema, ast, rootValue, contextValue, variables, operationName)
  return result
end

return Server