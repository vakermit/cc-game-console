local cards = require("lib.cards")

local game = {}

local width, height
local deck, playerHand, dealerHand
local balance, bet
local phase
local message, messageColor
local resultTimer

local BET_MIN = 10
local BET_MAX = 500
local BET_STEP = 10
local START_BALANCE = 1000

local function newRound()
    deck = cards.newDeck(2)
    cards.shuffle(deck)
    playerHand = cards.newHand()
    dealerHand = cards.newHand()
    bet = math.min(BET_MIN, balance)
    phase = "betting"
    message = "Place your bet"
    messageColor = colors.yellow
    resultTimer = 0
end

local function deal()
    cards.addToHand(playerHand, cards.draw(deck, 2))
    local dealerCards = cards.draw(deck, 2)
    dealerCards[2].faceUp = false
    cards.addToHand(dealerHand, dealerCards)

    if cards.isBlackjack(playerHand) then
        dealerHand[2].faceUp = true
        if cards.isBlackjack(dealerHand) then
            phase = "done"
            message = "Both blackjack - Push"
            messageColor = colors.yellow
        else
            phase = "done"
            balance = balance + math.floor(bet * 1.5)
            message = "Blackjack! +" .. math.floor(bet * 1.5)
            messageColor = colors.lime
        end
    else
        phase = "player"
        message = "Hit or Stand?"
        messageColor = colors.white
    end
end

local function dealerPlay()
    dealerHand[2].faceUp = true

    while cards.handValue(dealerHand) < 17 do
        cards.addToHand(dealerHand, cards.draw(deck, 1))
    end

    local pv = cards.handValue(playerHand)
    local dv = cards.handValue(dealerHand)

    if cards.isBusted(dealerHand) then
        balance = balance + bet
        message = "Dealer busts! +" .. bet
        messageColor = colors.lime
    elseif dv > pv then
        balance = balance - bet
        message = "Dealer wins -" .. bet
        messageColor = colors.red
    elseif pv > dv then
        balance = balance + bet
        message = "You win! +" .. bet
        messageColor = colors.lime
    else
        message = "Push"
        messageColor = colors.yellow
    end
    phase = "done"
end

function game.title()
    return "Blackjack"
end

function game.getControls()
    return {
        { action = "left/right", description = "Change bet" },
        { action = "action",     description = "Deal / New round" },
        { action = "up",         description = "Hit" },
        { action = "down",       description = "Stand" },
        { action = "alt",        description = "Surrender" },
    }
end

function game.init(console)
    width = console.getWidth()
    height = console.getHeight()
    balance = START_BALANCE
    math.randomseed(os.clock() * 1000)
    newRound()
end

function game.update(dt, input)
    local p1 = input.getPlayer(1)

    if phase == "betting" then
        if p1.wasPressed("left") then
            bet = math.max(BET_MIN, bet - BET_STEP)
        elseif p1.wasPressed("right") then
            bet = math.min(math.min(BET_MAX, balance), bet + BET_STEP)
        end
        if p1.wasPressed("action") and bet <= balance and balance > 0 then
            deal()
        end

    elseif phase == "player" then
        if p1.wasPressed("up") then
            cards.addToHand(playerHand, cards.draw(deck, 1))
            if cards.isBusted(playerHand) then
                dealerHand[2].faceUp = true
                balance = balance - bet
                message = "Bust! -" .. bet
                messageColor = colors.red
                phase = "done"
            else
                message = "Hit or Stand?"
                messageColor = colors.white
            end
        elseif p1.wasPressed("down") then
            dealerPlay()
        elseif p1.wasPressed("alt") then
            dealerHand[2].faceUp = true
            local loss = math.floor(bet / 2)
            balance = balance - loss
            message = "Surrender -" .. loss
            messageColor = colors.orange
            phase = "done"
        end

    elseif phase == "done" then
        resultTimer = resultTimer + dt
        if p1.wasPressed("action") and resultTimer > 0.5 then
            if balance <= 0 then
                balance = START_BALANCE
                message = "New bankroll!"
                messageColor = colors.yellow
            end
            newRound()
        end
    end
end

function game.draw()
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.clear()

    local spacing = math.min(5, math.floor((width - 4) / math.max(#dealerHand, 1)))
    spacing = math.max(2, spacing)

    term.setCursorPos(2, 1)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.lightGray)
    term.write("Dealer")

    if #dealerHand > 0 then
        local dealerX = math.max(2, math.floor((width - (#dealerHand - 1) * spacing - cards.getCardWidth()) / 2))
        cards.drawHand(dealerX, 2, dealerHand, spacing)

        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        local dv = cards.handValue(dealerHand)
        if dealerHand[2] and dealerHand[2].faceUp then
            term.setCursorPos(2, 2 + cards.getCardHeight())
            term.write("Total: " .. dv)
        end
    end

    local playerY = height - cards.getCardHeight() - 2
    term.setCursorPos(2, playerY - 1)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.lightGray)
    term.write("You")

    if #playerHand > 0 then
        local playerX = math.max(2, math.floor((width - (#playerHand - 1) * spacing - cards.getCardWidth()) / 2))
        cards.drawHand(playerX, playerY, playerHand, spacing)

        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.setCursorPos(2, playerY + cards.getCardHeight())
        term.write("Total: " .. cards.handValue(playerHand))
    end

    local midY = math.floor(height / 2)

    term.setBackgroundColor(colors.green)
    term.setTextColor(messageColor)
    local msgX = math.max(1, math.floor((width - #message) / 2))
    term.setCursorPos(msgX, midY)
    term.write(message)

    term.setTextColor(colors.yellow)
    local balStr = "$" .. balance
    term.setCursorPos(width - #balStr, 1)
    term.write(balStr)

    if phase == "betting" then
        local betStr = "Bet: $" .. bet
        term.setTextColor(colors.white)
        local betX = math.floor((width - #betStr - 6) / 2)
        term.setCursorPos(betX, midY + 1)
        term.setTextColor(colors.lightGray)
        term.write("< ")
        term.setTextColor(colors.yellow)
        term.write(betStr)
        term.setTextColor(colors.lightGray)
        term.write(" >")
    end

    if phase == "done" then
        local hint = "[action] Next round"
        term.setTextColor(colors.lightGray)
        term.setCursorPos(math.floor((width - #hint) / 2), midY + 2)
        term.write(hint)
    end
end

function game.cleanup()
end

return game
