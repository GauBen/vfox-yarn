--- Utility functions shared across hooks
local M = {}

function M.commandExists(cmd)
    local handle = io.popen("command -v " .. cmd .. " >/dev/null 2>&1 && echo 'yes' || echo 'no'")
    if handle then
        local result = handle:read("*a"):gsub("%s+", "")
        handle:close()
        return result == "yes"
    end
    return false
end

function M.execCommand(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        return result
    end
    return ""
end

return M