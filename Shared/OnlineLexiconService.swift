import Foundation

/// 在线词库服务 - 支持多种后端
final class OnlineLexiconService: RimeNativeBridge {
    private enum ServiceType {
        case customAPI(baseURL: String, apiKey: String?)
        case baiduNLP(apiKey: String, secretKey: String)
        case tencentNLP(secretId: String, secretKey: String)
    }
    
    private let serviceType: ServiceType
    private let session = URLSession.shared
    private var cache: [String: [String]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.wtkeyboard.online.cache")
    private let maxCacheSize = 1000
    
    private init(serviceType: ServiceType) {
        self.serviceType = serviceType
    }
    
    // MARK: - 便捷初始化方法
    
    /// 使用自定义 API
    static func customAPI(baseURL: String, apiKey: String? = nil) -> OnlineLexiconService {
        OnlineLexiconService(serviceType: .customAPI(baseURL: baseURL, apiKey: apiKey))
    }
    
    /// 使用百度 NLP API（需要申请）
    static func baiduNLP(apiKey: String, secretKey: String) -> OnlineLexiconService {
        OnlineLexiconService(serviceType: .baiduNLP(apiKey: apiKey, secretKey: secretKey))
    }
    
    /// 使用腾讯云 NLP API（需要申请）
    static func tencentNLP(secretId: String, secretKey: String) -> OnlineLexiconService {
        OnlineLexiconService(serviceType: .tencentNLP(secretId: secretId, secretKey: secretKey))
    }
    
    // MARK: - RimeNativeBridge
    
    func search(for input: String, limit: Int) -> [String] {
        guard !input.isEmpty else { return [] }
        
        // 检查缓存
        if let cached = cacheQueue.sync(execute: { cache[input] }) {
            return Array(cached.prefix(limit))
        }
        
        // 同步请求
        let semaphore = DispatchSemaphore(value: 0)
        var results: [String] = []
        var hasError = false
        
        performSearch(input: input, limit: limit) { result in
            switch result {
            case .success(let candidates):
                results = candidates
                // 更新缓存
                self.cacheQueue.async {
                    if self.cache.count >= self.maxCacheSize {
                        // 简单的 LRU：删除最旧的条目
                        let keyToRemove = self.cache.keys.first
                        if let key = keyToRemove {
                            self.cache.removeValue(forKey: key)
                        }
                    }
                    self.cache[input] = candidates
                }
            case .failure:
                hasError = true
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 1.5) // 1.5秒超时
        
        return hasError ? [] : Array(results.prefix(limit))
    }
    
    // MARK: - 私有方法
    
    private func performSearch(input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        switch serviceType {
        case .customAPI(let baseURL, let apiKey):
            searchCustomAPI(baseURL: baseURL, apiKey: apiKey, input: input, limit: limit, completion: completion)
        case .baiduNLP(let apiKey, let secretKey):
            searchBaiduNLP(apiKey: apiKey, secretKey: secretKey, input: input, limit: limit, completion: completion)
        case .tencentNLP(let secretId, let secretKey):
            searchTencentNLP(secretId: secretId, secretKey: secretKey, input: input, limit: limit, completion: completion)
        }
    }
    
    private func searchCustomAPI(baseURL: String, apiKey: String?, input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        guard var urlComponents = URLComponents(string: baseURL) else {
            completion(.failure(NSError(domain: "OnlineLexiconService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var queryItems = [
            URLQueryItem(name: "q", value: input),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let apiKey = apiKey {
            queryItems.append(URLQueryItem(name: "key", value: apiKey))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "OnlineLexiconService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "OnlineLexiconService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "OnlineLexiconService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            
            do {
                // 支持多种 JSON 格式
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                // 格式1: {"candidates": ["词1", "词2"]}
                if let candidates = json?["candidates"] as? [String] {
                    completion(.success(candidates))
                    return
                }
                
                // 格式2: {"data": ["词1", "词2"]}
                if let candidates = json?["data"] as? [String] {
                    completion(.success(candidates))
                    return
                }
                
                // 格式3: 直接是数组 ["词1", "词2"]
                if let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    completion(.success(array))
                    return
                }
                
                // 格式4: {"result": [{"word": "词1"}, {"word": "词2"}]}
                if let result = json?["result"] as? [[String: Any]] {
                    let candidates = result.compactMap { $0["word"] as? String }
                    completion(.success(candidates))
                    return
                }
                
                completion(.success([]))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func searchBaiduNLP(apiKey: String, secretKey: String, input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        // 百度 NLP API 实现
        // 需要先获取 access_token，然后调用相关 API
        // 这里只是示例框架
        completion(.success([]))
    }
    
    private func searchTencentNLP(secretId: String, secretKey: String, input: String, limit: Int, completion: @escaping (Result<[String], Error>) -> Void) {
        // 腾讯云 NLP API 实现
        // 需要签名和调用相关 API
        // 这里只是示例框架
        completion(.success([]))
    }
}

