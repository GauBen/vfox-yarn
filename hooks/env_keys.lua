--- Environment variables to set
PLUGIN = {}

function PLUGIN:EnvKeys(ctx)
    local install_path = ctx.path
    
    return {
        {
            key = "PATH",
            value = install_path .. "/bin"
        }
    }
end

return PLUGIN