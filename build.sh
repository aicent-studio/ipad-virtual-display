#!/bin/zsh
# 编译并打包 iPad 远程伴侣.app；加 --install 会装到 /Applications 并重新启动。
set -euo pipefail
cd "$(dirname "$0")"

APP="build/iPad 远程伴侣.app"
rm -rf build/*.app(N)
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -target arm64-apple-macos13.0 \
  -import-objc-header Sources/VirtualScreenAPI.h \
  Sources/*.swift -o "$APP/Contents/MacOS/iPadDisplay"

cp Info.plist "$APP/Contents/Info.plist"

if [[ ! -f Resources/AppIcon.icns ]]; then
  mkdir -p Resources build/AppIcon.iconset
  swift Scripts/make-icon.swift Resources/AppIcon-source.png build/icon-1024.png
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon-1024.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon-1024.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp -R Resources/zh-Hans.lproj "$APP/Contents/Resources/"
cp Resources/avatar.jpg "$APP/Contents/Resources/"

codesign --force --sign - "$APP"
echo "已生成：$APP"

if [[ "${1:-}" == "--install" ]]; then
  # 旧名字「iPad 虚拟屏」的版本也一并退出并删除，免得两个同时存在
  for name in "iPad 远程伴侣" "iPad 虚拟屏"; do
    osascript -e "quit app \"$name\"" 2>/dev/null || true
  done
  sleep 2
  rm -rf "/Applications/iPad 远程伴侣.app" "/Applications/iPad 虚拟屏.app"
  cp -R "$APP" /Applications/
  open "/Applications/iPad 远程伴侣.app"
  echo "已安装到 /Applications 并启动"
fi
