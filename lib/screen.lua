local screen = {}

screen.brightColors = {
    colors.red, colors.orange, colors.yellow, colors.lime,
    colors.cyan, colors.lightBlue, colors.magenta, colors.pink,
    colors.white,
}

function screen.randomBright()
    return screen.brightColors[math.random(#screen.brightColors)]
end

function screen.randomDir()
    return ({-1, 1})[math.random(2)]
end

return screen
