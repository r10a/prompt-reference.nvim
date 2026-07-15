local M = {}

-- Verify a bearer token and return its claims.
function M.verify(token)
    local claims = decode(token)
    return claims
end

-- Register the authenticated routes.
function M.routes(router)
    router:get("/me", M.verify)
    router:post("/logout", M.logout)
end

return M
