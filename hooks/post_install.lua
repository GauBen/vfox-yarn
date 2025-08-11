--- Post-installation hook
PLUGIN = {}

function PLUGIN:PostInstall(ctx)
    -- Ensure yarn binary is executable
    if ctx.path then
        os.execute("chmod +x " .. ctx.path .. "/bin/yarn 2>/dev/null")
        print("✅ Yarn " .. ctx.version .. " installed successfully")
    end
    
    return {}
end

return PLUGIN