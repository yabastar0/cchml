local request = http.get("http://frogfind.com")
local ip = "93.184.216.34"
local port = "80"

local htmldata = request.readAll()
local lines = {}
shell.run("wget https://raw.githubusercontent.com/TiagoDanin/htmlEntities-for-lua/master/src/htmlEntities.lua tmp")
local htmlentities = loadfile("tmp")()
shell.run("delete tmp")
-- PrimeUI by JackMacWindows
-- Public domain/CC0

local expect = require "cc.expect".expect

-- Initialization code
local PrimeUI = {}
do
    local coros = {}
    local restoreCursor

    --- Adds a task to run in the main loop.
    ---@param func function The function to run, usually an `os.pullEvent` loop
    function PrimeUI.addTask(func)
        expect(1, func, "function")
        local t = {coro = coroutine.create(func)}
        coros[#coros+1] = t
        _, t.filter = coroutine.resume(t.coro)
    end

    --- Sends the provided arguments to the run loop, where they will be returned.
    ---@param ... any The parameters to send
    function PrimeUI.resolve(...)
        coroutine.yield(coros, ...)
    end

    --- Clears the screen and resets all components. Do not use any previously
    --- created components after calling this function.
    function PrimeUI.clear()
        -- Reset the screen.
        term.setCursorPos(1, 1)
        term.setCursorBlink(false)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        -- Reset the task list and cursor restore function.
        coros = {}
        restoreCursor = nil
    end

    --- Sets or clears the window that holds where the cursor should be.
    ---@param win window|nil The window to set as the active window
    function PrimeUI.setCursorWindow(win)
        expect(1, win, "table", "nil")
        restoreCursor = win and win.restoreCursor
    end

    --- Gets the absolute position of a coordinate relative to a window.
    ---@param win window The window to check
    ---@param x number The relative X position of the point
    ---@param y number The relative Y position of the point
    ---@return number x The absolute X position of the window
    ---@return number y The absolute Y position of the window
    function PrimeUI.getWindowPos(win, x, y)
        if win == term then return x, y end
        while win ~= term.native() and win ~= term.current() do
            if not win.getPosition then return x, y end
            local wx, wy = win.getPosition()
            x, y = x + wx - 1, y + wy - 1
            _, win = debug.getupvalue(select(2, debug.getupvalue(win.isColor, 1)), 1) -- gets the parent window through an upvalue
        end
        return x, y
    end

    --- Runs the main loop, returning information on an action.
    ---@return any ... The result of the coroutine that exited
    function PrimeUI.run()
        while true do
            -- Restore the cursor and wait for the next event.
            if restoreCursor then restoreCursor() end
            local ev = table.pack(os.pullEvent())
            -- Run all coroutines.
            for _, v in ipairs(coros) do
                if v.filter == nil or v.filter == ev[1] then
                    -- Resume the coroutine, passing the current event.
                    local res = table.pack(coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)))
                    -- If the call failed, bail out. Coroutines should never exit.
                    if not res[1] then error(res[2], 2) end
                    -- If the coroutine resolved, return its values.
                    if res[2] == coros then return table.unpack(res, 3, res.n) end
                    -- Set the next event filter.
                    v.filter = res[2]
                end
            end
        end
    end
end

--- Creates a scrollable window, which allows drawing large content in a small area.
---@param win window The parent window of the scroll box
---@param x number The X position of the box
---@param y number The Y position of the box
---@param width number The width of the box
---@param height number The height of the outer box
---@param innerHeight number The height of the inner scroll area
---@param allowArrowKeys boolean|nil Whether to allow arrow keys to scroll the box (defaults to true)
---@param showScrollIndicators boolean|nil Whether to show arrow indicators on the right side when scrolling is available, which reduces the inner width by 1 (defaults to false)
---@param fgColor number|nil The color of scroll indicators (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
---@return window inner The inner window to draw inside
function PrimeUI.scrollBox(win, x, y, width, height, innerHeight, allowArrowKeys, showScrollIndicators, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, innerHeight, "number")
    expect(7, allowArrowKeys, "boolean", "nil")
    expect(8, showScrollIndicators, "boolean", "nil")
    fgColor = expect(9, fgColor, "number", "nil") or colors.white
    bgColor = expect(10, bgColor, "number", "nil") or colors.black
    if allowArrowKeys == nil then allowArrowKeys = true end
    -- Create the outer container box.
    local outer = window.create(win == term and term.current() or win, x, y, width, height)
    outer.setBackgroundColor(bgColor)
    outer.clear()
    -- Create the inner scrolling box.
    local inner = window.create(outer, 1, 1, width - (showScrollIndicators and 1 or 0), innerHeight)
    inner.setBackgroundColor(bgColor)
    inner.clear()
    -- Draw scroll indicators if desired.
    if showScrollIndicators then
        outer.setBackgroundColor(bgColor)
        outer.setTextColor(fgColor)
        outer.setCursorPos(width, height)
        outer.write(innerHeight > height and "\31" or " ")
    end
    -- Get the absolute position of the window.
    x, y = PrimeUI.getWindowPos(win, x, y)
    -- Add the scroll handler.
    PrimeUI.addTask(function()
        local scrollPos = 1
        while true do
            -- Wait for next event.
            local ev = table.pack(os.pullEvent())
            -- Update inner height in case it changed.
            innerHeight = select(2, inner.getSize())
            -- Check for scroll events and set direction.
            local dir
            if ev[1] == "key" and allowArrowKeys then
                if ev[2] == keys.up then dir = -1
                elseif ev[2] == keys.down then dir = 1 end
            elseif ev[1] == "mouse_scroll" and ev[3] >= x and ev[3] < x + width and ev[4] >= y and ev[4] < y + height then
                dir = ev[2]
            end
            -- If there's a scroll event, move the window vertically.
            if dir and (scrollPos + dir >= 1 and scrollPos + dir <= innerHeight - height) then
                scrollPos = scrollPos + dir
                inner.reposition(1, 2 - scrollPos)
            end
            -- Redraw scroll indicators if desired.
            if showScrollIndicators then
                outer.setBackgroundColor(bgColor)
                outer.setTextColor(fgColor)
                outer.setCursorPos(width, 1)
                outer.write(scrollPos > 1 and "\30" or " ")
                outer.setCursorPos(width, height)
                outer.write(scrollPos < innerHeight - height and "\31" or " ")
            end
        end
    end)
    return inner
end

--- Draws a line of text at a position.
---@param win window The window to draw on
---@param x number The X position of the left side of the text
---@param y number The Y position of the text
---@param text string The text to draw
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.label(win, x, y, text, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, text, "string")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(text)
end

--- Draws a horizontal line at a position with the specified width.
---@param win window The window to draw on
---@param x number The X position of the left side of the line
---@param y number The Y position of the line
---@param width number The width/length of the line
---@param fgColor color|nil The color of the line (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.horizontalLine(win, x, y, width, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    fgColor = expect(5, fgColor, "number", "nil") or colors.white
    bgColor = expect(6, bgColor, "number", "nil") or colors.black
    -- Use drawing characters to draw a thin line.
    win.setCursorPos(x, y)
    win.setTextColor(fgColor)
    win.setBackgroundColor(bgColor)
    win.write(("\x8C"):rep(width))
end

for s in htmldata:gmatch("[^\r\n]+") do
    table.insert(lines, s)
end
local function parseHTML(htmlString)
    local htmlTable = {}
    local currentIndex = 1
    while currentIndex <= #htmlString do
        local tagStart, tagEnd = htmlString:find("<[^>]+>", currentIndex)

        if tagStart then
            local text = htmlString:sub(currentIndex, tagStart - 1)
            if #text > 0 then
                table.insert(htmlTable, text)
            end

            local tag = htmlString:sub(tagStart, tagEnd)
            table.insert(htmlTable, tag)

            currentIndex = tagEnd + 1
        else
            local text = htmlString:sub(currentIndex)
            if #text > 0 then
                table.insert(htmlTable, text)
            end
            break
        end
    end

    return htmlTable
end

local line = ""
local text2 = ""
local inP = false
local inHTML = false
local inBody = false
local inHeading = false
local inLargeHeading = false
for i=1,#lines do
    line = lines[i]
    local parsedTable = parseHTML(line)
    for _,text in ipairs(parsedTable) do
        if text == "<p>" then
            inP = true
        elseif text == "</p>" then
            inP = false
        elseif text == "<html>" then
            inHTML = true
        elseif text == "</html>" then
            inHTML = false
        elseif text == "<body>" then
            inBody = true
        elseif text == "</body>" then
            inBody = false
        elseif text == "<h1>" or text == "<h2>" or text == "<h3>" then
            inLargeHeading = true
        elseif text == "<h4>" or text == "<h5>" or text == "<h6>" then
            inHeading = true
        elseif text == "</h1>" or text == "</h2>" or text == "</h3>" then
            inLargeHeading = false
        elseif text == "</h4>" or text == "</h5>" or text == "</h6>" then
            inHeading = false
        elseif text == "<br>" then
            text2 = text2.."\n"
        elseif string.sub(text,1,1)~="<" then
            if inHTML == true and inBody == true then
                text2 = text2..htmlentities.decode(text).."\n"
            else
                text2 = text2..htmlentities.decode(text)
            end
        end
    end
end

--- Draws a block of text inside a window with word wrapping, optionally resizing the window to fit.
---@param win window The window to draw in
---@param text string The text to draw
---@param resizeToFit boolean|nil Whether to resize the window to fit the text (defaults to false). This is useful for scroll boxes.
---@param fgColor color|nil The color of the text (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
---@return number lines The total number of lines drawn
function PrimeUI.drawText(win, text, resizeToFit, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, text, "string")
    expect(3, resizeToFit, "boolean", "nil")
    fgColor = expect(4, fgColor, "number", "nil") or colors.white
    bgColor = expect(5, bgColor, "number", "nil") or colors.black
    -- Set colors.
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    -- Redirect to the window to use print on it.
    local old = term.redirect(win)
    -- Draw the text using print().
    local lines = print(text)
    -- Redirect back to the original terminal.
    term.redirect(old)
    -- Resize the window if desired.
    if resizeToFit then
        -- Get original parameters.
        local x, y = win.getPosition()
        local w = win.getSize()
        -- Resize the window.
        win.reposition(x, y, w, lines)
    end
    return lines
end

--- Draws a thin border around a screen region.
---@param win window The window to draw on
---@param x number The X coordinate of the inside of the box
---@param y number The Y coordinate of the inside of the box
---@param width number The width of the inner box
---@param height number The height of the inner box
---@param fgColor color|nil The color of the border (defaults to white)
---@param bgColor color|nil The color of the background (defaults to black)
function PrimeUI.borderBox(win, x, y, width, height, fgColor, bgColor)
    expect(1, win, "table")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    fgColor = expect(6, fgColor, "number", "nil") or colors.white
    bgColor = expect(7, bgColor, "number", "nil") or colors.black
    -- Draw the top-left corner & top border.
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    win.setCursorPos(x - 1, y - 1)
    win.write("\x9C" .. ("\x8C"):rep(width))
    -- Draw the top-right corner.
    win.setBackgroundColor(fgColor)
    win.setTextColor(bgColor)
    win.write("\x93")
    -- Draw the right border.
    for i = 1, height do
        win.setCursorPos(win.getCursorPos() - 1, y + i - 1)
        win.write("\x95")
    end
    -- Draw the left border.
    win.setBackgroundColor(bgColor)
    win.setTextColor(fgColor)
    for i = 1, height do
        win.setCursorPos(x - 1, y + i - 1)
        win.write("\x95")
    end
    -- Draw the bottom border and corners.
    win.setCursorPos(x - 1, y + height)
    win.write("\x8D" .. ("\x8C"):rep(width) .. "\x8E")
end

PrimeUI.clear()
PrimeUI.label(term.current(), 3, 2, ip..":"..port)
PrimeUI.horizontalLine(term.current(), 3, 3, #(ip..":"..port))
local scroller = PrimeUI.scrollBox(term.current(), 4, 6, 40, 10, 9000, true, true,colors.black,colors.white)
PrimeUI.drawText(scroller, text2, true,colors.black,colors.white)
PrimeUI.run()
