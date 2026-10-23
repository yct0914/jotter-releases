#!/bin/sh
# Jotter 安装 / 升级：下载最新版，装进「应用程序」，装好命令行 jot，然后打开。
# 用法：curl -fsSL https://raw.githubusercontent.com/yct0914/jotter-releases/main/install.sh | sh
set -e
FEED="${JOTTER_FEED:-https://raw.githubusercontent.com/yct0914/jotter-releases/main/latest.json}"
# 测试用：JOTTER_INSTALL_TEST=<目录> 时装进那个目录，不退出、不打开 Jotter，也不装 jot
TEST_DIR="${JOTTER_INSTALL_TEST:-}"
say() { printf '%s\n' "$*"; }
field() { printf '%s' "$JSON" | tr ',' '\n' | sed -n "s/.*\"$1\" *: *\"\{0,1\}\([^\"]*\)\"\{0,1\}.*/\1/p" | head -1; }

[ "$(uname)" = Darwin ] || { say "Jotter 只能装在 Mac 上"; exit 1; }
say "正在查最新版本…"
JSON=$(curl -fsSL "$FEED") || { say "连不上 GitHub，检查一下网络再试"; exit 1; }
VER=$(field version); URL=$(field url); SHA=$(field sha256)
[ -n "$URL" ] && [ -n "$SHA" ] || { say "版本说明读不懂，请联系作者"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
say "正在下载 Jotter ${VER}…"
curl -fL --progress-bar "$URL" -o "$TMP/Jotter.zip"
[ "$(shasum -a 256 "$TMP/Jotter.zip" | cut -d' ' -f1)" = "$SHA" ] || { say "下载的文件不完整，请重试"; exit 1; }
ditto -x -k "$TMP/Jotter.zip" "$TMP/new"

if [ -n "$TEST_DIR" ]; then
  ditto "$TMP/new/Jotter.app" "$TEST_DIR/Jotter.app"
  xattr -dr com.apple.quarantine "$TEST_DIR/Jotter.app" 2>/dev/null || true
  say "装好了：Jotter ${VER}（${TEST_DIR}/Jotter.app）"
  exit 0
fi

if pgrep -qx Jotter; then
  say "先退出正在运行的 Jotter…"
  osascript -e 'quit app "Jotter"' >/dev/null 2>&1 || true
  n=0; while pgrep -qx Jotter; do n=$((n + 1)); [ $n -gt 60 ] && { say "Jotter 没有退出（可能有没保存的文件），处理完再运行一次"; exit 1; }; sleep 0.5; done
fi

DEST=/Applications
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
rm -rf "$DEST/Jotter.app"
ditto "$TMP/new/Jotter.app" "$DEST/Jotter.app"
xattr -dr com.apple.quarantine "$DEST/Jotter.app" 2>/dev/null || true

mkdir -p "$HOME/.local/bin"
ln -sf "$DEST/Jotter.app/Contents/MacOS/jot" "$HOME/.local/bin/jot"
open "$DEST/Jotter.app"
say "装好了：Jotter ${VER}（${DEST}/Jotter.app）"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) say "命令行 jot 也装好了，比如：jot 文件名、echo hi | jot" ;;
  *) say "命令行 jot 装在 ~/.local/bin，要在终端里用，把这一行加进 ~/.zshrc：export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
say "以后有新版，Jotter 会自己提醒你更新。"
