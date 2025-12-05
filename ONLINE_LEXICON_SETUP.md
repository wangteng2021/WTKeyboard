# 在线词库集成指南

## 推荐方案

### 方案1: 自建 API 服务（推荐）

**优点：**
- 完全可控
- 可以自定义词库和算法
- 成本低（使用自己的服务器）

**实现步骤：**

1. **创建 API 服务**
   - 使用 Node.js/Python/Go 等创建简单的 HTTP API
   - API 格式：`GET /api/suggestions?q=拼音&limit=8`
   - 返回格式：`{"candidates": ["词1", "词2", ...]}`

2. **配置环境变量**
   ```swift
   // 在 Xcode Scheme 中设置环境变量
   LEXICON_API_URL = https://your-api.com/api/suggestions
   LEXICON_API_KEY = your-api-key (可选)
   ```

3. **代码已自动集成**
   - `OnlineLexiconService` 会自动使用环境变量中的 API URL

### 方案2: 使用百度 NLP API

**优点：**
- 官方服务，稳定可靠
- 支持多种 NLP 功能

**缺点：**
- 需要申请 API Key
- 可能有调用限制和费用

**申请地址：** https://ai.baidu.com/

### 方案3: 使用腾讯云 NLP API

**优点：**
- 企业级服务
- 功能丰富

**缺点：**
- 需要申请账号
- 可能有费用

**申请地址：** https://cloud.tencent.com/product/nlp

### 方案4: 使用开源词库 API

可以考虑使用一些开源的中文词库 API 服务，或者自己部署一个简单的服务。

## 快速开始

### 使用自定义 API

1. 在 `KeyboardViewController.createOnlineLexiconService()` 中配置你的 API URL
2. 或者通过环境变量设置：
   - `LEXICON_API_URL`: API 地址
   - `LEXICON_API_KEY`: API 密钥（可选）

### API 接口规范

**请求：**
```
GET /api/suggestions?q=拼音&limit=8
Headers:
  Accept: application/json
  Authorization: Bearer YOUR_API_KEY (可选)
```

**响应：**
```json
{
  "candidates": ["词1", "词2", "词3"]
}
```

或者简单数组格式：
```json
["词1", "词2", "词3"]
```

## 代码结构

- `OnlineLexiconService.swift`: 在线词库服务实现
- `OnlineLexiconBridge.swift`: 桥接器（可选，用于更复杂的场景）

## 注意事项

1. **网络权限**：确保键盘扩展有网络访问权限
2. **超时设置**：默认 1.5 秒超时，避免影响输入体验
3. **缓存机制**：已实现本地缓存，减少网络请求
4. **降级策略**：在线服务失败时，会自动降级到本地 SQLite 词库

## 测试

在 Xcode 中设置环境变量进行测试：
1. Edit Scheme → Run → Arguments → Environment Variables
2. 添加 `LEXICON_API_URL` 和 `LEXICON_API_KEY`

