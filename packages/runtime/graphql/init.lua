local graphql = { _version = '0.0.2' }

graphql.parse = require('@tilla/graphql.parse')
graphql.types = require('@tilla/graphql.types')
graphql.schema = require('@tilla/graphql.schema')
graphql.validate = require('@tilla/graphql.validate')
graphql.execute = require('@tilla/graphql.execute')

return graphql
