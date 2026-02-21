# Alarm — Claude Code 项目指南

iOS 闹钟应用，支持通勤时间感知、节假日判断、多语言（中/英）。

## 技术栈

- **语言**: Swift 5, SwiftUI
- **框架**: SwiftData, MapKit, CoreLocation, UserNotifications
- **最低 iOS**: 17.0
- **Xcode**: 16+
- **项目生成**: [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`project.yml` → `.xcodeproj`）

## 新 Mac 快速部署

### 1. 安装依赖

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# XcodeGen（必须）
brew install xcodegen
```

### 2. 克隆并生成 Xcode 项目

```bash
git clone <REPO_URL> ~/dev/Alarm
cd ~/dev/Alarm
xcodegen generate
```

### 3. 构建并部署

```bash
# 自动检测连接的 iPhone 或 Simulator
./deploy.sh
```

> **真机部署**: 需要在 Xcode 中将 `DEVELOPMENT_TEAM` 改为自己的 Team ID（当前为 `MS49M8LMJ8`）。

## 项目结构

```
Alarm/
├── project.yml          # XcodeGen 配置（唯一的项目定义）
├── deploy.sh            # 一键构建 + 部署脚本
├── AlarmApp.swift       # App 入口
├── ContentView.swift    # 根视图
├── Models/              # SwiftData 数据模型
├── Services/            # 位置、通知、节假日、通勤服务
├── Views/               # SwiftUI 视图（Alarm/Calendar/Commute/Settings）
├── Utils/               # 工具扩展
├── Assets.xcassets      # 图片资源
├── Localizable.xcstrings# 中英文本
└── Info.plist           # App 配置
```

## Claude 插件

- **swift-lsp**: 已在 `.claude/settings.json` 中启用，提供 Swift 语义补全与诊断。

## 常用操作

| 操作 | 命令 |
|------|------|
| 重新生成 Xcode 项目 | `xcodegen generate` |
| 部署到设备/模拟器 | `./deploy.sh` |
