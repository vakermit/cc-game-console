while true do
    shell.run("screensaver")
    -- Clear require cache so modules re-initialize (e.g. console's running=true)
    for name in pairs(package.loaded) do
        if name ~= "_G" and name ~= "package" then
            package.loaded[name] = nil
        end
    end
    shell.run("vgame")
end
