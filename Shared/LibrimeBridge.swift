import Foundation
import Darwin

final class LibrimeBridge: RimeNativeBridge {
    struct Configuration {
        let libraryPath: String
        let searchSymbol: String
        let cleanupSymbol: String

        static let defaultLibraryName = "libRimeNativeBridge.dylib"

        static func autoDetect() -> Configuration? {
            let fileManager = FileManager.default
            var candidates: [String] = []
            if let frameworksPath = Bundle.main.privateFrameworksPath {
                candidates.append(URL(fileURLWithPath: frameworksPath).appendingPathComponent(defaultLibraryName).path)
            }
            let bundlePath = Bundle.main.bundlePath
            candidates.append(URL(fileURLWithPath: bundlePath).appendingPathComponent(defaultLibraryName).path)
            candidates.append("/usr/local/lib/" + defaultLibraryName)
            guard let path = candidates.first(where: { fileManager.fileExists(atPath: $0) }) else {
                return nil
            }
            return Configuration(libraryPath: path, searchSymbol: "rime_bridge_search", cleanupSymbol: "rime_bridge_free")
        }
    }

    private typealias SearchFunction = @convention(c) (UnsafePointer<CChar>, Int32, UnsafeMutablePointer<RimeCandidateBuffer>?) -> Int32
    private typealias CleanupFunction = @convention(c) (UnsafeMutablePointer<RimeCandidateBuffer>?) -> Void

    private let handle: UnsafeMutableRawPointer
    private let search: SearchFunction
    private let cleanup: CleanupFunction
    private let queue = DispatchQueue(label: "com.ddm.similar.librime", qos: .userInitiated)

    init?(configuration: Configuration? = Configuration.autoDetect()) {
        guard let configuration else { return nil }
        guard let handle = dlopen(configuration.libraryPath, RTLD_NOW) else {
            #if DEBUG
            print("[LibrimeBridge] Failed to open library at \(configuration.libraryPath)")
            #endif
            return nil
        }
        guard let rawSearch = dlsym(handle, configuration.searchSymbol) else {
            dlclose(handle)
            return nil
        }
        guard let rawCleanup = dlsym(handle, configuration.cleanupSymbol) else {
            dlclose(handle)
            return nil
        }
        self.handle = handle
        self.search = unsafeBitCast(rawSearch, to: SearchFunction.self)
        self.cleanup = unsafeBitCast(rawCleanup, to: CleanupFunction.self)
    }

    deinit {
        dlclose(handle)
    }

    func search(for input: String, limit: Int) -> [String] {
        guard !input.isEmpty else { return [] }
        return queue.sync {
            var buffer = RimeCandidateBuffer()
            let status = input.withCString { pointer -> Int32 in
                search(pointer, Int32(limit), &buffer)
            }
            guard status == 0 else {
                cleanup(&buffer)
                return []
            }
            let results = buffer.toCandidates()
            cleanup(&buffer)
            return results
        }
    }
}

private struct RimeCandidateBuffer {
    var count: Int32 = 0
    var items: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?

    fileprivate func toCandidates() -> [String] {
        guard let items, count > 0 else { return [] }
        var result: [String] = []
        for index in 0..<Int(count) {
            if let pointer = items[index] {
                result.append(String(cString: pointer))
            }
        }
        return result
    }
}
