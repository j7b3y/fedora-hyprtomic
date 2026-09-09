-- quadgrid: caps every tile at a 2x2 cell (same aspect ratio as the monitor).
-- Windows may sit in any of the 4 cells (sticky placement):
--   * new windows take the least-occupied cell (priority: BR, BL, TR, TL)
--   * several windows in one cell split it recursively like dwindle
--     (older windows keep the larger region)
--   * moving into an occupied cell cohabits instead of displacing
--   * cells freed by closing stay empty (no repacking)
--   * SUPER+SHIFT+arrows (move_or_swap): adjacent cell; at the grid border
--     it falls back to the built-in movewindow (keeps cross-monitor moves)
--   * mouse drag (on_drag_end): drop position decides the cell
--     (the C++ side ignores it, so we resolve it here)
--
-- Usage: requiring this file registers the layout and its events; applying it
-- is a workspace rule `layout = "lua:quadgrid"` (see custom/general.lua).

local M = {}

M.LAYOUT_NAME = "lua:quadgrid"

local cellOf = {} -- window address -> cell (row-major: 1=TL 2=TR 3=BL 4=BR)
local PREFER = { 4, 3, 2, 1 } -- free-cell assignment order (bottom-right anchor)

-- adjacency: ADJ[dir][from] = to (nil = grid border)
local ADJ = {
    left  = { [2] = 1, [4] = 3 },
    right = { [1] = 2, [3] = 4 },
    up    = { [3] = 1, [4] = 2 },
    down  = { [1] = 3, [2] = 4 },
}

local function isTile(w)
    return w.mapped and not w.floating and not w.hidden
end

-- dwindle-style recursive split of the last region (half along the long edge)
local function dwindleSplit(box, k)
    local boxes = { box }
    for _ = 2, k do
        local last = table.remove(boxes)
        local w, h = last.w, last.h
        if w >= h then
            table.insert(boxes, { x = last.x,         y = last.y, w = w / 2, h = h })
            table.insert(boxes, { x = last.x + w / 2,  y = last.y, w = w / 2, h = h })
        else
            table.insert(boxes, { x = last.x, y = last.y,         w = w, h = h / 2 })
            table.insert(boxes, { x = last.x, y = last.y + h / 2, w = w, h = h / 2 })
        end
    end
    return boxes
end

hl.layout.register("quadgrid", {
    recalculate = function(ctx)
        -- C++ may append the same target twice (drags etc.); dedupe
        local targets, seen = {}, {}
        for _, t in ipairs(ctx.targets) do
            local addr = t.window and t.window.address
            if not addr or not seen[addr] then
                if addr then
                    seen[addr] = true
                end
                targets[#targets + 1] = t
            end
        end
        if #targets == 0 then
            return
        end

        -- assign remembered cells first, pending ones to the emptiest cell
        local byCell = { {}, {}, {}, {} }
        local pending = {}
        for _, t in ipairs(targets) do
            local addr = t.window and t.window.address
            local c = addr and cellOf[addr]
            if c then
                table.insert(byCell[c], t)
            else
                table.insert(pending, t)
            end
        end
        for _, t in ipairs(pending) do
            local best = PREFER[1]
            for _, c in ipairs(PREFER) do
                if #byCell[c] < #byCell[best] then
                    best = c
                end
            end
            table.insert(byCell[best], t)
            local addr = t.window and t.window.address
            if addr then
                cellOf[addr] = best
            end
        end

        -- one window keeps its cell; multiple split it dwindle-style
        for c = 1, 4 do
            local group = byCell[c]
            local k = #group
            if k == 1 then
                group[1]:place(ctx:grid_cell(c, 2, 2))
            elseif k > 1 then
                local boxes = dwindleSplit(ctx:grid_cell(c, 2, 2), k)
                for i, t in ipairs(group) do
                    t:place(boxes[i])
                end
            end
        end
    end,

    -- "refresh" triggers relayout after cell-assignment changes
    layout_msg = function(_, msg)
        if msg == "refresh" then
            return true
        end
        return "quadgrid: unsupported layoutmsg: " .. tostring(msg)
    end,
})

local function refresh()
    hl.dispatch(hl.dsp.layout("refresh"))
end

-- move w into cell `to`, cohabiting (in-cell split) if occupied
local function moveToCell(w, to)
    if cellOf[w.address] == to then
        return
    end
    cellOf[w.address] = to
    refresh()
end

-- returns window, workspace when the active tiled window is on quadgrid
local function activeQuadgridTile()
    local w = hl.get_active_window()
    local ws = w and w.workspace
    if w and not w.floating and ws and ws.tiled_layout == M.LAYOUT_NAME then
        return w, ws
    end
    return nil, nil
end

-- bind action for SUPER+SHIFT+arrows
function M.move_or_swap(dir)
    local move = hl.dsp.window.move({ direction = dir })
    return function()
        local w = activeQuadgridTile()
        local from = w and cellOf[w.address]
        local to = from and ADJ[dir][from]
        if not to then
            -- other layouts / grid border: defer to the built-in dispatcher
            hl.dispatch(move)
            return
        end
        moveToCell(w, to)
    end
end

-- SUPER+LMB drag end (bind drag flag): place into the dropped-on cell
function M.on_drag_end()
    local w = activeQuadgridTile()
    if not w then
        return
    end
    local pos = hl.get_cursor_pos()
    local mon = w.monitor
    if not pos or not mon then
        return
    end
    local sw, sh = mon.width / mon.scale, mon.height / mon.scale
    if mon.transform % 2 == 1 then
        sw, sh = sh, sw
    end
    local col = (pos.x - mon.x) * 2 >= sw and 2 or 1
    local row = (pos.y - mon.y) * 2 >= sh and 2 or 1
    moveToCell(w, (row - 1) * 2 + col)
end

-- forget cells of destroyed windows
hl.on("window.destroy", function()
    local alive = {}
    for _, w in ipairs(hl.get_windows()) do
        alive[w.address] = true
    end
    for addr in pairs(cellOf) do
        if not alive[addr] then
            cellOf[addr] = nil
        end
    end
end)

return M
