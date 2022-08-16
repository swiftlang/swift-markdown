//! Define a MarkupCounter struct to count the Text and UnorderedList count of the Markup Object 
import Markdown
struct MarkupCounter: MarkupWalker {
    private var textCount = 0
    private var unorderedListCount = 0
    private var unorderedListItemsCount = 0

    // MARK: Hide
    var result: String {
        """
        The Markup has:
        \(textCount) Text elements
        \(unorderedListCount) UnorderedList elements with a total of \(unorderedListItemsCount) items
        """
    }
    // MARK: Show

    mutating func visitText(_ text: Text) -> () {
        print("Visiting Text Element: \(text.string)\n")
        textCount += 1
    }
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        print("Visiting UnorderedList Element: \(unorderedList.format())\n")
        unorderedListCount += 1
        unorderedListItemsCount += unorderedList.childCount
    }
}

let source = """
Hello

- Item 1
- Item 2

world

- Item 3
"""
let document = Document(parsing: source)

var dumper = MarkupCounter()
dumper.visit(document)
print(dumper.result)
