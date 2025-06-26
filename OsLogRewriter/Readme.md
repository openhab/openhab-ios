# Tool to transforms all os_log patterns from the openHAB iOS codebase to the new logger.debug/info/error format with clean Swift string interpolation syntax

## 📋 Build and run the executable 

'swift run OsLogRewriter <inputFile.swift> > <outputFile.swift>'

'find ./Sources -name "*.swift" -exec swift run OsLogRewriter {} \; > temp.swift && mv temp.swift {}'

## 📋 How to Run Tests:

    ### Run all tests (simple)
    swift test
    
# Features

   1. Parameter handling - parses all arguments after the format string
   2. Format specifier support - Handles multiple format patterns: %{public}@, %{PUBLIC}@, %@, %d, %ld, %s  
   3. Severity mapping - Correctly maps type: .debug/.info/.error/.fault to logger methods
   4. String interpolation - Properly converts format strings with arguments to Swift string interpolation
   5. Multi-line format preservation - Complex multi-line os_log calls handled correctly
   6. Trivia Cleaning
   7. Smart indentation
