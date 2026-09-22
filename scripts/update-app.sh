#!/bin/bash
# 从 fork 的 nightly release 下载最新构建并安装到 /Applications。
# 年度维护流程:
#   1) python3 scripts/generate_trading_calendar.py   # 刷新交易日历
#   2) git commit + push                              # CI 自动构建(约4分钟)
#   3) ./scripts/update-app.sh                        # 下载并安装
set -e
REPO="wanghlstar/PanBar"
APP="PanBar"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "→ 下载 nightly 构建..."
curl -sL -o "$WORK/PanBar.zip" "https://github.com/$REPO/releases/download/nightly/PanBar.zip?cb=$(date +%s)"
[ -s "$WORK/PanBar.zip" ] || { echo "❌ 下载失败(CI 可能还没跑完,稍等再试)"; exit 1; }

cd "$WORK" && unzip -q PanBar.zip
[ -d "$APP.app" ] || { echo "❌ 包内容异常"; exit 1; }

echo "→ 备份当前版本到 ~/.attic/"
mkdir -p ~/.attic
[ -d "/Applications/$APP.app" ] && rm -rf "$HOME/.attic/$APP-$(date +%Y%m%d-%H%M%S).app" && cp -R "/Applications/$APP.app" "$HOME/.attic/$APP-$(date +%Y%m%d-%H%M%S).app"

echo "→ 停止旧版并安装..."
osascript -e "quit app \"$APP\"" 2>/dev/null || true
sleep 1
rm -rf "/Applications/$APP.app"
cp -R "$WORK/$APP.app" "/Applications/$APP.app"
xattr -cr "/Applications/$APP.app"
codesign --force --deep -s - "/Applications/$APP.app" 2>/dev/null

echo "→ 启动..."
open "/Applications/$APP.app"
sleep 2
if pgrep -f "$APP.app/Contents/MacOS" >/dev/null; then
    echo "✅ 完成:$APP 已更新并运行"
else
    echo "⚠️ 已安装但未自动启动,请手动打开 /Applications/$APP.app"
fi
