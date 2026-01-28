--- Post-installation hook

-- os.execute returns 0 in Lua 5.1, true in Lua 5.2+
local function exec_success(result)
    return result == true or result == 0
end

local function download_file(url, output_path)
    -- Detect Windows
    local is_windows = package.config:sub(1,1) == '\\'
    local stderr_redirect = is_windows and " 2>NUL" or " 2>/dev/null"

    -- Try curl first (more likely to be available on Windows via Git Bash)
    local curl_cmd = "curl -sSL -o " .. output_path .. " " .. url .. stderr_redirect
    local wget_cmd = "wget -q -O " .. output_path .. " " .. url .. stderr_redirect

    if exec_success(os.execute(curl_cmd)) then
        return true
    elseif exec_success(os.execute(wget_cmd)) then
        return true
    end
    return false
end

local function get_target_platform()
    -- Detect platform and architecture for Yarn v6+ binary downloads
    local is_windows = package.config:sub(1,1) == '\\'

    if is_windows then
        -- Windows detection
        local arch = os.getenv("PROCESSOR_ARCHITECTURE") or "x86_64"
        if arch:match("ARM64") then
            return "aarch64-pc-windows-gnu"
        else
            return "x86_64-pc-windows-gnu"
        end
    else
        -- Unix-like systems (Linux, macOS, etc.)
        local handle = io.popen("uname -ms 2>/dev/null")
        local result = handle and handle:read("*a") or ""
        if handle then handle:close() end

        if result:match("Darwin arm64") or result:match("Darwin aarch64") then
            return "aarch64-apple-darwin"
        elseif result:match("Darwin") then
            return "x86_64-apple-darwin"
        elseif result:match("Linux aarch64") or result:match("Linux arm64") then
            return "aarch64-unknown-linux-musl"
        else
            -- Default to x86_64 Linux
            return "x86_64-unknown-linux-musl"
        end
    end
end

function PLUGIN:PostInstall(ctx)
    -- Get install path - it should be in sdkInfo
    local install_path = nil
    local version = nil

    -- Try to get path from sdkInfo
    if ctx.sdkInfo and ctx.sdkInfo.yarn then
        install_path = ctx.sdkInfo.yarn.path
        version = ctx.sdkInfo.yarn.version
    end

    -- Fallback to environment variable
    if not install_path then
        install_path = os.getenv("MISE_INSTALL_PATH")
    end
    if not version then
        version = os.getenv("MISE_INSTALL_VERSION") or ctx.version
    end

    if not install_path or not version then
        -- For v1, mise handles everything, so this is OK
        return {}
    end

    local major_version = string.sub(version, 1, 1)
    local is_windows = package.config:sub(1,1) == '\\'

    if major_version == "6" or (tonumber(major_version) and tonumber(major_version) >= 6) then
        -- Yarn ZPM (v6+) - download pre-compiled Rust binary
        local target = get_target_platform()
        local yarn_url = "https://repo.yarnpkg.com/releases/" .. version .. "/" .. target

        -- Create bin directory (cross-platform)
        local bin_dir = install_path .. "/bin"
        if is_windows then
            os.execute('mkdir "' .. bin_dir .. '" 2>NUL')
        else
            os.execute("mkdir -p " .. bin_dir)
        end

        -- Download and extract the binary
        local archive_path = bin_dir .. "/yarn.zip"
        if not download_file(yarn_url, archive_path) then
            error("Failed to download Yarn v6+ from " .. yarn_url)
        end

        -- Extract the zip file
        if is_windows then
            -- Use PowerShell to extract zip on Windows
            local ps_cmd = 'powershell -Command "Expand-Archive -Path ' .. archive_path .. ' -DestinationPath ' .. bin_dir .. ' -Force" 2>NUL'
            if not exec_success(os.execute(ps_cmd)) then
                -- Fallback to unzip if available
                os.execute("cd " .. bin_dir .. " && unzip -q yarn.zip 2>NUL")
            end
        else
            -- Use unzip on Unix-like systems
            os.execute("unzip -q " .. archive_path .. " -d " .. bin_dir)
        end

        -- Clean up archive
        if is_windows then
            os.execute('del "' .. archive_path .. '" 2>NUL')
        else
            os.execute("rm -f " .. archive_path)
        end

        -- Make the binary executable on Unix-like systems
        if not is_windows then
            os.execute("chmod +x " .. bin_dir .. "/yarn")
        end
    elseif major_version ~= "1" then
        -- Yarn Berry (v2.x+) - download single JS file
        local yarn_url = "https://repo.yarnpkg.com/" .. version .. "/packages/yarnpkg-cli/bin/yarn.js"

        -- Create bin directory (cross-platform)
        local bin_dir = install_path .. "/bin"
        if is_windows then
            os.execute('mkdir "' .. bin_dir .. '" 2>NUL')
        else
            os.execute("mkdir -p " .. bin_dir)
        end

        -- Download yarn.js
        local yarn_js_file = bin_dir .. "/yarn.js"
        if not download_file(yarn_url, yarn_js_file) then
            error("Failed to download Yarn v2+")
        end

        -- Create wrapper script
        if is_windows then
            -- Create yarn.cmd wrapper for Windows
            local yarn_cmd = bin_dir .. "/yarn.cmd"
            local cmd_file = io.open(yarn_cmd, "w")
            if cmd_file then
                cmd_file:write("@echo off\n")
                cmd_file:write('node "%~dp0yarn.js" %*\n')
                cmd_file:close()
            end

            -- Also create yarn without extension for Git Bash
            local yarn_sh = bin_dir .. "/yarn"
            local sh_file = io.open(yarn_sh, "w")
            if sh_file then
                sh_file:write("#!/bin/sh\n")
                sh_file:write('exec node "$(dirname "$0")/yarn.js" "$@"\n')
                sh_file:close()
            end
        else
            -- Create shell wrapper for Unix
            local yarn_file = bin_dir .. "/yarn"
            local wrapper_file = io.open(yarn_file, "w")
            if wrapper_file then
                wrapper_file:write("#!/bin/sh\n")
                wrapper_file:write('exec node "$(dirname "$0")/yarn.js" "$@"\n')
                wrapper_file:close()
            end
            -- Make executable
            os.execute("chmod +x " .. yarn_file)
        end
    end

    return {}
end

return PLUGIN
