# Codex Menu Quota

一款原生 macOS 菜单栏应用，用于查看本机 Codex 的 5 小时额度、每周额度和可用重置次数。

## 功能

- 在菜单栏直接展示剩余额度
- 环形进度卡片展示 5 小时与每周额度
- 展示额度重置时间和可用重置次数
- 支持自动刷新、菜单栏显示项配置和登录时启动
- 支持浅色与深色模式

## 运行要求

- macOS 14 或更高版本
- 已安装 Codex 桌面应用
- Codex 已使用 ChatGPT 账号登录

应用通过 Codex 自带的本地 `app-server` 读取额度，不读取或保存登录令牌。

## 开发

使用 Xcode 打开：

```text
codex-menu-quota.xcodeproj
```

选择 `codex-menu-quota` Scheme 和 `My Mac`，然后运行。

## 构建 DMG

在项目根目录执行：

```bash
./scripts/build-dmg.sh
```

生成结果位于 `dist/`。默认构建同时支持 Apple Silicon 和 Intel 的通用版本。

> 当前项目默认采用本机临时签名。公开分发前需要配置 Developer ID、开启 Hardened Runtime 并完成 Apple 公证。
