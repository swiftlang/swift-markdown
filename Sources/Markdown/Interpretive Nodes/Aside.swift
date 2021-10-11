/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An auxiliary aside element interpreted from a block quote.
///
/// Asides are written as a block quote starting with a special plain-text tag,
/// such as `note:` or `tip:`:
///
/// ```markdown
/// > Tip: This is a `tip` aside.
/// > It may have a presentation similar to a block quote, but with a
/// > different meaning, as it doesn't quote speech.
/// ```
public struct Aside {
    /// The kind of aside.
    public enum Kind: String, CaseIterable {
        /// A "note" aside.
        case note = "Note"

        /// A "tip" aside.
        case tip = "Tip"

        /// An "important" aside.
        case important = "Important"

        /// An "experiment" aside.
        case experiment = "Experiment"

        /// A "warning" aside.
        case warning = "Warning"

        /// An "attention" aside.
        case attention = "Attention"

        /// An "author" aside.
        case author = "Author"

        /// An "authors" aside.
        case authors = "Authors"

        /// A "bug" aside.
        case bug = "Bug"

        /// A "complexity" aside.
        case complexity = "Complexity"

        /// A "copyright" aside.
        case copyright = "Copyright"

        /// A "date" aside.
        case date = "Date"

        /// An "invariant" aside.
        case invariant = "Invariant"

        /// A "mutatingVariant" aside.
        case mutatingVariant = "MutatingVariant"

        /// A "nonMutatingVariant" aside.
        case nonMutatingVariant = "NonMutatingVariant"

        /// A "postcondition" aside.
        case postcondition = "Postcondition"

        /// A "precondition" aside.
        case precondition = "Precondition"

        /// A "remark" aside.
        case remark = "Remark"

        /// A "requires" aside.
        case requires = "Requires"

        /// A "since" aside.
        case since = "Since"

        /// A "todo" aside.
        case todo = "ToDo"

        /// A "version" aside.
        case version = "Version"

        /// A "throws" aside.
        case `throws` = "Throws"

        public init?(rawValue: String) {
            // Allow lowercase aside prefixes to match.
            let casesAndLowercasedRawValues = Kind.allCases.map { (kind: $0, rawValue: $0.rawValue.lowercased() )}
            guard let matchingCaseAndRawValue = casesAndLowercasedRawValues.first(where: { $0.rawValue == rawValue.lowercased() }) else {
                return nil
            }
            self = matchingCaseAndRawValue.kind
        }
    }

    /// The kind of aside interpreted from the initial text of the ``BlockQuote``.
    public var kind: Kind

    /// The block elements of the aside taken from the ``BlockQuote``,
    /// excluding the initial text tag.
    public var content: [BlockMarkup]

    /// Create an aside from a block quote.
    public init(_ blockQuote: BlockQuote) {
        // Try to find an initial `tag:` text at the beginning.
        guard var initialText = blockQuote.child(through: [
            (0, Paragraph.self),
            (0, Text.self),
        ]) as? Text,
        let firstColonIndex = initialText.string.firstIndex(where: { $0 == ":" }),
        let kind = Kind(rawValue: String(initialText.string[initialText.string.startIndex..<firstColonIndex])) else {
            // Otherwise, default to a note aside.
            self.kind = .note
            self.content = Array(blockQuote.blockChildren)
            return
        }
        self.kind = kind

        // Trim off the aside tag prefix.
        let trimmedText = initialText.string[initialText.string.index(after: firstColonIndex)...].drop {
            $0 == " " || $0 == "\t"
        }
        initialText.string = String(trimmedText)

        let newBlockQuote = initialText.parent!.parent! as! BlockQuote
        self.content = Array(newBlockQuote.blockChildren)
    }
}
