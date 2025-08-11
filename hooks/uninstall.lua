--- Uninstall a version
PLUGIN = {}

function PLUGIN:Uninstall(ctx)
    local install_path = ctx.path
    os.execute("rm -rf " .. install_path)
    print("✅ Yarn uninstalled from " .. install_path)
end

return PLUGIN