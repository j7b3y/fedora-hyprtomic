-- quadgrid: タイルの最大サイズを 2x2 セル (モニタと同アスペクト比 = 16:9) に制限する。
-- 各ウィンドウは 4 セルのどこにでも自由に配置できる (sticky cell)。
-- ユーザーが動かした窓と新規窓以外は勝手に動かさない:
--   * 新規ウィンドウは占有数が最少のセルへ (同数なら右下→左下→右上→左上)
--   * 同一セルの複数ウィンドウは dwindle と同じ再帰二分割で同居する
--     (古い窓ほど大きい区画を維持、新しい窓が最後の区画をさらに半分割)
--   * キーでのセル移動 (SUPER+SHIFT+矢印 = move_or_swap) は先客を退かさず同居
--     (先客が縮んでスペースを空ける)
--   * マウスドラッグ (SUPER+LMB → on_drag/on_drag_end) はドロップした位置の
--     セルへ移動。先客が居るセルなら、ドロップ位置に最も近い窓と入れ替える
--     (同居はしない)
--   * 別モニタへのドロップは C++ 側のワークスペース移動に任せる。
--     ドロップ先のワークスペースも quadgrid なら同じセル位置を記憶する
--   * 同じセルに同居している窓 (8:9 が 2 枚並ぶなど) は、ドロップ位置に
--     近い同居窓とセル内で入れ替えられる。SUPER+SHIFT+矢印も、その方向に
--     同居窓があればセル内で入れ替える
--   * ウィンドウが閉じて枚数が減った時は、空きすぎのセルを埋めるように
--     均等に再配置する (dwindle のように隙間を残さない)。ドラッグ等で枚数が
--     変わらない時はユーザーの配置を尊重する
--   * 枚数が何枚でもタイルは 1/2 x 1/2 セル以下を維持する (2x2 セル +
--     セル内の再帰分割なので、5 枚以上でも縦横が半分を超えない)
--   * グリッド端での move_or_swap は本体の movewindow にフォールバック
--     (モニタ間移動を維持)
--     ※ C++ 側 (CLuaTiledAlgorithm::movedTarget) はドロップ位置を無視するため
--       マウスドロップのセル割当は自前処理
--
-- 使い方: require するだけで登録・イベント購読される。適用は workspace_rule の
-- layout = "lua:quadgrid" (host.lua)。

local M = {}

M.LAYOUT_NAME = "lua:quadgrid"

local cellOf = {} -- window address → セル番号 (行優先: 1=左上 2=右上 3=左下 4=右下)
local PREFER = { 4, 3, 2, 1 } -- 空きセルの割当順 (右下アンカー)

-- セル内の並び順 (小さいほど先頭 = 大きい区画)。同じセル内の入れ替えは
-- この連番を交換して行う。初出時に target 順で振るので、既定の並びは
-- 「古い窓ほど大きい区画」のまま
local seqOf = {}
local seqNext = 0

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

-- モニタの論理サイズ (回転 (transform) 適用後)。カーソル座標と同じ座標系
local function monitorSize(mon)
    local w, h = mon.width / (mon.scale or 1), mon.height / (mon.scale or 1)
    if (mon.transform or 0) % 2 == 1 then
        w, h = h, w
    end
    return w, h
end

-- モニタ上の座標 (x, y) が属するセル番号 (モニタ中央で 2x2 に分割)
local function cellAt(mon, x, y)
    local sw, sh = monitorSize(mon)
    local col = (x - mon.x) * 2 >= sw and 2 or 1
    local row = (y - mon.y) * 2 >= sh and 2 or 1
    return (row - 1) * 2 + col
end

local function containsPoint(mon, x, y)
    local sw, sh = monitorSize(mon)
    return x >= mon.x and y >= mon.y and x < mon.x + sw and y < mon.y + sh
end

-- 記憶が無い窓のセルを現在の位置 (中心点) から推定する
local function windowCell(w)
    local mon, at, size = w.monitor, w.at, w.size
    if not mon or not at or not size then
        return nil
    end
    return cellAt(mon, at.x + size.x / 2, at.y + size.y / 2)
end

-- グループは 1 枚のタイルとして数える (compositor から見ても 1 target)。
-- 非アクティブなグループメンバーは hidden ではなく alpha 0 なので、
-- isTile だけでは同じグループを複数枚と数えてしまう。
local function isCurrentTile(w)
    if not isTile(w) then
        return false
    end
    local group = w.group
    local current = group and group.current
    return current == nil or current.address == w.address
end

local function seqOfWindow(w)
    local addr = w and w.address
    if not addr then
        return nil
    end
    if not seqOf[addr] then
        seqNext = seqNext + 1
        seqOf[addr] = seqNext
    end
    return seqOf[addr]
end

-- 同一セル内の 2 枚の並び順 (左右/上下の区画) を入れ替える
local function swapOrder(a, b)
    local sa, sb = seqOf[a.address], seqOf[b.address]
    if not sa or not sb then
        return false
    end
    seqOf[a.address], seqOf[b.address] = sb, sa
    return true
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

-- セルごとの枚数が偏っていたら、混んでいるセルから空いているセルへ移して
-- floor/ceil(n/4) に揃える (窓が閉じて空いたセルを詰める)。
-- 移す窓は各セルの最後 (=新しい方) を優先し、行き先は空きが最少のセル。
local function rebalance(byCell)
    local n = 0
    for c = 1, 4 do
        n = n + #byCell[c]
    end
    if n == 0 then
        return
    end

    local floorQ, ceilQ = math.floor(n / 4), math.ceil(n / 4)
    local moved = false

    -- 上限を超えているセルの溢れた分を、空いているセルへ
    for _, c in ipairs(PREFER) do
        while #byCell[c] > ceilQ do
            local t = table.remove(byCell[c])
            local best
            for _, dst in ipairs(PREFER) do
                if #byCell[dst] < ceilQ and (not best or #byCell[dst] < #byCell[best]) then
                    best = dst
                end
            end
            if not best then
                table.insert(byCell[c], t)
                break
            end
            table.insert(byCell[best], t)
            moved = true
        end
    end

    -- 下限を割っているセルがあれば、余っているセルから移す
    for _, c in ipairs(PREFER) do
        if #byCell[c] < floorQ then
            for _, src in ipairs(PREFER) do
                if #byCell[src] > floorQ then
                    table.insert(byCell[c], table.remove(byCell[src]))
                    moved = true
                    break
                end
            end
        end
    end

    if moved then
        for c = 1, 4 do
            for _, t in ipairs(byCell[c]) do
                local addr = t.window and t.window.address
                if addr then
                    cellOf[addr] = c
                end
            end
        end
    end
end

-- タイル枚数が変わった時だけ再配置するための記録 (workspace config_name → 枚数)
local lastCount = {}

local function workspaceKey(targets)
    for _, t in ipairs(targets) do
        local ws = t.window and t.window.workspace
        local key = ws and ws.config_name
        if key and key ~= "" then
            return key
        end
    end
    return nil
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
            seqOfWindow(t.window) -- 初出の窓にセル内順序を振る
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

        -- セル内は seq 順 (古い窓ほど先頭 = 大きい区画)。入れ替えは seq を交換する
        for c = 1, 4 do
            table.sort(byCell[c], function(x, y)
                return (seqOf[x.window and x.window.address] or 0) < (seqOf[y.window and y.window.address] or 0)
            end)
        end

        -- 枚数が変わった時 (閉じた/増えた) だけ、空きすぎのセルを詰め直す。
        -- ドラッグ等で枚数が変わらない時はユーザーの配置を尊重する
        local key = workspaceKey(targets)
        if key and lastCount[key] ~= #targets then
            lastCount[key] = #targets
            rebalance(byCell)
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

-- 座標 (x, y) から窓の中心までの距離^2 (at/size が無ければ無限大)
local function centerDist(w, x, y)
    local at, size = w.at, w.size
    if not at or not size then
        return math.huge
    end
    local dx = at.x + size.x / 2 - x
    local dy = at.y + size.y / 2 - y
    return dx * dx + dy * dy
end

-- セル cell にある (除外した窓以外の) タイルのうち、座標 (x, y) に最も近いものを返す
local function tileNear(ws, cell, excludeAddress, x, y)
    local best, bestDist
    for _, w in ipairs(ws:get_windows()) do
        if isCurrentTile(w) and w.address ~= excludeAddress and (cellOf[w.address] or windowCell(w)) == cell then
            local dist = centerDist(w, x, y)
            if not bestDist or dist < bestDist then
                best, bestDist = w, dist
            end
        end
    end
    return best
end

-- 同じセルに居て dir 方向にある同居窓を返す (いなければ nil)。
-- 2 枚並び (8:9 など) で「右の窓を左へ」をセル内の入れ替えにするために使う
local function mateInDirection(w, cell, dir)
    local at, size = w.at, w.size
    local ws = w.workspace
    if not at or not size or not ws or not cell then
        return nil
    end

    local cx, cy = at.x + size.x / 2, at.y + size.y / 2
    local best, bestScore
    for _, m in ipairs(ws:get_windows()) do
        if isCurrentTile(m) and m.address ~= w.address and (cellOf[m.address] or windowCell(m)) == cell then
            local mat, msize = m.at, m.size
            if mat and msize then
                local dx = mat.x + msize.x / 2 - cx
                local dy = mat.y + msize.y / 2 - cy
                local along, side
                if dir == "left" then
                    along, side = -dx, math.abs(dy)
                elseif dir == "right" then
                    along, side = dx, math.abs(dy)
                elseif dir == "up" then
                    along, side = -dy, math.abs(dx)
                else
                    along, side = dy, math.abs(dx)
                end
                -- その方向に離れていて、直交方向のずれが小さい相手を選ぶ
                if along > 1 and (not bestScore or along + side < bestScore) then
                    best, bestScore = m, along + side
                end
            end
        end
    end
    return best
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

-- SUPER+SHIFT+矢印用のバインドアクションを返す。
-- その方向に同居窓があればセル内で入れ替え、無ければ隣のセルへ移動する。
-- 移動先がグリッド端なら本体の movewindow にフォールバックする
function M.move_or_swap(dir)
    local move = hl.dsp.window.move({ direction = dir })
    return function()
        local w = activeQuadgridTile()
        local from = w and (cellOf[w.address] or windowCell(w))

        -- 同居窓との入れ替え (同じセル内)
        local mate = w and mateInDirection(w, from, dir)
        if mate and swapOrder(w, mate) then
            refresh()
            return
        end

        local to = from and ADJ[dir][from]
        if not to then
            -- quadgrid 以外 / グリッド端 (モニタ間移動など) は本体に任せる
            hl.dispatch(move)
            return
        end
        moveToCell(w, to)
    end
end

-- SUPER+LMB の bind (hyprland.lua) 本体。
-- 押下時に押下位置を記憶して window.drag() を開始する。Hyprland は
-- requestBindRelease により「解放時にもう一度同じ bind を呼ぶ」ので、
-- 2 回目の呼び出し (release follow-up) でドロップ先のセルへ配置する。
-- ※ 押下用と解放用を別々の bind に分けると、押下を消費した bind が
--    解放用 bind を shadow して発火しなくなる (Hyprland 0.56 の shadowBinds)
local dragFrom = nil -- 押下時のカーソル位置 (nil = ドラッグしていない)

-- ドラッグとみなす最小移動量 (px)。binds:drag_threshold と揃える
local function dragThreshold()
    local t = hl.get_config("binds.drag_threshold")
    if type(t) == "number" then
        return math.max(t, 0)
    end
    return 10
end

function M.on_drag()
    if dragFrom then
        local from = dragFrom
        dragFrom = nil
        M.on_drag_end(from)
        return
    end
    dragFrom = { pos = hl.get_cursor_pos() }
    return hl.dispatch(hl.dsp.window.drag())
end

-- ドロップしたセルへ移動し、先客が居ればドロップ位置に最も近い窓と入れ替える。
-- 同じセルへドロップした場合は、そのセル内の並び順を入れ替える
-- (8:9 が 2 枚並ぶときの左右の入れ替え)。
-- 別モニタへドロップした場合は C++ 側 (ドラッグ中の assignToSpace) が
-- ドロップ先モニタのワークスペースへ移すので、その結果に従う。
-- pressed.pos は押下時のカーソル位置 (クリックを誤って配置替えしないため)
function M.on_drag_end(pressed)
    local w, ws = activeQuadgridTile()
    local pos = hl.get_cursor_pos()
    local mon = w and w.monitor
    if not w or not ws or not mon or not pos or not containsPoint(mon, pos.x, pos.y) then
        -- quadgrid 以外 / モニタ外 (別モニタへは C++ 側が移す) は何もしない
        return
    end

    -- しきい値未満の移動 (クリック) は配置替えしない
    local pressed_pos = pressed and pressed.pos
    local threshold = dragThreshold()
    if pressed_pos and threshold > 0 then
        local dx, dy = pos.x - pressed_pos.x, pos.y - pressed_pos.y
        if dx * dx + dy * dy < threshold * threshold then
            return
        end
    end

    local to = cellAt(mon, pos.x, pos.y)
    local old = cellOf[w.address] or windowCell(w)
    if old == to then
        -- 同じセル: ドロップ位置が同居窓側なら、セル内の並びを入れ替える。
        -- 自分側に戻した時は何もしない
        local mate = tileNear(ws, to, w.address, pos.x, pos.y)
        if mate and centerDist(mate, pos.x, pos.y) < centerDist(w, pos.x, pos.y) and swapOrder(w, mate) then
            refresh()
        end
        return
    end

    local other = tileNear(ws, to, w.address, pos.x, pos.y)
    if other and old then
        cellOf[other.address] = old -- 先客を移動元のセルへ (入れ替え)
    end
    cellOf[w.address] = to
    refresh()
end

-- 閉じたウィンドウのセル記憶と並び順を破棄
hl.on("window.destroy", function()
    local alive = {}
    for _, w in ipairs(hl.get_windows()) do
        alive[w.address] = true
    end
    for addr in pairs(cellOf) do
        if not alive[addr] then
            cellOf[addr] = nil
            seqOf[addr] = nil
        end
    end
end)

return M
