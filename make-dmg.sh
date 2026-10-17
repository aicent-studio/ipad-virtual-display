#!/bin/zsh
# 打包成 dmg 安装包：左边应用图标、右边「应用程序」文件夹，带设计好的背景。
# 产物：dist/iPad远程伴侣-<版本号>.dmg
set -euo pipefail
cd "$(dirname "$0")"

VOLUME="iPad 远程伴侣"
APP_NAME="iPad 远程伴侣.app"
VERSION=$(plutil -extract CFBundleShortVersionString raw Info.plist)
OUTPUT="dist/iPad远程伴侣-${VERSION}.dmg"
STAGING="build/dmg-staging"
TEMP_DMG="build/dmg-temp.dmg"

./build.sh

# 1. 准备安装包内容
rm -rf "$STAGING" "$TEMP_DMG"
mkdir -p "$STAGING/.background" dist
cp -R "build/$APP_NAME" "$STAGING/"
ln -s /Applications "$STAGING/应用程序"
swift Scripts/make-dmg-background.swift build/dmg-bg
tiffutil -cathidpicheck build/dmg-bg/background.png build/dmg-bg/background@2x.png -out "$STAGING/.background/background.tiff" >/dev/null

# 2. 生成可写的临时镜像并挂载（先卸载同名旧卷）
hdiutil detach "/Volumes/$VOLUME" -quiet 2>/dev/null || true
hdiutil create -srcfolder "$STAGING" -volname "$VOLUME" -fs HFS+ -format UDRW -ov "$TEMP_DMG" >/dev/null
# 从挂载结果读出实际挂载点（同名卷未卸载时系统会挂到「… 1」之类的路径）
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen | awk -F'\t' '/\/Volumes\// {print $NF}' | tail -1)
DISK_NAME=$(basename "$MOUNT_DIR")
echo "临时镜像挂载于：$MOUNT_DIR"

# 3. 让访达摆好窗口：大小与背景一致（660×420，另加标题栏），图标位置与背景上的箭头对齐
osascript <<EOF
tell application "Finder"
    tell disk "$DISK_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 568}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "$APP_NAME" of container window to {170, 215}
        set position of item "应用程序" of container window to {490, 215}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# 4. 安装包本身的图标用应用图标。放在访达设置之后：建镜像时会漏掉这个文件，访达摆放窗口时也会把它清掉
cp Resources/AppIcon.icns "$MOUNT_DIR/.VolumeIcon.icns"
SetFile -a C "$MOUNT_DIR"

# 5. 写入完成后卸载，压缩成只读安装包
sync
rm -rf "$MOUNT_DIR/.fseventsd"
hdiutil detach "$MOUNT_DIR" -quiet
rm -f "$OUTPUT"
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT" >/dev/null
rm -rf "$TEMP_DMG" "$STAGING"

# 6. dmg 文件本身也用应用图标。图标记在文件的附加信息里：隔空投送、U 盘、zip 能保留，微信、邮件、网盘会丢失
swift -e 'import AppKit; NSWorkspace.shared.setIcon(NSImage(contentsOfFile: CommandLine.arguments[1]), forFile: CommandLine.arguments[2], options: [])' \
  Resources/AppIcon.icns "$OUTPUT"

echo "已生成：$OUTPUT（$(du -h "$OUTPUT" | cut -f1)）"
