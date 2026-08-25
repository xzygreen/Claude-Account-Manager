# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Stack

原生 SwiftUI（用户明确优先），SQLite 保存可检索元数据，macOS Keychain 保存敏感信息。

## Users

主要用户是需要在一台 Mac 上整理多个 Claude 个人网页账号的个人用户。核心任务是离线维护账号清单，快速按注册时间、状态、标签和最后使用时间定位账号。

## Product Purpose

统一管理多个 claude.ai 个人网页账号。应用不调用 Claude API，不自动联网获取账号信息；数据仅保存在本机。

## Positioning

围绕“注册时间清晰可见”和“敏感凭据与可检索元数据分离存储”设计的轻量原生 Mac 工具。

## Operating Context

用户会批量粘贴现有的 `邮箱自动登录链接--sessionkey--注册时间` 文本，也可能使用 `|` 分隔或 JSON。日常工作以搜索、筛选、排序、标记当前账号和更新状态为主。

## Capabilities and Constraints

- 账号增删改查、批量导入、搜索、筛选、排序、标签、备注。
- 字段包括 email、login_link、session_key、registered_at、status、last_used、tags、note、created_at。
- 支持正常、受限、失效、待验证四种手动状态。
- 支持以 `mail|邮箱自动登录链接|sessionkey|注册时间` 竖线管道格式导出为文本文件。
- 不实现账号自动探测、API 调用、云同步或浏览器自动化。
- 最低支持 macOS 14。

## Product Principles

- 注册时间是列表中的一级信息，不隐藏在详情中。
- 默认保护凭据，敏感字段不进入 SQLite、日志或普通导出。
- 批量操作先预览结果与错误，再写入本地数据。
- 优先使用 macOS 熟悉的表格、侧边栏、菜单、快捷键和系统反馈。
- 离线状态是正常工作状态，不是降级模式。

## Accessibility & Inclusion

使用系统语义色、SF Symbols、键盘快捷键和原生控件；状态同时使用文字、图标和颜色表达，支持浅色/深色及系统辅助功能。
