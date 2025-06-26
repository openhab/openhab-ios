import Foundation
import OsLogRewriterLib

let path = CommandLine.arguments.dropFirst().first!

do {
    let result = try rewriteOsLogCallsInFile(at: path)
    print(result)
} catch {
    fputs("❌ Error: \(error)\n", stderr)
    exit(1)
}
