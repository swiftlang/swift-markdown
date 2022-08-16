//! Example on how to parse Markdown from file
import Markdown
import Foundation

// MARK: Hide
let tempDirecotry = FileManager.default.temporaryDirectory
let testFile = tempDirecotry.appendingPathComponent("Test.md")
let testData = """
1. Hello
2. World
""".data(using: .utf8)!
try testData.write(to: testFile)
// MARK: Show
guard let source = try? String(contentsOf: testFile) else {
    fatalError("Unable to get the contents of the Test.md file")
}
let everythingDocument = Document(parsing: source)
let document = Document(parsing: source)
print(document.debugDescription(options: [.printEverything]))
