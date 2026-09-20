#!/bin/zsh
set -eu
cd "$(dirname "$0")"
mkdir -p '刘海聊天.app/Contents/MacOS' '刘海聊天.app/Contents/Resources'
cp AppIcon.icns '刘海聊天.app/Contents/Resources/AppIcon.icns'
swiftc main.swift -o '刘海聊天.app/Contents/MacOS/NotchChat' -framework Cocoa -framework WebKit
cat > '刘海聊天.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NotchChat</string>
<key>CFBundleIdentifier</key><string>local.yu.NotchChatPrototype</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>27</string>
<key>CFBundleName</key><string>刘海聊天</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.27</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - '刘海聊天.app'
