---
name: Claude Account Manager
description: 高信息密度、默认保护凭据的原生 macOS 账号管理工具
---

# Design System: Claude Account Manager

## Overview

**Creative North Star: "原生操作台账"**

Claude Account Manager 是一个 Operate 模式的原生 macOS 工具：界面像一份清楚、可靠、可以快速扫读的本地台账。视觉表达服从账号定位、比较、筛选与编辑，依赖用户熟悉的 `NavigationSplitView`、`Table`、`Form`、sheet、toolbar 和原生 sidebar selection，不建立自定义网页式组件外观。

系统保持高信息密度和低动效。注册时间在中间表格和右侧详情中都是一级信息；状态以文字、SF Symbol 和系统语义色共同表达；敏感字段默认隐藏，并以钥匙串保存状态而不是明文内容作为常态反馈。所有表面随 macOS 浅色、深色、高对比度与辅助功能设置自适应。

**Key Characteristics:**

- 原生三栏操作结构，列表扫描优先于装饰表达。
- San Francisco、SF Symbols、系统控件和动态语义色构成完整视觉语言。
- teal 只承担交互 tint；状态与风险反馈保留各自的系统语义色。
- 日期与计数使用等宽数字，保证密集列和概览数字稳定对齐。
- 凭据默认不可见，涉及明文导出的风险必须在界面中显式呈现。

## Colors

颜色全部来自 SwiftUI 与 AppKit 的动态系统语义，不固定为 hex；这是浅色、深色和辅助功能自适应的必要条件。

### Primary

- **交互青色（System Teal）：** 应用根视图通过 `.tint(.teal)` 统一交互强调，作用于原生按钮、选中状态和“使用中”等可操作语义。

### Secondary

- **状态绿色（System Green）：** “正常”、成功与可安全继续的反馈。
- **状态橙色（System Orange）：** “受限”、导入跳过项和明文凭据风险提醒。
- **状态红色（System Red）：** “失效”、解析错误与破坏性操作。
- **状态蓝色（System Blue）：** “待验证”状态。

### Neutral

- **主要标签色（SwiftUI `.primary`）：** 邮箱、有效日期、备注和其他主要内容。
- **次要标签色（SwiftUI `.secondary`）：** 计数、说明、空值、辅助文案和未选中图标。
- **系统栏材质（SwiftUI `.bar`）：** 表格上方筛选栏的背景层。
- **系统文本背景与分隔色（AppKit `textBackgroundColor` / `separatorColor`）：** 批量导入编辑器的可编辑表面与边界。

### Named Rules

**The 语义适配 Rule.** 不把动态系统颜色冻结为自定义 RGB、hex 或浅色模式快照；新增界面继续使用 SwiftUI 语义角色。

**The 状态三重编码 Rule.** 每个账号状态必须同时提供可读文字、SF Symbol 和颜色，颜色不能成为唯一信息载体。

**The 单一交互强调 Rule.** teal 用于交互 tint，不取代绿色、橙色、红色和蓝色的状态含义。

## Typography

**Display Font:** San Francisco（macOS 系统字体）  
**Body Font:** San Francisco（macOS 系统字体）  
**Label/Mono Font:** San Francisco；导入原文使用系统等宽设计，日期与计数使用等宽数字特性。

**Character:** 字体层级由 SwiftUI 动态文字样式而非固定字号构成，整体紧凑、直接、可扫描。视觉层级主要来自系统字号角色、字重和前景语义，而不是大尺寸标题或品牌字体。

### Hierarchy

- **Title（`.title2.weight(.semibold)`）：** 添加、导入和导出 sheet 的标题。
- **Headline（`.headline`）：** 详情邮箱、导入输入区标题和预览区标题。
- **Body（系统默认 `.body`）：** 表格主值、表单控件、按钮和主要说明。
- **Label（`.caption` / `.caption.weight(.medium)`）：** 状态胶囊、备注摘要、格式帮助、计数和安全提示；状态文字使用中等字重。
- **Monospaced Data（`.monospacedDigit()`）：** 注册时间、最后使用、创建时间、账号计数与导入计数；只改变数字宽度，不改变系统字体家族。
- **Raw Import Text（`.system(.body, design: .monospaced)`）：** 用户粘贴的批量导入原文，帮助识别分隔符和字段边界。

### Named Rules

**The 系统字号 Rule.** 不为常规界面发明固定字号；使用 SwiftUI 动态文字样式和系统字重，让 macOS 与辅助功能决定最终度量。

**The 稳定数字 Rule.** 可纵向比较的日期和计数始终使用等宽数字，避免内容变化导致列内跳动。

## Layout

应用采用 balanced 三栏 `NavigationSplitView`。窗口默认尺寸为 1320 × 780 pt，最小尺寸为 980 × 620 pt。左侧筛选栏宽度为最小 190、理想 220、最大 280 pt；中间账号表格为最小 560、理想 720 pt；右侧详情为最小 320、理想 390、最大 520 pt。窗口收窄时由系统分栏行为管理可见性和压缩，不另造网页断点。

左栏用原生 sidebar list 组织“账号”“状态”“概览”；中栏先放紧凑筛选栏，再放高密度 `Table`；右栏在查看态使用 grouped `Form`，在编辑态复用同一套账号表单。注册时间列保持在状态之后、最后使用之前，不能下沉到详情或二级展开中。

中间表格的固定与弹性列均来自实现：当前账号标记 28 pt，邮箱 160–230 pt，状态 74 pt，注册时间与最后使用各至少 116 pt，标签至少 80 pt。筛选栏水平内边距 12 pt、垂直内边距 8 pt；表格单元内容保持紧凑，说明信息最多一行。

添加 sheet 为 620 × 740 pt，批量导入 sheet 为 820 × 620 pt，导出 sheet 宽 560 pt。批量导入用 `HSplitView` 并排呈现原文与预览，确保写入前可同时检查有效项和错误。

**The 注册时间一级信息 Rule.** 任何账号列表变体都必须在首屏表格中保留注册时间，并维持可排序、可筛选和可比较的阅读条件。

**The 原生三栏 Rule.** 新增全局筛选放左栏，账号集合操作放中栏，单个账号查看与编辑放右栏；sheet 只承载添加、批量导入和导出等有明确开始与结束的任务。

## Elevation & Depth

系统在常驻界面中保持平面化，不定义自有阴影。深度由 macOS 原生窗口、sheet、sidebar selection、`.bar` 筛选栏、`Divider`、grouped `Form`、`GroupBox` 与系统控件层级表达；这些材料会自动适配浅色和深色外观。

**The 原生层级 Rule.** 常驻内容不通过自绘阴影、玻璃模糊或漂浮大卡片制造层次；需要临时层级时使用系统 sheet、alert 或选择反馈。

## Shapes

形状以系统控件默认轮廓为主，不覆盖按钮、输入框、Picker、Toggle、Table、List、Form 或 sheet 的原生圆角。自定义形状只出现在两个紧凑信息标记和一个文本编辑表面：状态与标签使用 `Capsule`，水平内边距 7 pt、垂直内边距 3 pt；批量导入文本编辑器使用 6 pt 圆角矩形，并配系统分隔色描边。

**The 少量自定义形状 Rule.** 只有需要在密集内容中形成独立视觉单元的短标签使用胶囊；普通分区和字段继续依赖原生容器。

## Components

### Navigation

- **Sidebar：** `.listStyle(.sidebar)` 与原生 selection；每行由 18 pt 对齐槽中的 SF Symbol、文字和等宽计数组成，状态筛选沿用状态色。
- **Toolbar：** 系统 primary-action toolbar 放置添加、批量导入、导出和删除；操作使用 `Label` + SF Symbol，并提供 help、禁用态与菜单快捷键。
- **Search：** toolbar placement 的原生 `.searchable`，搜索邮箱、备注和标签。

### Table & Filter Bar

- **Filter Bar：** `.bar` 背景上放注册时间范围 Picker、排序 Picker 与右对齐结果计数；使用原生 Picker，不自绘下拉菜单。
- **Account Table：** 原生 `Table` + selection；同一视线展示当前标记、邮箱与一行备注、状态、注册时间、最后使用和标签。
- **Empty State：** 原生 `ContentUnavailableView` 区分“还没有账号”和“没有匹配结果”，并提供添加、导入或清除筛选的就地动作。

### Status Badge

- **Style：** `Label` 同时显示状态文字与 SF Symbol；`.caption.weight(.medium)`，前景使用状态语义色，同色 12% 透明背景置于胶囊内。
- **Spacing：** 水平 7 pt、垂直 3 pt。
- **Accessibility：** 明确朗读“状态：状态名”，不依赖图标或颜色推断。

### Forms & Fields

- **Style：** 详情查看与账号编辑均使用 `.formStyle(.grouped)`，通过 `Section` 和 `LabeledContent` 组织信息。
- **Sensitive Fields：** 自动登录链接和 Session Key 默认使用 `SecureField`；无边框眼睛按钮显式切换显示与隐藏，并带 help 和 accessibility label。
- **Secret Presence Row：** 查看态只显示“未保存”或“已安全保存”，提供无边框复制按钮，不直接陈列凭据。
- **Dates and Status：** 使用原生 `DatePicker` 与 `Picker`；状态 Picker 继续以文字和 SF Symbol 呈现。

### Tags

- **Style：** 标签为次要语义色 12% 透明背景的胶囊，`.caption` 字号，水平 7 pt、垂直 3 pt。
- **Layout：** 右侧详情中的标签使用 6 pt 间距自动换行；表格中则压缩成单行“ · ”分隔文本。

### Sheets, Alerts & Feedback

- **Add：** 标题区、分隔线、复用编辑表单与底部取消/默认动作。
- **Import：** 左侧等宽文本输入、右侧实时预览；有效项、错误、计数与完成消息都使用明确文字和系统图标。
- **Export：** 原生 `GroupBox` 汇总导出内容；敏感字段默认关闭，开启后显示橙色风险提示并要求再次确认。
- **Destructive Feedback：** 删除通过系统 alert 确认并明确说明数据库和钥匙串都会删除；错误通过系统 alert 呈现。

## Do's and Don'ts

### Do:

- **Do** 保持原生 macOS `NavigationSplitView`、`Table`、`Form`、sheet、toolbar、sidebar selection 和系统反馈。
- **Do** 把注册时间保留为表格一级列，并对日期与计数使用等宽数字。
- **Do** 用 teal 作为交互 tint，用动态系统语义色表达状态、风险和破坏性操作。
- **Do** 让所有状态同时具备文字、SF Symbol 和颜色，并提供可理解的辅助功能标签。
- **Do** 默认隐藏 Keychain 敏感字段；查看态优先显示保存状态，明文导出必须显式确认风险。
- **Do** 依赖系统控件、材质、选择和 sheet 完成浅深色与辅助功能适配。

### Don't:

- **Don't** 把界面改造成网页式仪表盘、营销大卡片、玻璃拟态或装饰性浮层。
- **Don't** 用自定义字体、固定 hex 色或手工模拟的系统控件替换 San Francisco、动态语义色与原生组件。
- **Don't** 只用颜色表达账号状态，或把注册时间隐藏到详情、tooltip 或展开面板。
- **Don't** 默认显示自动登录链接、Session Key，或在无二次确认时导出明文凭据。
- **Don't** 添加持续、弹跳或装饰性动效；保留系统 sheet、选择和状态过渡，并尊重 Reduce Motion。
