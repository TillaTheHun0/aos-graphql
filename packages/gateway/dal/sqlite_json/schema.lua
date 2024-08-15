
--[[
  TODO: implement

  A simple, single-table schema, for storing transactions.
  We will leverage SQLites JSON selector to implement querying
  based on the search crtieria
]]

local created = false

local function createSchema (client)
  if not created then
    -- TODO: create schema
    created = true
  end

  return client
end

return createSchema
