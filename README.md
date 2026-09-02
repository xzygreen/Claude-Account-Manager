# Claude 账号管理（macOS）

一个完全本地、面向 `claude.ai` 个人网页登录账号的原生 macOS 管理工具。它不调用 Claude API，也不会联网读取账号状态。

## 已实现功能

- 添加、查看、编辑和删除账号。
- 批量粘贴导入，支持旧格式、`|` 分隔格式和 JSON。
- 搜索邮箱、标签和备注。
- 按状态、注册时间范围筛选；按注册时间正序/倒序、最后使用或邮箱排序。
- 标记唯一“当前使用中”账号，并更新最后使用时间。
- 支持以 `mail|登录链接|sessionkey|注册时间|状态|标签|最后使用|备注` 格式导出文本文件，便于分发与再导入。
- Session Key 与自动登录链接保存在本机加密保险库中；SQLite 仅存元数据。

## 技术栈

- Swift 5.10 / SwiftUI
- SQLite 3（系统库，无第三方依赖）
- Security.framework / macOS Keychain
- 最低 macOS 14

选择原生 SwiftUI 的原因是应用只面向 macOS，系统表格、侧边栏、Form、Keychain、深浅色和键盘操作都可以直接使用平台能力。相比 Electron，它没有浏览器运行时和网络依赖；相比 Tauri，它也不需要维护 Web UI 与 Rust 桥接层。

## 数据结构

SQLite 表 `accounts`：

| 字段 | SQLite 类型 | 说明 |
|---|---|---|
| `id` | TEXT PK | UUID |
| `email` | TEXT UNIQUE | 忽略大小写唯一 |
| `registered_at` | REAL | Unix 时间戳，已建索引 |
| `status` | TEXT | normal / restricted / invalid / pendingVerification |
| `last_used` | REAL NULL | 可为空，已建索引 |
| `tags_json` | TEXT | JSON 字符串数组 |
| `note` | TEXT | 备注 |
| `created_at` | REAL | 创建或首次导入时间 |
| `updated_at` | REAL | 最后修改时间 |
| `is_current` | INTEGER | 唯一部分索引确保最多一个当前账号 |

`login_link` 和 `session_key` 不进入 SQLite。它们存放在 Application Support 下的 AES-GCM 保险库中，主密钥保存在钥匙串，访问控制为 `WhenUnlockedThisDeviceOnly`。解密失败时应用会拒绝写入，以免覆盖现有凭据。

## 导入格式

现有格式（邮箱与链接直接相连）：

```text
person@example.comhttps://claude.ai/login?...--sessionkey--2026-08-20
```

推荐格式：

```text
person@example.com | https://claude.ai/login?... | sessionkey | 2026-08-20 09:30
```

可选追加状态、标签和备注：

```text
person@example.com | https://claude.ai/login?... | sessionkey | 2026-08-20 | 正常 | 主力,工作 | 日常账号
```

JSON：

```json
[
  {
    "email": "person@example.com",
    "login_link": "https://claude.ai/login?...",
    "session_key": "...",
    "registered_at": "2026-08-20 09:30",
    "status": "正常",
    "last_used": "2026-08-20 10:00",
    "tags": ["主力", "工作"],
    "note": "日常账号"
  }
]
```

解析流程是：识别 JSON 或逐行文本 → 识别格式 → 校验邮箱/链接/日期 → 预览有效项与逐行错误 → 按邮箱新增或更新。已有账号导入时，如果敏感字段为空，不会清除 Keychain 中的旧值。

## 安全策略

- 导出包含明文自动登录链接与 Session Key，适合分发与迁移，保存时会提供安全提示。
- 应用不记录敏感字段日志，不把凭据放入 UserDefaults 或 SQLite。
- 删除账号时，同时删除 SQLite 元数据和对应 Keychain 项。
- 复制敏感值后，系统剪贴板仍可能被其他应用读取，使用后建议手动覆盖剪贴板。
- 本地威胁模型仍依赖 macOS 登录密码、FileVault 和设备物理安全；建议启用 FileVault。

## 运行与构建

测试：

```bash
./scripts/test.sh
```

当前 Command Line Tools 的 Testing 宏位于专用插件目录；测试脚本会显式加载该插件，并设置与 SDK 匹配的运行库路径。

开发运行：

```bash
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache" \
swift run --disable-sandbox ClaudeAccountManager
```

打包 `.app`：

```bash
MACOS_SDK_OVERRIDE=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
BUILD_ARCHS=arm64 \
./scripts/build-macos-app.sh
```

产物位于 `dist/Claude Account Manager.app`，脚本会进行本地 ad-hoc 签名。正式分发给其他 Mac 时，应使用 Apple Developer ID 签名并公证。

## 代码结构

```text
Sources/ClaudeAccountManager/
├── App/            应用入口与菜单命令
├── Data/           SQLite 与 Keychain
├── Domain/         数据模型、状态、筛选和排序
├── ImportExport/   文本/JSON 解析与 CSV 导出
├── Store/          界面状态与业务编排
├── Support/        日期格式等公共能力
└── UI/             三栏界面、表格、详情和导入导出 sheet
```

当前实现刻意不包含网页登录自动化、cookie 注入或账号状态探测。这些行为既不在需求内，也会显著增加凭据暴露和网站兼容风险。
