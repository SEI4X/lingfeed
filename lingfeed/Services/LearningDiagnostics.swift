import Foundation
import OSLog

enum LearningDiagnostics {
    static let logger = Logger(subsystem: "com.lexmashkov.lingfeed", category: "Learning")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        print("[Learning] \(message)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        print("[Learning][Error] \(message)")
    }
}
