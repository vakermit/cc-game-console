while true do
    local ok = pcall(shell.run, "screensaver")
    if not ok then break end

    -- Clear require cache so modules re-initialize (e.g. console's running=true)
    for name in pairs(package.loaded) do
        if name ~= "_G" and name ~= "package" then
            package.loaded[name] = nil
        end
    end

    local ok2 = pcall(shell.run, "vgame")
    if not ok2 then break end
end
