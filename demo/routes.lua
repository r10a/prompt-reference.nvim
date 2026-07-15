local auth = require("auth")

local M = {}

-- Register the authenticated routes.
function M.setup(router)
    router:get("/me", auth.verify)
    router:post("/logout", M.logout)
end

return M
