import XCTest
@testable import OsLogRewriterLib

final class OsLogRewriterTests: XCTestCase {
    
    func testSimpleOsLogMessage() throws {
        let input = """
        import os.log
        
        func test() {
            os_log("Simple message")
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            logger.info("Simple message")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), 
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testOsLogWithSeverity() throws {
        let input = """
        import os.log
        
        func test() {
            os_log("Debug message", type: .debug)
            os_log("Info message", type: .info)
            os_log("Error message", type: .error)
            os_log("Fault message", type: .fault)
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            logger.debug("Debug message")
            logger.info("Info message")
            logger.error("Error message")
            logger.error("Fault message")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testOsLogWithFormatParameters() throws {
        let input = """
        import os.log
        
        func test() {
            let key = "testKey"
            let value = "testValue"
            os_log("Preference %{public}@ is %{public}@", key, value)
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            let key = "testKey"
            let value = "testValue"
            logger.info("Preference \\(key) is \\(value)")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testOsLogWithLogParameter() throws {
        let input = """
        import os.log
        
        func test() {
            os_log("Message with log param", log: .default, type: .debug)
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            logger.debug("Message with log param")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testOsLogWithStringInterpolationArguments() throws {
        let input = """
        import os.log
        
        func test() {
            let value = 42
            os_log("Value is %{public}@", "\\(value)")
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            let value = 42
            logger.info("Value is \\(value)")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testMultipleFormatSpecifiers() throws {
        let input = """
        import os.log
        
        func test() {
            os_log("User %{public}@ logged in from %{public}@ at %{public}@", username, ipAddress, timestamp)
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            logger.info("User \\(username) logged in from \\(ipAddress) at \\(timestamp)")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testDifferentFormatSpecifiers() throws {
        let input = """
        import os.log
        
        func test() {
            os_log("String: %{PUBLIC}@, Number: %d, Long: %ld", stringValue, intValue, longValue)
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            logger.info("String: \\(stringValue), Number: \\(intValue), Long: \\(longValue)")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testOpenHABStylePatterns() throws {
        let input = """
        import os.log
        
        func test() {
            os_log("Preference value %{PUBLIC}@ was \\"%{PUBLIC}@\\" but did not conform to %{PUBLIC}@. Replace with default value.", 
                   log: .default, type: .fault, key, "\\(preferenceValue)", "\\(T.self)")
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            logger.error("Preference value \\(key) was \\"\\(preferenceValue)\\" but did not conform to \\(T.self). Replace with default value.")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testNonOsLogCallsUnchanged() throws {
        let input = """
        import os.log
        
        func test() {
            print("This should not change")
            NSLog("This should not change")
            someOtherFunction("parameter")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      input.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    func testMixedOsLogAndOtherCalls() throws {
        let input = """
        import os.log
        
        func test() {
            print("Regular print")
            os_log("This gets transformed", type: .debug)
            NSLog("This stays the same")
        }
        """
        
        let expected = """
        import os.log
        
        func test() {
            print("Regular print")
            logger.debug("This gets transformed")
            NSLog("This stays the same")
        }
        """
        
        let result = try rewriteOsLogCalls(in: input)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines),
                      expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
