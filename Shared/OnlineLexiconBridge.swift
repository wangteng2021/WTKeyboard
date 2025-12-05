import Foundation

/// 在线词库桥接器协议
protocol OnlineLexiconProvider {
    func search(for input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void)
}

/// 在线词库桥接器实现
final class OnlineLexiconBridge: RimeNativeBridge {
    private let provider: OnlineLexiconProvider
    private let cache: [String: [String]]
    private let cacheQueue = DispatchQueue(label: "com.wtkeyboard.online.cache", qos: .utility)
    private var pendingRequests: [String: DispatchGroup] = [:]
    private let requestQueue = DispatchQueue(label: "com.wtkeyboard.online.requests", qos: .userInitiated)
    
    init(provider: OnlineLexiconProvider) {
        self.provider = provider
        self.cache = [:]
    }
    
    func search(for input: String, limit: Int) -> [String] {
        guard !input.isEmpty else { return [] }
        
        // 先检查缓存
        if let cached = cacheQueue.sync(execute: { cache[input] }) {
            return Array(cached.prefix(limit))
        }
        
        // 同步请求（用于兼容 RimeNativeBridge 协议）
        let semaphore = DispatchSemaphore(value: 0)
        var results: [String] = []
        var requestError: Error?
        
        provider.search(for: input, limit: limit) { result in
            switch result {
            case .success(let candidates):
                results = candidates
            case .failure(let error):
                requestError = error
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 2.0) // 2秒超时
        
        if let error = requestError {
            #if DEBUG
            print("[OnlineLexiconBridge] Request failed: \(error)")
            #endif
            return []
        }
        
        return Array(results.prefix(limit))
    }
}

/// 示例：百度翻译 API 词库提供者
final class BaiduTranslationProvider: OnlineLexiconProvider {
    private let apiKey: String
    private let appId: String
    private let session = URLSession.shared
    
    init(apiKey: String, appId: String) {
        self.apiKey = apiKey
        self.appId = appId
    }
    
    func search(for input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        // 这里可以实现百度翻译 API 调用
        // 注意：百度翻译主要用于翻译，不是专门的输入法词库
        completion(.success([]))
    }
}

/// 示例：自定义 API 词库提供者
final class CustomAPIProvider: OnlineLexiconProvider {
    private let baseURL: String
    private let apiKey: String?
    private let session = URLSession.shared
    
    init(baseURL: String, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }
    
    func search(for input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        guard var urlComponents = URLComponents(string: baseURL) else {
            completion(.failure(NSError(domain: "CustomAPIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var queryItems = [
            URLQueryItem(name: "input", value: input),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let apiKey = apiKey {
            queryItems.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "CustomAPIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "CustomAPIProvider", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            
            do {
                // 假设 API 返回格式: {"candidates": ["词1", "词2", ...]}
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let candidates = json?["candidates"] as? [String] ?? []
                completion(.success(candidates))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

/// 示例：搜狗输入法 API（如果可用）
final class SougouInputProvider: OnlineLexiconProvider {
    private let session = URLSession.shared
    
    func search(for input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        // 注意：搜狗输入法没有公开 API，这里只是示例结构
        // 实际使用时需要找到可用的 API 端点
        completion(.success([]))
    }
}

