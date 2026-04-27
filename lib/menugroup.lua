local MenuGroup = {}
MenuGroup.__index = MenuGroup

function MenuGroup.new(opts)
    local self = setmetatable({}, MenuGroup)

    self.menus = opts.menus or {}
    self.horizontal = opts.horizontal or false
    self.focusIndex = 1
    self.default_bg = opts.default_bg or colors.black

    if opts.focus then
        for i, m in ipairs(self.menus) do
            if m == opts.focus then
                self.focusIndex = i
                break
            end
        end
    end

    for i, m in ipairs(self.menus) do
        m.focused = (i == self.focusIndex)
    end

    local first = self.menus[1]
    self.up_action = opts.up_action or (first and first.up_action) or "p1_up"
    self.down_action = opts.down_action or (first and first.down_action) or "p1_down"
    self.left_action = opts.left_action or "p1_left"
    self.right_action = opts.right_action or "p1_right"
    self.select_action = opts.select_action or (first and first.select_action) or "p1_action"

    return self
end

function MenuGroup:getFocused()
    return self.menus[self.focusIndex]
end

function MenuGroup:getFocusIndex()
    return self.focusIndex
end

function MenuGroup:setFocus(menuOrIndex)
    local newIndex
    if type(menuOrIndex) == "number" then
        if menuOrIndex >= 1 and menuOrIndex <= #self.menus then
            newIndex = menuOrIndex
        end
    else
        for i, m in ipairs(self.menus) do
            if m == menuOrIndex then
                newIndex = i
                break
            end
        end
    end
    if newIndex then
        self.menus[self.focusIndex].focused = false
        self.focusIndex = newIndex
        self.menus[self.focusIndex].focused = true
    end
end

function MenuGroup:getMenu(index)
    return self.menus[index]
end

function MenuGroup:getMenuCount()
    return #self.menus
end

local function findNeighbor(menus, from, delta)
    local i = from + delta
    while i >= 1 and i <= #menus do
        if menus[i]:getItemCount() > 0 then
            return i
        end
        i = i + delta
    end
    return nil
end

function MenuGroup:handleInput(inputState)
    if #self.menus == 0 then return nil end

    local focused = self.menus[self.focusIndex]
    if not focused or focused:getItemCount() == 0 then return nil end

    local prevAction, nextAction
    if self.horizontal then
        prevAction = self.left_action
        nextAction = self.right_action
    else
        prevAction = self.up_action
        nextAction = self.down_action
    end

    if inputState.wasPressed(prevAction) then
        if focused:getSelected() == 1 then
            local target = findNeighbor(self.menus, self.focusIndex, -1)
            if target then
                focused.focused = false
                self.focusIndex = target
                local m = self.menus[target]
                m.focused = true
                m:setSelected(m:getItemCount())
                return { type = "focus", menu = m, menuIndex = target }
            end
            return nil
        end
    elseif inputState.wasPressed(nextAction) then
        if focused:getSelected() == focused:getItemCount() then
            local target = findNeighbor(self.menus, self.focusIndex, 1)
            if target then
                focused.focused = false
                self.focusIndex = target
                local m = self.menus[target]
                m.focused = true
                m:setSelected(1)
                return { type = "focus", menu = m, menuIndex = target }
            end
            return nil
        end
    end

    local result = focused:handleInput(inputState)
    if result then
        result.menu = focused
        result.menuIndex = self.focusIndex
    end
    return result
end

function MenuGroup:draw()
    for _, menu in ipairs(self.menus) do
        menu:draw()
    end
end

function MenuGroup:run(tickRate, inputState, opts)
    opts = opts or {}
    local timeout = opts.timeout
    local timeout_index = opts.timeout_index
    local elapsed = 0
    local timerId = os.startTimer(tickRate)

    while true do
        local event, p1 = os.pullEvent()
        if event == "timer" and p1 == timerId then
            inputState.tick()
            elapsed = elapsed + tickRate

            if timeout and elapsed >= timeout then
                local targetMenu, targetIdx
                if timeout_index then
                    for mi, menu in ipairs(self.menus) do
                        if timeout_index <= menu:getItemCount() then
                            targetMenu = menu
                            targetIdx = timeout_index
                            break
                        end
                        timeout_index = timeout_index - menu:getItemCount()
                    end
                end
                local item = targetMenu and targetMenu:getItem(targetIdx)
                if item then
                    return { type = "timeout", index = targetIdx, item = item,
                             menu = targetMenu, elapsed = elapsed }
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

function MenuGroup:onEvent(callback)
    self._onEvent = callback
end

function MenuGroup:hitTest(screenX, screenY)
    for i, menu in ipairs(self.menus) do
        local hit = menu:hitTest(screenX, screenY)
        if hit then
            hit.menu = menu
            hit.menuIndex = i
            return hit
        end
    end
    return nil
end

return MenuGroup
