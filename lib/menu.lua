local Menu = {}
Menu.__index = Menu

function Menu.new(opts)
    local self = setmetatable({}, Menu)

    self.x = opts.x or 1
    self.y = opts.y or 1
    self.width = opts.width
    self.horizontal = opts.horizontal or false
    self.centered = opts.centered or false
    self.max_rows = opts.max_rows or 10
    self.max_columns = opts.max_columns or 1
    self.highlight_fg = opts.highlight_fg or colors.black
    self.highlight_bg = opts.highlight_bg or colors.white
    self.default_color = opts.default_color or colors.white
    self.default_bg = opts.default_bg or colors.black
    self.up_action = opts.up_action or "p1_up"
    self.down_action = opts.down_action or "p1_down"
    self.select_action = opts.select_action or "p1_action"

    self.focused = opts.focused ~= false

    self.items = {}
    self.selected = 1
    self.scroll_offset = 0

    if opts.items then
        for _, item in ipairs(opts.items) do
            self:addItem(item)
        end
    end

    return self
end

function Menu:addItem(item)
    table.insert(self.items, {
        label = item.label,
        color = item.color or self.default_color,
        highlight_fg = item.highlight_fg,
        highlight_bg = item.highlight_bg,
        action = item.action or "select",
        value = item.value,
        data = item.data,
    })
end

function Menu:setItems(items)
    self.items = {}
    for _, item in ipairs(items) do
        self:addItem(item)
    end
    self.selected = 1
    self.scroll_offset = 0
end

function Menu:getSelected()
    return self.selected
end

function Menu:setSelected(index)
    if index >= 1 and index <= #self.items then
        self.selected = index
        self:_ensureVisible()
    end
end

function Menu:getItem(index)
    return self.items[index]
end

function Menu:getItemCount()
    return #self.items
end

local function resolveLabel(item)
    if type(item.label) == "function" then
        return item.label(item)
    end
    return item.label or ""
end

function Menu:_slotCapacity()
    if self.horizontal then
        return self.max_columns
    end
    return self.max_rows
end

function Menu:_needsScroll()
    return #self.items > self:_slotCapacity()
end

function Menu:_maxScroll()
    return math.max(0, #self.items - self:_slotCapacity())
end

function Menu:_ensureVisible()
    local vis = math.min(#self.items, self:_slotCapacity())
    if self.selected < self.scroll_offset + 1 then
        self.scroll_offset = self.selected - 1
    elseif self.selected > self.scroll_offset + vis then
        self.scroll_offset = self.selected - vis
    end
    self.scroll_offset = math.max(0, math.min(self.scroll_offset, self:_maxScroll()))
end

function Menu:_clampScroll()
    self.scroll_offset = math.max(0, math.min(self.scroll_offset, self:_maxScroll()))
end

function Menu:_visibleRange()
    self:_clampScroll()
    local needsScroll = self:_needsScroll()
    local available = self:_slotCapacity()
    if needsScroll then
        if self.scroll_offset > 0 then available = available - 1 end
        if self.scroll_offset < self:_maxScroll() then available = available - 1 end
    end
    local startIdx = self.scroll_offset + 1
    local endIdx = math.min(startIdx + available - 1, #self.items)
    return startIdx, endIdx, needsScroll
end

function Menu:_getWidth()
    if self.width then return self.width end
    local tw = term.getSize()
    return tw - self.x + 1
end

function Menu:_arrowX(menuWidth)
    if self.centered then
        return math.floor(self.x + menuWidth / 2)
    end
    return self.x
end

function Menu:_itemX(label, isSelected, menuWidth)
    if self.centered then
        local padded = isSelected and (#label + 2) or #label
        return math.max(1, math.floor(self.x + (menuWidth - padded) / 2))
    end
    return self.x
end

function Menu:handleInput(inputState)
    if #self.items == 0 then return nil end

    if inputState.wasPressed(self.up_action) then
        local old = self.selected
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self.items end
        self:_ensureVisible()
        if old ~= self.selected then
            return { type = "navigate", index = self.selected }
        end
    elseif inputState.wasPressed(self.down_action) then
        local old = self.selected
        self.selected = self.selected + 1
        if self.selected > #self.items then self.selected = 1 end
        self:_ensureVisible()
        if old ~= self.selected then
            return { type = "navigate", index = self.selected }
        end
    elseif inputState.wasPressed(self.select_action) then
        local item = self.items[self.selected]
        if item then
            if item.action == "toggle" then
                item.value = not item.value
                return { type = "toggle", index = self.selected, value = item.value, item = item }
            else
                return { type = "select", index = self.selected, item = item }
            end
        end
    end

    return nil
end

function Menu:draw()
    if #self.items == 0 then return end

    local tw, th = term.getSize()
    local startIdx, endIdx, needsScroll = self:_visibleRange()
    local menuWidth = self:_getWidth()

    local drawY = self.y

    if self.horizontal and drawY >= 1 and drawY <= th then
        term.setCursorPos(self.x, drawY)
        term.setBackgroundColor(self.default_bg)
        term.write(string.rep(" ", math.min(menuWidth, tw - self.x + 1)))
    end

    if needsScroll and self.scroll_offset > 0 then
        if drawY >= 1 and drawY <= th then
            local ax = self:_arrowX(menuWidth)
            if ax >= 1 and ax <= tw then
                term.setCursorPos(ax, drawY)
                term.setTextColor(colors.lightGray)
                term.setBackgroundColor(self.default_bg)
                term.write("\24")
            end
        end
        drawY = drawY + 1
    end

    local hSpacing = 0
    if self.horizontal and endIdx >= startIdx then
        local totalLabelW = 0
        for i = startIdx, endIdx do
            totalLabelW = totalLabelW + #resolveLabel(self.items[i]) + 2
        end
        local count = endIdx - startIdx + 1
        if count > 1 then
            hSpacing = math.floor((menuWidth - totalLabelW) / (count + 1))
        end
    end

    local hCursor = self.x + (self.horizontal and hSpacing or 0)

    for i = startIdx, endIdx do
        local item = self.items[i]
        local label = resolveLabel(item)
        local isSelected = (i == self.selected)
        local showHighlight = isSelected and self.focused

        local cx, cy
        if self.horizontal then
            cx = hCursor
            cy = drawY
            hCursor = hCursor + (showHighlight and #label + 2 or #label) + hSpacing
        else
            cy = drawY + (i - startIdx)
            cx = self:_itemX(label, showHighlight, menuWidth)
        end

        if cy < 1 or cy > th then break end
        if cx < 1 then cx = 1 end

        term.setCursorPos(cx, cy)
        if showHighlight then
            term.setBackgroundColor(item.highlight_bg or self.highlight_bg)
            term.setTextColor(item.highlight_fg or self.highlight_fg)
            local displayLabel = " " .. label .. " "
            local maxLen = tw - cx + 1
            if #displayLabel > maxLen then
                displayLabel = displayLabel:sub(1, maxLen)
            end
            term.write(displayLabel)
        else
            term.setBackgroundColor(self.default_bg)
            term.setTextColor(item.color or self.default_color)
            local maxLen = tw - cx + 1
            if #label > maxLen then
                label = label:sub(1, maxLen)
            end
            term.write(label)
        end
    end

    if needsScroll and self.scroll_offset < self:_maxScroll() then
        local arrowY = drawY + (endIdx - startIdx) + 1
        if arrowY >= 1 and arrowY <= th then
            local ax = self:_arrowX(menuWidth)
            if ax >= 1 and ax <= tw then
                term.setCursorPos(ax, arrowY)
                term.setTextColor(colors.lightGray)
                term.setBackgroundColor(self.default_bg)
                term.write("\25")
            end
        end
    end

    term.setBackgroundColor(self.default_bg)
    term.setTextColor(self.default_color)
end

function Menu:run(tickRate, inputState, opts)
    opts = opts or {}
    local timeout = opts.timeout
    local timeout_index = opts.timeout_index or #self.items
    local elapsed = 0
    local timerId = os.startTimer(tickRate)

    while true do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            inputState.tick()
            elapsed = elapsed + tickRate

            if timeout and elapsed >= timeout then
                local item = self.items[timeout_index]
                if item then
                    return { type = "timeout", index = timeout_index, item = item, elapsed = elapsed }
                end
            end

            local result = self:handleInput(inputState)
            if result then
                if result.type == "select" then
                    return result
                elseif self._onEvent then
                    self._onEvent(result)
                end
            end
            term.setBackgroundColor(self.default_bg)
            term.clear()
            self:draw()
            timerId = os.startTimer(tickRate)
        end
    end
end

function Menu:onEvent(callback)
    self._onEvent = callback
end

function Menu:hitTest(screenX, screenY)
    if #self.items == 0 then return nil end

    local startIdx, endIdx, needsScroll = self:_visibleRange()
    local menuWidth = self:_getWidth()

    local testY = self.y

    if needsScroll and self.scroll_offset > 0 then
        if screenX == self:_arrowX(menuWidth) and screenY == testY then
            return { type = "scroll", dir = "up" }
        end
        testY = testY + 1
    end

    local hSpacing = 0
    if self.horizontal and endIdx >= startIdx then
        local totalLabelW = 0
        for i = startIdx, endIdx do
            totalLabelW = totalLabelW + #resolveLabel(self.items[i]) + 2
        end
        local count = endIdx - startIdx + 1
        if count > 1 then
            hSpacing = math.floor((menuWidth - totalLabelW) / (count + 1))
        end
    end

    local hCursor = self.x + (self.horizontal and hSpacing or 0)

    for i = startIdx, endIdx do
        local item = self.items[i]
        local label = resolveLabel(item)
        local showHighlight = (i == self.selected) and self.focused
        local displayLen = showHighlight and (#label + 2) or #label

        local cx, cy
        if self.horizontal then
            cx = hCursor
            cy = testY
            hCursor = hCursor + displayLen + hSpacing
        else
            cy = testY + (i - startIdx)
            cx = self:_itemX(label, showHighlight, menuWidth)
        end

        if screenY == cy and screenX >= cx and screenX < cx + displayLen then
            return { type = "item", index = i, item = item }
        end
    end

    if needsScroll and self.scroll_offset < self:_maxScroll() then
        local arrowY = testY + (endIdx - startIdx) + 1
        if screenX == self:_arrowX(menuWidth) and screenY == arrowY then
            return { type = "scroll", dir = "down" }
        end
    end

    return nil
end

function Menu:scrollUp()
    if self.scroll_offset > 0 then
        self.scroll_offset = self.scroll_offset - 1
        return true
    end
    return false
end

function Menu:scrollDown()
    if self.scroll_offset < self:_maxScroll() then
        self.scroll_offset = self.scroll_offset + 1
        return true
    end
    return false
end

return Menu
