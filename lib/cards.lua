local cards = {}

local suits = {
    { name = "spades",   symbol = "\x06", color = colors.black },
    { name = "hearts",   symbol = "\x03", color = colors.red },
    { name = "diamonds", symbol = "\x04", color = colors.red },
    { name = "clubs",    symbol = "\x05", color = colors.black },
}

local ranks = {
    { name = "A",  value = 1,  display = "A " },
    { name = "2",  value = 2,  display = "2 " },
    { name = "3",  value = 3,  display = "3 " },
    { name = "4",  value = 4,  display = "4 " },
    { name = "5",  value = 5,  display = "5 " },
    { name = "6",  value = 6,  display = "6 " },
    { name = "7",  value = 7,  display = "7 " },
    { name = "8",  value = 8,  display = "8 " },
    { name = "9",  value = 9,  display = "9 " },
    { name = "10", value = 10, display = "10" },
    { name = "J",  value = 10, display = "J " },
    { name = "Q",  value = 10, display = "Q " },
    { name = "K",  value = 10, display = "K " },
}

function cards.getSuits()
    return suits
end

function cards.getRanks()
    return ranks
end

function cards.newDeck(numDecks)
    numDecks = numDecks or 1
    local deck = {}
    for d = 1, numDecks do
        for _, suit in ipairs(suits) do
            for _, rank in ipairs(ranks) do
                table.insert(deck, {
                    suit = suit,
                    rank = rank,
                    faceUp = true,
                })
            end
        end
    end
    return deck
end

function cards.shuffle(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

function cards.draw(deck, n)
    n = n or 1
    local drawn = {}
    for i = 1, n do
        if #deck == 0 then break end
        table.insert(drawn, table.remove(deck, 1))
    end
    return drawn
end

function cards.newHand()
    return {}
end

function cards.addToHand(hand, cardList)
    for _, card in ipairs(cardList) do
        table.insert(hand, card)
    end
end

function cards.handValue(hand)
    local total = 0
    local aces = 0
    for _, card in ipairs(hand) do
        if card.faceUp then
            total = total + card.rank.value
            if card.rank.name == "A" then aces = aces + 1 end
        end
    end
    while aces > 0 and total + 10 <= 21 do
        total = total + 10
        aces = aces - 1
    end
    return total
end

function cards.isBusted(hand)
    return cards.handValue(hand) > 21
end

function cards.isBlackjack(hand)
    return #hand == 2 and cards.handValue(hand) == 21
end

local cardWidth = 7
local cardHeight = 5

function cards.getCardWidth()
    return cardWidth
end

function cards.getCardHeight()
    return cardHeight
end

function cards.drawCard(x, y, card)
    if not card.faceUp then
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.lightBlue)
        for row = 0, cardHeight - 1 do
            term.setCursorPos(x, y + row)
            if row == 0 or row == cardHeight - 1 then
                term.write(string.rep("#", cardWidth))
            else
                term.write("#" .. string.rep("~", cardWidth - 2) .. "#")
            end
        end
        return
    end

    term.setBackgroundColor(colors.white)
    for row = 0, cardHeight - 1 do
        term.setCursorPos(x, y + row)
        term.write(string.rep(" ", cardWidth))
    end

    term.setTextColor(card.suit.color)

    term.setCursorPos(x + 1, y)
    term.write(card.rank.display)

    term.setCursorPos(x + 3, y + 2)
    term.write(card.suit.symbol)

    local bottomRank = card.rank.display
    term.setCursorPos(x + cardWidth - #bottomRank - 1, y + cardHeight - 1)
    term.write(bottomRank)
end

function cards.drawHand(x, y, hand, spacing)
    spacing = spacing or 4
    for i, card in ipairs(hand) do
        local cx = x + (i - 1) * spacing
        cards.drawCard(cx, y, card)
    end
end

return cards
