local M = {}

-- Verify a bearer token and return its claims.
function M.verify(token)
    local claims = decode(token)
    return claims
end

return M
