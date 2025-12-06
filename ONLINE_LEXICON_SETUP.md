# 词库集成指南

## 当前状态

**项目已完全使用本地 rime-ice 词库，不再依赖任何在线 API 服务。**

所有词库功能都通过 `LocalLexiconService` 从本地 SQLite 数据库提供，无需网络连接，响应速度快，隐私安全。

## 词库来源

### rime-ice（雾凇拼音）

项目使用 **rime-ice** 作为主要词库来源。rime-ice 是一个高质量的简体中文词库配置项目，整合了多种权威词库，经过人工校对。

**特点：**
- 高质量词库，经过人工校对
- 词汇丰富，包含常用词、专业术语、网络用语等
- 持续更新维护
- 标准 Rime 格式，兼容性好

## 词库文件

词库以 SQLite 格式存储在：
```
WTRimeKeyboard/Resources/rime_lexicon.sqlite
```

该文件通过 `AppGroupBootstrapper` 自动同步到 App Group 共享目录，供键盘扩展使用。

## 更新词库

### 使用 rime-ice 转换工具

运行转换脚本生成新的词库：

```bash
cd Tools
python3 download_and_convert_rime_ice.py
```

脚本会自动：
1. 从 GitHub 下载 rime-ice 最新版本
2. 提取所有词库文件（dict.yaml）
3. 合并并去重
4. 转换为 SQLite 格式
5. 保存到项目目录

### 使用本地已下载的文件

如果您已经手动下载了 rime-ice：

```bash
cd Tools
python3 download_and_convert_rime_ice.py /path/to/rime-ice
```

## 代码结构

- `LocalLexiconService.swift`: 本地 SQLite 词库服务实现
- `OnlineLexiconService.swift`: 已弃用，保留仅用于向后兼容
- `AppGroupBootstrapper.swift`: 负责词库文件的同步和初始化

## 使用方式

在 `KeyboardViewController` 中，词库服务会自动初始化：

```swift
private let lexiconService: LocalLexiconService? = LocalLexiconService()
```

词库查询通过 `RimeNativeBridge` 协议进行：

```swift
let candidates = lexiconService?.search(for: "nihao", limit: 8) ?? []
```

## 注意事项

1. **文件大小**：rime-ice 词库较大，SQLite 文件可能达到几十 MB
2. **构建时间**：首次转换可能需要几分钟时间
3. **内存使用**：转换过程中会占用较多内存
4. **网络要求**：转换工具需要能够访问 GitHub（仅转换时需要）

## 故障排除

### 问题：词库查询返回空结果

**解决方案：**
- 检查 SQLite 文件是否已正确添加到 Xcode 项目
- 确认 `AppGroupBootstrapper.installSharedLexiconIfNeeded()` 已调用
- 检查 App Group 共享目录中是否存在词库文件

### 问题：词库文件找不到

**解决方案：**
- 确认 SQLite 文件在 `WTRimeKeyboard/Resources/` 目录下
- 检查文件是否已添加到 Xcode 项目的 Target 中
- 查看控制台日志中的错误信息

## 相关链接

- rime-ice GitHub: https://github.com/iDvel/rime-ice
- Rime 输入法官网: https://rime.im/
- 项目词库转换工具: `Tools/convert_rime_dict.swift`
- rime-ice 集成指南: `RIME_ICE_SETUP.md`

## 历史说明

**已移除的功能：**
- 百度 API 支持（NLP、翻译等）
- 腾讯云 NLP API 支持
- 所有在线词库服务

这些功能已被本地 rime-ice 词库完全替代，提供更好的性能、隐私和可靠性。
