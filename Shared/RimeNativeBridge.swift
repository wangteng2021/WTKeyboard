import Foundation

protocol RimeNativeBridge {
    func search(for input: String, limit: Int) -> [String]
}
