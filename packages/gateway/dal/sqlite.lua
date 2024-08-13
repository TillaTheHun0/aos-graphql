-- TODO import sqlite and implement

local stubBlocks = {
  {
    id = 'iOnwzLSR2hNoihJLX_SXJ_fDjJFJqMwn-FpBq9vvx71so7KLnUJ6wqms308PP4iF',
    timestamp = 1723565424,
    height = 1485144,
    previous = 'cm9HyYpEGryadjE-MWewG0oxBFT69RQ_Th2R9o99ino-WfRN3Zarwkw3G_Tf2oTM',
  },
  {
    id = 'cm9HyYpEGryadjE-MWewG0oxBFT69RQ_Th2R9o99ino-WfRN3Zarwkw3G_Tf2oTM',
    timestamp = 1723565382,
    height = 1485143,
    previous = 'o-oApTA_bWKYCJeWarp1UOF_cqmpL9aZOxlOgJOTl3LMW88xIfmltSbMPiAjZOid'
  },
  {
    id = "o-oApTA_bWKYCJeWarp1UOF_cqmpL9aZOxlOgJOTl3LMW88xIfmltSbMPiAjZOid",
    timestamp = 1723565270,
    height = 1485142,
    previous = nil
  }
}

return function (args)
  local client = args.client or { } -- TODO: instantiate db client if not injected

  local dal = {}

  dal.query = function (query)
    local statement, parameters = query.statement, query.parameters
    -- TODO: implement
  end

  dal.run = function (run)
    local statement, parameters = run.statement, run.parameters
    -- TODO: implement
  end

  return dal
end
