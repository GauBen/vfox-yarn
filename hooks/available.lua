--- List all available versions
PLUGIN = {}

local http = require("vfox.http")
local json = require("vfox.json")

function PLUGIN:Available(ctx)
    local versions = {}
    
    -- Get Yarn Berry versions (v2.x+) from GitHub API
    local berry_resp, err = http.get({
        url = "https://api.github.com/repos/yarnpkg/berry/git/refs/tags"
    })
    
    if err == nil and berry_resp.status_code == 200 then
        local refs = json.decode(berry_resp.body)
        if refs then
            -- Process refs in reverse order to get newest first
            for i = #refs, 1, -1 do
                local ref = refs[i].ref
                if ref and ref:match("@yarnpkg/cli/") then
                    local version = ref:gsub("^refs/tags/@yarnpkg/cli/", "")
                    if version and version ~= "" then
                        table.insert(versions, {
                            version = version
                        })
                    end
                end
            end
        end
    end
    
    -- Get Yarn Classic versions (v1.x) from GitHub API
    local classic_resp, err = http.get({
        url = "https://api.github.com/repos/yarnpkg/yarn/git/refs/tags"
    })
    
    if err == nil and classic_resp.status_code == 200 then
        local refs = json.decode(classic_resp.body)
        if refs then
            -- Process refs in reverse order to get newest first
            for i = #refs, 1, -1 do
                local ref = refs[i].ref
                if ref and ref:match("^refs/tags/v") then
                    local version = ref:gsub("^refs/tags/v", "")
                    -- Skip v0.x versions
                    if version and not version:match("^0%.") then
                        table.insert(versions, {
                            version = version
                        })
                    end
                end
            end
        end
    end
    
    return versions
end

return PLUGIN