-- Hyprland Configuration (Lua)
-- 基準: dotfiles リポジトリ arch/lua ブランチ (hypr/hyprland.lua)。
-- Fedora Atomic 向け adapted 版: Arch 専用ツール (clipse/hypremoji/polkit-gnome) は
-- イメージ側の代替 (clipryx/hypr-emoji-picker/hyprpolkitagent) に読替え、デバイス固有の
-- 値 (特定モニタ名・カーソルテーマ) は持たせない。
-- ~/.config/hypr/hyprland.lua が存在すると .conf より優先される。
-- デフォルトレイアウトは標準 dwindle。カスタムレイアウト quadgrid (layouts/quadgrid.lua)
-- は登録のみ行い、適用は host.lua (ユーザー作成) に委ねる。

-- Monitor - auto detect (host 設定で上書き)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.0,
})

-- Variables
local terminal    = "ghostty"
local fileManager = "nemo"
local menu        = "qs ipc call launcher toggle"
local mainMod     = "SUPER"

-- Host-specific settings: ~/.config/hypr/host.lua (setup-dotfiles.sh がテンプレを生成)
local hostOk, host = pcall(require, "host")
if not hostOk or type(host) ~= "table" then
    host = {}
end
-- 未設定なら空文字 = ドックは全出力に表示 (device 固定を bake しない)
local monitorPrimary = host.monitor_primary or ""

-- カスタムレイアウト登録 (~/.config/hypr/layouts/quadgrid.lua 経由。無ければ skip)
local quadgridOk, quadgrid = pcall(require, "layouts.quadgrid")
if not quadgridOk then
    quadgrid = nil
end

-- Environment
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "catppuccin-mocha-blue-standard+default")
hl.env("ADW_DEBUG_COLOR_SCHEME", "prefer-dark")
hl.env("XCURSOR_SIZE", "36")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
-- fcitx5 input method (Fedora: IM env はセッション側で明示が必要)
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("systemctl --user import-environment QT_QPA_PLATFORMTHEME")
    hl.exec_cmd("clipryx -d")
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("env GDK_BACKEND=x11 nm-applet")
    hl.exec_cmd("~/.config/hypr/scripts/dock-watch.sh '" .. monitorPrimary .. "'")
    hl.exec_cmd("qs")
    hl.exec_cmd("swaybg -i $HOME/.local/share/backgrounds/wallpaper.jpg -m fill")
    hl.exec_cmd("fcitx5 -d")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd("sleep 2 && dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

-- General
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = "rgba(8AB4F8cc)",
            inactive_border = "rgba(33353Aaa)",
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    -- Group (tabs) - integrated with terminal window
    group = {
        col = {
            border_active   = "rgba(ffffffcc)",
            border_inactive = "rgba(808080aa)",
        },
        -- auto_group=false: chrome 等の自動グループ参加を防止
        auto_group = false,
        groupbar = {
            enabled   = true,
            font_size = 10,
            height    = 24,
            gradients = true,
            blur      = true,
            col = {
                active   = "rgba(000000e6)",
                inactive = "rgba(000000e6)",
            },
            text_color          = "rgba(ffffffff)",
            text_color_inactive = "rgba(ffffffff)",
            indicator_height    = 2,
            rounding            = 4,
            gradient_rounding   = 4,
        },
    },

    -- Decoration
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = true,
            popups  = false,
            size    = 4,
            passes  = 1,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        middle_click_paste   = false,
        disable_autoreload   = true,
        render_unfocused_fps = 10,
    },

    cursor = {
        no_hardware_cursors = false,
    },

    render = {
        new_render_scheduling = true,
    },

    -- Input
    input = {
        kb_layout          = "jp",
        kb_options         = "caps:none",
        repeat_delay       = 800,
        numlock_by_default = true,
        follow_mouse       = 1,
        sensitivity        = 0.2,
        touchpad = {
            natural_scroll = false,
            scroll_factor  = 1.5,
        },
    },
})

-- Animations
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- Keybindings
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprbind"), { desc = "キーバインドを確認" })
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), { desc = "ターミナルを開く (単体)" })
hl.bind(mainMod .. " + X", hl.dsp.window.close(), { desc = "アクティブウィンドウを閉じる" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), { desc = "ファイルマネージャを開く" })
-- タイル窓を float 化すると直前のタイルサイズがそのまま採用され画面をほぼ覆ってしまう
-- (windowrule の max_size は togglefloating では再評価されず効かない実測済み) ため、
-- float 化した直後に限り明示的に上限までリサイズしてセンタリングする
hl.bind(mainMod .. " + F", function()
    local w = hl.get_active_window()
    local wasFloating = w and w.floating
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    if not w or wasFloating then
        return
    end
    local mon = w.monitor
    if not mon then
        return
    end
    local maxW = mon.width / mon.scale * 0.25
    local maxH = mon.height / mon.scale * 0.25
    if w.size.x > maxW or w.size.y > maxH then
        hl.dispatch(hl.dsp.window.resize({ x = math.min(w.size.x, maxW), y = math.min(w.size.y, maxH), relative = false }))
        hl.dispatch(hl.dsp.window.center())
    end
end, { desc = "フローティング切り替え" })
hl.bind("Henkan_Mode", hl.dsp.exec_cmd(menu), { desc = "アプリランチャを開く (変換キー)" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { desc = "Pseudo モード切り替え (dwindle)" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { desc = "スプリット方向切り替え (dwindle)" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"), { desc = "画面ロック" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("google-chrome-stable --ozone-platform=wayland"), { desc = "Chrome を開く" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("bitwarden"), { desc = "Bitwarden を開く" })

-- Focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  { desc = "フォーカス移動: 左" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { desc = "フォーカス移動: 右" })
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    { desc = "フォーカス移動: 上" })
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),   { desc = "フォーカス移動: 下" })

-- Move window (quadgrid 上では隣接セルへ移動。先客が居れば縮小して同居)
local function moveWindowAction(dir)
    if quadgrid then
        return quadgrid.move_or_swap(dir)
    end
    return hl.dsp.window.move({ direction = dir })
end
hl.bind(mainMod .. " + SHIFT + left",  moveWindowAction("left"),  { desc = "ウィンドウ移動: 左" })
hl.bind(mainMod .. " + SHIFT + right", moveWindowAction("right"), { desc = "ウィンドウ移動: 右" })
hl.bind(mainMod .. " + SHIFT + up",    moveWindowAction("up"),    { desc = "ウィンドウ移動: 上" })
hl.bind(mainMod .. " + SHIFT + down",  moveWindowAction("down"),  { desc = "ウィンドウ移動: 下" })

-- Utilities
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("rofi -show window"), { desc = "ウィンドウスイッチャ (rofi)" })
hl.bind(mainMod .. " + SHIFT + S",
    hl.dsp.exec_cmd([[mkdir -p "$HOME/Pictures/Screenshots" && FILE="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" && grim -g "$(slurp)" "$FILE" && wl-copy --type image/png < "$FILE"]]),
    { desc = "領域スクリーンショットをコピーして保存" })
hl.bind(mainMod .. " + CTRL + SHIFT + S",
    hl.dsp.exec_cmd([[mkdir -p "$HOME/Pictures/Screenshots" && grim -g "$(slurp)" "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"]]),
    { desc = "領域スクリーンショットを保存" })
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -f hex"), { desc = "カラーピッカー" })
hl.bind(mainMod .. " + DELETE", hl.dsp.exec_cmd("qs ipc call powermenu toggle"), { desc = "電源メニュー" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("qs ipc call controlcenter toggle"), { desc = "コントロールセンター" })

-- Ghostty ネイティブタブを使用 (Ctrl+Shift+T/Q/←/→ は Ghostty が処理)

-- Workspaces
for i = 1, 10 do
    local key = i % 10 -- 10 は 0 キー
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }),
        { desc = "ワークスペース " .. i .. " へ" })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }),
        { desc = "ウィンドウをワークスペース " .. i .. " に移動" })
end

-- Workspace scroll
hl.bind(mainMod .. " + mouse_down",   hl.dsp.focus({ workspace = "e+1" }), { desc = "次のワークスペース (スクロール)" })
hl.bind(mainMod .. " + mouse_up",     hl.dsp.focus({ workspace = "e-1" }), { desc = "前のワークスペース (スクロール)" })
hl.bind(mainMod .. " + bracketleft",  hl.dsp.focus({ workspace = "e-1" }), { desc = "前のワークスペース" })
hl.bind(mainMod .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }), { desc = "次のワークスペース" })
hl.bind(mainMod .. " + TAB",          hl.dsp.focus({ workspace = "e+1" }), { desc = "次のワークスペース (Tab)" })

-- Disable noisy keys
hl.bind("Caps_Lock", hl.dsp.no_op(), { desc = "Caps Lock 無効化" })
hl.bind("Insert",    hl.dsp.no_op(), { desc = "Insert キー無効化" })

-- Resize (repeat)
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -20, y = 0,  relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 左 -20px" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 20,  y = 0,  relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 右 +20px" })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -20, relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 上 -20px" })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 20,  relative = true }), { repeating = true, desc = "ウィンドウリサイズ: 下 +20px" })

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, desc = "マウスドラッグでウィンドウ移動" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "マウスドラッグでウィンドウリサイズ" })
if quadgrid then
    -- quadgrid のタイルはドロップしたセルに配置 (drag = ドラッグ後のボタンリリースで発火)
    hl.bind(mainMod .. " + mouse:272", quadgrid.on_drag_end, { drag = true, desc = "quadgrid: ドロップ先セルに配置" })
end

-- Locked bindings - work on lock screen
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true, desc = "音量を上げる" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true, desc = "音量を下げる" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true, desc = "出力ミュート切り替え" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true, desc = "マイクミュート切り替え" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/scripts/bright.sh 5%+"),
    { locked = true, repeating = true, desc = "画面輝度を上げる" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/bright.sh 5%-"),
    { locked = true, repeating = true, desc = "画面輝度を下げる" })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, desc = "次の曲" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "再生/一時停止" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "再生/一時停止" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, desc = "前の曲" })

-- Regular bindings
hl.bind(mainMod .. " + V",      hl.dsp.exec_cmd("clipryx"),          { desc = "クリップボード履歴" })
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("hypr-emoji-picker"), { desc = "絵文字ピッカー" })

-- Window rules
hl.window_rule({
    name    = "opacity-apps",
    match   = { class = "^(google-chrome|nemo|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|Blueman-manager|nwg-look|org.gnome.FileRoller|org.fcitx.fcitx5-config-qt)$" },
    opacity = 0.925,
})

hl.window_rule({
    name    = "opacity-ghostty",
    match   = { class = "^com\\.mitchellh\\.ghostty$" },
    opacity = 1.0,
})

hl.window_rule({
    name  = "float-utils",
    match = { class = "^(authentication-agent|Rustdesk|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|Blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name    = "float-pickers",
    match   = { class = "^(clipryx|hypr-emoji-picker|Hypr-emoji-picker)$" },
    float   = true,
    center  = true,
    opacity = 0.9,
})

hl.window_rule({
    name  = "float-qt5ct-shotcut",
    match = { initial_class = "^(qt5ct|org.shotcut.Shotcut)$" },
    float = true,
})

hl.window_rule({
    name  = "float-steam",
    match = { initial_class = "^(steam)$" },
    float = true,
})

hl.window_rule({
    name   = "float-portals",
    match  = { initial_class = ".*-desktop-portal-.*" },
    float  = true,
    center = true,
})

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name   = "float-satty",
    match  = { class = "com.gabm.satty" },
    float  = true,
    size   = "(monitor_w*0.6) (monitor_h*0.7)",
    center = true,
})

hl.window_rule({
    name    = "float-missioncenter",
    match   = { class = "io.missioncenter.MissionCenter" },
    float   = true,
    size    = "(monitor_w*0.5) (monitor_h*0.6)",
    center  = true,
    opacity = 0.85,
})

hl.window_rule({
    name    = "float-hyprbind",
    match   = { initial_title = "^HyprBind$" },
    float   = true,
    size    = "(monitor_w*0.5) (monitor_h*0.6)",
    center  = true,
    opacity = 0.85,
})

hl.window_rule({
    name           = "pip-float",
    match          = { title = "^(Picture-in-Picture|ピクチャー イン ピクチャー)$" },
    float          = true,
    pin            = true,
    suppress_event = "float",
})

hl.window_rule({
    name           = "float-waydroid",
    match          = { class = "Waydroid" },
    float          = true,
    center         = true,
    suppress_event = "activate activatefocus",
})

hl.window_rule({
    name  = "float-wine-proton",
    match = { class = "^(steam_app_.*|.*\\.exe)$" },
    float = true,
})

-- Layer rules
hl.layer_rule({ name = "waybar-blur",        match = { namespace = "waybar" },                    blur = true })
hl.layer_rule({ name = "waybar-blur-popups", match = { namespace = "waybar" },                    blur_popups = true })
hl.layer_rule({ name = "waybar-alpha",       match = { namespace = "waybar" },                    ignore_alpha = 0.5 })
hl.layer_rule({ name = "powermenu",          match = { namespace = "quickshell:powermenu" },      blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "controlcenter",      match = { namespace = "quickshell:controlcenter" },  blur = true,  ignore_alpha = 0.5 })
hl.layer_rule({ name = "notifications",      match = { namespace = "quickshell:notifications" },  blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "shelf",              match = { namespace = "quickshell:shelf" },          blur = true,  ignore_alpha = 0.5 })
hl.layer_rule({ name = "launcher",           match = { namespace = "quickshell:launcher" },       blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "volume-osd",         match = { namespace = "quickshell:volume-osd" },     blur = false, ignore_alpha = 0.5 })
hl.layer_rule({ name = "rofi",               match = { namespace = "rofi" },                      blur = true,  ignore_alpha = 0.2 })
