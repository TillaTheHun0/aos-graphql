local graphql = require('@tilla/graphql.init')

local parse = graphql.parse
local validate = graphql.validate
local execute = graphql.execute

local server = { version = '0.0.1' }

server.create = function (args)
  local schema, _context = args.schema, args.context or function () return {} end

  return function (operation, variables, info)
    local contextValue = _context(info)

    local ast = parse(operation)

    -- Validate a parsed operation against the schema
    validate(schema, ast)

    local rootValue = nil
    -- TODO: Does this lock down the operation to specific named operations?
    -- TODO: derive from ast
    local operationName = nil

    local result = execute(schema, ast, rootValue, contextValue, variables, operationName)
    return result
  end
end

server.aos = function (args)
  local schema, context = args.schema, args.context

  local gql = server.create({
    schema = schema,
    -- Build a context value to pass to each invoked resolver
    -- passing along the ao specific info
    context = function (info)
      local contextValue = context({ msg = info.msg, ao = info.ao })
      return contextValue
    end
  })

  -- Add an aos Handler that will handle any GraphQL actions
  Handlers.prepend(
    "graphql",
    function (msg) return msg.Tags.Action == 'GraphQL' end,
    function (msg)
      local operation, variables
      if msg.Tags.Operation then
        operation = msg.Tags.Operation
        variables = msg.Data
      else
        operation = msg.Data
      end

      local result = gql(operation, variables or {}, { msg = msg, ao = ao })

      ao.send({ Target = msg.From, Data = result })
      -- TODO: should we continue handler invocation?
      -- break after handler is executed and a result in resolved
      return -1
    end
  )

  return gql
end

return server
