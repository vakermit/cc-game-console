local block_letters = {}

-- 5x5 bitmap font: each char = {row1, row2, row3, row4, row5}
-- each row is a 5-bit integer, bit 4 (16) = leftmost pixel
local glyphs = {
    A = {14,17,31,17,17},  B = {30,17,30,17,30},  C = {14,16,16,16,14},
    D = {30,17,17,17,30},  E = {31,16,28,16,31},  F = {31,16,28,16,16},
    G = {14,16,19,17,14},  H = {17,17,31,17,17},  I = {31,4,4,4,31},
    J = {31,2,2,18,12},    K = {17,18,28,18,17},   L = {16,16,16,16,31},
    M = {17,27,21,17,17},  N = {17,25,21,19,17},   O = {14,17,17,17,14},
    P = {30,17,30,16,16},  Q = {14,17,21,18,13},   R = {30,17,30,18,17},
    S = {15,16,14,1,30},   T = {31,4,4,4,4},       U = {17,17,17,17,14},
    V = {17,17,17,10,4},   W = {17,17,21,27,17},   X = {17,10,4,10,17},
    Y = {17,10,4,4,4},     Z = {31,2,4,8,31},
    ["0"] = {14,19,21,25,14}, ["1"] = {4,12,4,4,14},   ["2"] = {14,17,6,8,31},
    ["3"] = {14,17,6,17,14},  ["4"] = {18,18,31,2,2},   ["5"] = {31,16,30,1,30},
    ["6"] = {14,16,30,17,14}, ["7"] = {31,1,2,4,4},     ["8"] = {14,17,14,17,14},
    ["9"] = {14,17,15,1,14},
    [" "] = {0,0,0,0,0},     ["!"] = {4,4,4,0,4},      ["-"] = {0,0,14,0,0},
    ["."] = {0,0,0,0,4},     [":"] = {0,4,0,4,0},      ["?"] = {14,17,6,0,4},
}

function block_letters.draw(x, y, text, fillChar)
    for row = 1, 5 do
        for i = 1, #text do
            local ch = text:sub(i, i):upper()
            local glyph = glyphs[ch]
            if glyph then
                local bits = glyph[row]
                local fill = fillChar or ch
                local px = x + (i - 1) * 6
                for col = 0, 4 do
                    local mask = 2 ^ (4 - col)
                    if math.floor(bits / mask) % 2 == 1 then
                        term.setCursorPos(px + col, y + row - 1)
                        term.write(fill)
                    end
                end
            end
        end
    end
end

function block_letters.width(text)
    return #text * 6 - 1
end

function block_letters.hasGlyph(ch)
    return glyphs[ch:upper()] ~= nil
end

return block_letters
