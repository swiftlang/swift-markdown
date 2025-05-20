/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A textual replacement.
public struct Replacement: CustomStringConvertible, CustomDebugStringConvertible, Sendable {
    /// The range of source text to replace.
    public var range: SourceRange

    /// The text to substitute in the ``range``.
    public var replacementText: String

    /// Create a textual replacement.
    ///
    /// - parameter range: The range of the source text to replace.
    /// - parameter replacementText: The text to substitute in the range.
    public init(range: SourceRange, replacementText: String) {
      self.range = range
      self.replacementText = replacementText
    }

    public var description: String {
        return "\(range.diagnosticDescription()): fixit: \(replacementText)"
    }

    public var debugDescription: String {
        return description
    }
}
