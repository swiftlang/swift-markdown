/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
    /// Describes the different kinds of aside.
    public struct Kind: RawRepresentable, CaseIterable, Equatable {
        /// A "note" aside.
        public static let note = Kind(rawValue: "Note")!
        
        /// A "tip" aside.
        public static let tip = Kind(rawValue: "Tip")!
        
        /// An "important" aside.
        public static let important = Kind(rawValue: "Important")!
        
        /// An "experiment" aside.
        public static let experiment = Kind(rawValue: "Experiment")!
        
        /// A "warning" aside.
        public static let warning = Kind(rawValue: "Warning")!
        
        /// An "attention" aside.
        public static let attention = Kind(rawValue: "Attention")!
        
        /// An "author" aside.
        public static let author = Kind(rawValue: "Author")!
        
        /// An "authors" aside.
        public static let authors = Kind(rawValue: "Authors")!
        
        /// A "bug" aside.
        public static let bug = Kind(rawValue: "Bug")!
        
        /// A "complexity" aside.
        public static let complexity = Kind(rawValue: "Complexity")!
        
        /// A "copyright" aside.
        public static let copyright = Kind(rawValue: "Copyright")!
        
        /// A "date" aside.
        public static let date = Kind(rawValue: "Date")!
        
        /// An "invariant" aside.
        public static let invariant = Kind(rawValue: "Invariant")!
        
        /// A "mutatingVariant" aside.
        public static let mutatingVariant = Kind(rawValue: "MutatingVariant")!
        
        /// A "nonMutatingVariant" aside.
        public static let nonMutatingVariant = Kind(rawValue: "NonMutatingVariant")!
        
        /// A "postcondition" aside.
        public static let postcondition = Kind(rawValue: "Postcondition")!
        
        /// A "precondition" aside.
        public static let precondition = Kind(rawValue: "Precondition")!
        
        /// A "remark" aside.
        public static let remark = Kind(rawValue: "Remark")!
        
        /// A "requires" aside.
        public static let requires = Kind(rawValue: "Requires")!
        
        /// A "since" aside.
        public static let since = Kind(rawValue: "Since")!
        
        /// A "todo" aside.
        public static let todo = Kind(rawValue: "ToDo")!
        
        /// A "version" aside.
        public static let version = Kind(rawValue: "Version")!
        
        /// A "throws" aside.
        public static let `throws` = Kind(rawValue: "Throws")!
        
        /// A "seeAlso" aside.
        public static let seeAlso = Kind(rawValue: "SeeAlso")!
        
        /// A collection of preconfigured aside kinds.
        public static var allCases: [Aside.Kind] {
            [
                note,
                tip,
                important,
                experiment,
                warning,
                attention,
                author,
                authors,
                bug,
                complexity,
                copyright,
                date,
                invariant,
                mutatingVariant,
                nonMutatingVariant,
                postcondition,
                precondition,
                remark,
                requires,
                since,
                todo,
                version,
                `throws`,
                seeAlso,
            ]
        }
        
        /// The heading text to use when rendering this kind of aside.
        ///
        /// For multi-word asides this value may differ from the aside's ``rawValue``.
        /// For example, the ``seeAlso`` aside's `rawValue` is `"SeeAlso"` but its
        /// `displayName` is `"See Also"`.
        /// Likewise, ``nonMutatingVariant``'s `rawValue` is
        /// `"NonMutatingVariant"` and its `displayName` is `"Non-Mutating Variant"`.
        ///
        /// For simpler, single-word asides like ``bug``, the `displayName` and `rawValue` will
        /// be the same.
        public var displayName: String {
            switch self {
            case .seeAlso:
                return "See Also"
            case .nonMutatingVariant:
                return "Non-Mutating Variant"
            case .mutatingVariant:
                return "Mutating Variant"
            case .todo:
                return "To Do"
            default:
                return rawValue
            }
        }
        
        /// The underlying raw string value.
        public var rawValue: String
        
        /// Creates an aside kind with the specified raw value.
        /// - Parameter rawValue: The string the aside displays as its title.
        public init?(rawValue: String) {
            self.rawValue = rawValue
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
        let firstColonIndex = initialText.string.firstIndex(where: { $0 == ":" }) else {
            // Otherwise, default to a note aside.
            self.kind = .note
            self.content = Array(blockQuote.blockChildren)
            return
        }
        self.kind = Kind(rawValue: String(initialText.string[..<firstColonIndex]))!

        // Trim off the aside tag prefix.
        let trimmedText = initialText.string[initialText.string.index(after: firstColonIndex)...].drop {
            $0 == " " || $0 == "\t"
        }
        initialText.string = String(trimmedText)

        let newBlockQuote = initialText.parent!.parent! as! BlockQuote
        self.content = Array(newBlockQuote.blockChildren)
    }
}

extension BlockQuote {
    /// Conservatively checks the text of this block quote to see whether it can be parsed as an aside.
    ///
    /// Whereas ``Aside/init(_:)`` will use all the text before the first colon in the first line,
    /// or else return an ``Aside`` with a ``Aside/Kind-swift.struct`` of ``Aside/Kind/note``,
    /// this function will allow parsers to only parse an aside if there is a single-word aside
    /// marker in the first line, and otherwise fall back to a plain ``BlockQuote``.
    func isAside() -> Bool {
        guard let initialText = self.child(through: [
            (0, Paragraph.self),
            (0, Text.self),
        ]) as? Text,
              let firstColonIndex = initialText.string.firstIndex(where: { $0 == ":" }) else {
            return false
        }

        if let firstSpaceIndex = initialText.string.firstIndex(where: { $0 == " " }) {
            return firstSpaceIndex > firstColonIndex
        } else {
            return true
        }
    }
}
