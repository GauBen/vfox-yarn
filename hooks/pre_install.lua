--- Pre-installation hook (also performs installation)
PLUGIN = {}

local function commandExists(cmd)
    local handle = io.popen("command -v " .. cmd .. " >/dev/null 2>&1 && echo 'yes' || echo 'no'")
    if handle then
        local result = handle:read("*a"):gsub("%s+", "")
        handle:close()
        return result == "yes"
    end
    return false
end

--- Install Yarn v1 (Classic)
local function installYarnV1(version, install_path, temp_dir)
    local archive_name = "yarn-v" .. version .. ".tar.gz"
    local archive_url = "https://classic.yarnpkg.com/downloads/" .. version .. "/" .. archive_name
    local signature_url = archive_url .. ".asc"
    
    -- Download archive
    local download_cmd
    if commandExists("wget") then
        download_cmd = "wget -q -O " .. temp_dir .. "/" .. archive_name .. " " .. archive_url
    else
        download_cmd = "curl -sSL -o " .. temp_dir .. "/" .. archive_name .. " " .. archive_url
    end
    
    local result = os.execute(download_cmd)
    if result ~= 0 and result ~= true then
        error("Failed to download Yarn archive")
    end
    
    -- GPG verification (if not skipped)
    if os.getenv("MISE_YARN_SKIP_GPG") == nil then
        -- Download signature
        if commandExists("wget") then
            os.execute("wget -q -O " .. temp_dir .. "/" .. archive_name .. ".asc " .. signature_url)
        else
            os.execute("curl -sSL -o " .. temp_dir .. "/" .. archive_name .. ".asc " .. signature_url)
        end
        
        -- Import GPG key
        local keyring_dir = os.getenv("HOME") .. "/.cache/vfox-yarn/keyrings"
        os.execute("mkdir -p " .. keyring_dir .. " && chmod 0700 " .. keyring_dir)
        
        if commandExists("wget") then
            os.execute("wget -q -O - https://dl.yarnpkg.com/debian/pubkey.gpg | GNUPGHOME=" .. keyring_dir .. " gpg --import 2>/dev/null")
        else
            os.execute("curl -sSL https://dl.yarnpkg.com/debian/pubkey.gpg | GNUPGHOME=" .. keyring_dir .. " gpg --import 2>/dev/null")
        end
        
        -- Verify signature
        local verify_result = os.execute("GNUPGHOME=" .. keyring_dir .. " gpg --verify " .. temp_dir .. "/" .. archive_name .. ".asc " .. temp_dir .. "/" .. archive_name .. " 2>/dev/null")
        if verify_result ~= 0 and verify_result ~= true then
            print("⚠️  GPG verification failed. Set MISE_YARN_SKIP_GPG=1 to skip verification")
            error("GPG signature verification failed")
        end
    end
    
    -- Extract archive
    os.execute("cd " .. temp_dir .. " && tar xzf " .. archive_name .. " --strip-components=1 --no-same-owner")
    
    -- Remove archive files
    os.execute("rm -f " .. temp_dir .. "/" .. archive_name .. " " .. temp_dir .. "/" .. archive_name .. ".asc")
    
    -- Create installation directory
    os.execute("rm -rf " .. install_path .. " 2>/dev/null")
    os.execute("mkdir -p " .. install_path)
    
    -- Move files to installation directory
    os.execute("cp -r " .. temp_dir .. "/* " .. install_path .. "/")
end

--- Install Yarn v2+ (Berry)
local function installYarnV2Plus(version, install_path, temp_dir)
    local yarn_url = "https://repo.yarnpkg.com/" .. version .. "/packages/yarnpkg-cli/bin/yarn.js"
    local yarn_file = temp_dir .. "/yarn.js"
    
    -- Download yarn.js
    local download_cmd
    if commandExists("wget") then
        download_cmd = "wget -q -O " .. yarn_file .. " " .. yarn_url
    else
        download_cmd = "curl -sSL -o " .. yarn_file .. " " .. yarn_url
    end
    
    local result = os.execute(download_cmd)
    if result ~= 0 and result ~= true then
        error("Failed to download Yarn")
    end
    
    -- Create installation directory structure
    os.execute("rm -rf " .. install_path .. " 2>/dev/null")
    os.execute("mkdir -p " .. install_path .. "/bin")
    
    -- Move and make executable
    os.execute("cp " .. yarn_file .. " " .. install_path .. "/bin/yarn")
    os.execute("chmod +x " .. install_path .. "/bin/yarn")
end

function PLUGIN:PreInstall(ctx)
    local version = ctx.version
    
    -- Check for required tools
    if not commandExists("tar") then
        error("Missing required dependency: tar")
    end
    
    if not commandExists("wget") and not commandExists("curl") then
        error("Missing one of either of the following dependencies: wget, curl")
    end
    
    local major_version = string.sub(version, 1, 1)
    if major_version == "1" and os.getenv("MISE_YARN_SKIP_GPG") == nil then
        if not commandExists("gpg") then
            print("⚠️  Warning: gpg not found. Set MISE_YARN_SKIP_GPG=1 to skip GPG verification")
            error("Missing required dependency: gpg (or set MISE_YARN_SKIP_GPG to skip verification)")
        end
    end
    
    -- Derive install path from environment  
    local install_path = os.getenv("MISE_INSTALL_PATH")
    if not install_path then
        install_path = os.getenv("HOME") .. "/.local/share/mise/installs/yarn/" .. version
    end
    
    print("Installing Yarn " .. version .. " to " .. install_path .. "...")
    
    -- Create temp directory
    local temp_dir = "/tmp/vfox-yarn-" .. os.time()
    os.execute("mkdir -p " .. temp_dir)
    
    local success, err
    if major_version == "1" then
        -- Install Yarn Classic (v1.x)
        success, err = pcall(installYarnV1, version, install_path, temp_dir)
    else
        -- Install Yarn Berry (v2.x+)
        success, err = pcall(installYarnV2Plus, version, install_path, temp_dir)
    end
    
    -- Clean up temp directory
    os.execute("rm -rf " .. temp_dir)
    
    if not success then
        error("Installation failed: " .. tostring(err))
    end
    
    -- Return the version unchanged
    return {
        version = version
    }
end

return PLUGIN