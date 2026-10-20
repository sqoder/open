#!/bin/bash
pkill -f "momi" 2>/dev/null || true
open /Applications/momi.app
echo "momi 已启动并在 Mac 顶部菜单栏显示！"
