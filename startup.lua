local nativeTerm = term.current()

local function status(msg)
    local old = term.redirect(nativeTerm)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.yellow)
    term.write("cc-game-console")
    term.setCursorPos(1, 3)
    term.setTextColor(colors.white)
    term.write(msg)
    term.setCursorPos(1, 5)
    term.setTextColor(colors.lightGray)
    term.write("Ctrl+T to exit to shell")
    term.redirect(old)
end

shell.run("reset-monitor")

status("Waiting for startup...")
sleep(10)
while true do
    status("Starting screensaver...")
    shell.run("screensaver")
    sleep(1)

    -- Clear require cache so modules re-initialize (e.g. console's running=true)
    for name in pairs(package.loaded) do
        if name ~= "_G" and name ~= "package" then
            package.loaded[name] = nil
        end
    end

    status("Starting game console...")
    shell.run("game-console")
    sleep(1)
end
