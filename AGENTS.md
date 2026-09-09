# このリポジトリについて
- Fedora Atomicベース
- Github Acrion Workflowによる自動更新
- いくつかのリファレンスを元としたdotfilesを組み込みデフォルトで反映したイメージをビルド

# Refarences
- [Base Dotfiles](https://github.com/j7b3y/fedora-hyprtomic/tree/fix/setup)
> 方針を変えたため没になった以前のAtomicブランチ
> include packages: clipryx,ghostty,hazkey,hypr-emoji-picker,hyprbind,sddm-theme,snipland
> ghostty,hazkey以外は自身でビルドして組み込む必要がある。

- [sync-skel-config システム](https://github.com/oameye/atomic-hyprland)
> 上流の更新を反映するためのスクリプト。
> command: ujust overwrite=1 sync-skel-config

- [GUI全般のリファレンス](https://github.com/end-4/dots-hyprland)
> 以下の点はデフォルトから変更
>> barは下に配置,barポジションに追従しているものもbarが下に移動したことを加味して必要な場合は最適化すること。
>> Base Dotsfilesに従い、ウィンドウ管理はタイル形式の自動配置&一部アプリと手動切り替えでfloat windowの形式を維持したい。
>> 大画面モニター向けのカスタムレイアウト(quadgrid)も改修して後々採用するつもりなので組み込んでほしいが基本のレイアウトはデフォルトのものを採用してほしい。

# 以下必要な場合に追記用のTODO領域

# 統合実装メモ (dev/dot-fusion)
- GUI: end-4/dots-hyprland を固定コミットで files/system/etc/skel/ にベンダー済み (pin: /usr/share/hyprtomic/versions.env)
- 変更点は ~/.config/hypr/custom/ (HyprTomic レイヤー) と ~/.config/illogical-impulse/config.json (bar.bottom=true) に集約
- quadgrid は ~/.config/hypr/layouts/quadgrid.lua に同梱、custom/general.lua で登録 (デフォルトレイアウトは未変更、ワークスペースルールで opt-in)
- dotfile配信: /etc/skel + `ujust sync-skel-config` (oameye方式, overwrite=1で管理ファイル置換&prune)
- 旧自作GUI (quickshell Shelf, waybar, rofi, nwg-dock, dunst, catppuccin GTK/Kvantum) は撤去済み
- Base Dotfilesツール (clipryx/ghostty/hazkey/hypr-emoji-picker/hyprbind/snipland/sddm-theme) は維持、キーバインドはiiと衝突しないキーに割当


