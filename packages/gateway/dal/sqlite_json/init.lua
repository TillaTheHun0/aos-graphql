-- TODO import sqlite and implement

local utils = require('graphql.gateway.utils')

local createSchema = require('.graphql.gateway.dal.sqlite_json.schema')

return function (args)
  local client = args.client or { } -- TODO: instantiate db client if not injected

  -- Bootstrap the schema
  createSchema(client)

  local dal = {}

  dal.findTransactionById = function (id)

  end

  dal.findTransactions = function (criteria)

  end

  dal.saveTransaction = function (doc)
    
  end

  return dal
end
