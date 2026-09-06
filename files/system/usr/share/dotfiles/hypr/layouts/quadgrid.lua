-- quadgrid: タイルの最大サイズを 2x2 セル (モニタと同アスペクト比 = 16:9) に制限する。
-- 各ウィンドウは 4 セルのどこにでも自由に配置できる (sticky cell)。
-- ユーザーが動かした窓と新規窓以外は勝手に動かさない:
--   * 新規ウィンドウは占有数が最少のセルへ (同数なら右下→左下→右上→左上)
--   * 同一セルの複数ウィンドウは dwindle と同じ再帰二分割で同居する
--     (古い窓ほど大きい区画を維持、新しい窓が最後の区画をさらに半分割)
--   * セルへの移動 (キー/マウス) は先客を退かさず同居 (先客が縮んでスペースを空ける)
--   * ウィンドウが閉じて空いたセルはそのまま空きになる (自動で詰めない)
--   * SUPER+SHIFT+矢印 (move_or_swap): 隣のセルへ移動。
--     グリッド端では本体の movewindow にフォールバック (モニタ間移動を維持)
--   * マウスドラッグ (on_drag_end): ドロップした位置のセルへ移動。
--     ※ C++ 側 (CLuaTiledAlgorithm::movedTarget) はドロップ位置を無視するため自前処理
--
-- 使い方: require するだけで登録・イベント購読される。適用は workspace_rule の
-- layout = "lua:quadgrid" (host.lua)。

local M = {}

M.LAYOUT_NAME = "lua:quadgrid"

local cellOf = {} -- window address → セル番号 (行優先: 1=左上 2=右上 3=左下 4=右下)
local PREFER = { 4, 3, 2, 1 } -- 空きセルの割当順 (右下アンカー)

-- 隣接セル: ADJ[dir][from] = to (nil はグリッド端)
local ADJ = {
    left  = { [2] = 1, [4] = 3 },
    right = { [1] = 2, [3] = 4 },
    up    = { [3] = 1, [4] = 2 },
    down  = { [1] = 3, [2] = 4 },
}

local function isTile(w)
    return w.mapped and not w.floating and not w.hidden
end

-- dwindle と同じ再帰二分割: 直近の区画を長辺方向に半分割し続ける。
-- k=3 なら 大きい1枚 + 縦に並んだ2枚 (左右いずれかは box の縦横比次第) になる
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
        -- C++ 側がドラッグ等で同一 target を再 append することがあるため重複排除
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

        -- セル割当: 記憶があればそのセル、無ければ占有数最少のセルへ
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

        -- 配置: 1 枚ならセルそのまま、複数は dwindle と同じ再帰二分割
        -- (group はセルに入った順=古い窓ほど大きい区画を維持する)
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

    -- "refresh" はセル割当変更後の再配置トリガとして使う
    layout_msg = function(_, msg)
        if msg == "refresh" then
            return true
        end
        return "quadgrid: unsupported layoutmsg: " .. tostring(msg)
    end,
})

-- アクティブワークスペースのレイアウトに再配置させる
local function refresh()
    hl.dispatch(hl.dsp.layout("refresh"))
end

-- w をセル to へ移動。先客が居ても退かさず同居 (セル内分割)
local function moveToCell(w, to)
    if cellOf[w.address] == to then
        return
    end
    cellOf[w.address] = to
    refresh()
end

-- quadgrid 上のアクティブなタイル窓なら window, workspace を返す
local function activeQuadgridTile()
    local w = hl.get_active_window()
    local ws = w and w.workspace
    if w and not w.floating and ws and ws.tiled_layout == M.LAYOUT_NAME then
        return w, ws
    end
    return nil, nil
end

-- SUPER+SHIFT+矢印用のバインドアクションを返す
function M.move_or_swap(dir)
    local move = hl.dsp.window.move({ direction = dir })
    return function()
        local w = activeQuadgridTile()
        local from = w and cellOf[w.address]
        local to = from and ADJ[dir][from]
        if not to then
            -- quadgrid 以外 / グリッド端 (モニタ間移動など) は本体に任せる
            hl.dispatch(move)
            return
        end
        moveToCell(w, to)
    end
end

-- SUPER+LMB ドラッグ終了時 (bind の drag フラグ) に呼ぶ: カーソル位置のセルへ配置
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

-- 閉じたウィンドウのセル記憶を破棄
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
