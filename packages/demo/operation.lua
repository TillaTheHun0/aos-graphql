
local variables = { id = 'id-3' }

local operation = [[
  query GetPerson ($id: ID!) {
    person (id: $id) {
      id
      firstName
      middleName
      lastName
      age
      friends {
        firstName
        lastName
      }
    }
  }
]]

return Server:resolve(operation, variables)
