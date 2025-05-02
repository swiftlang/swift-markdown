/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A location in a source file.
public struct SourceLocation: Hashable, CustomStringConvertible, Comparable, Sendable {
    public static func < (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        if lhs.line < rhs.line {
            return true
        } else if lhs.line == rhs.line {
            return lhs.column < rhs.column
        } else {
            return false
        }
    }

    /// The line number of the location.
    public var line: Int

    /// The number of bytes in UTF-8 encoding from the start of the line to the character at this source location.
    public var column: Int

    /// The source file for which this location applies, if it came from an accessible location.
    public var source: URL?

    /// Create a source location with line, column, and optional source to which the location applies.
    ///
    /// - parameter line: The line number of the location, starting with 1.
    /// - parameter column: The column of the location, starting with 1.
    /// - parameter source: The URL in which the location resides, or `nil` if there is not a specific
    ///   file or resource that needs to be identified.
    public init(line: Int, column: Int, source: URL?) {
        self.line = line
        self.column = column
        self.source = source
    }

    public var description: String {
        let path = source.map {
            $0.path.isEmpty
                ? ""
                : "\($0.path):"
        } ?? ""
        return "\(path)\(line):\(column)"
    }
}

extension Range {
    /// Widen this range to contain another.
    mutating func widen(toFit other: Self) {
        self = Swift.min(self.lowerBound, other.lowerBound)..<Swift.max(self.upperBound, other.upperBound)
    }
}

/// A range in a source file.
public typealias SourceRange = Range<SourceLocation>

extension SourceRange {
    @available(*, deprecated, message: "Use lowerBound..<upperBound initialization")
    public init(start: Bound, end: Bound) {
        self = start..<end
    }

    @available(*, deprecated, renamed: "lowerBound")
    public var start: Bound {
        get {
            return lowerBound
        }
        set {
            self = newValue..<upperBound
        }
    }

    @available(*, deprecated, renamed: "upperBound")
    public var end: Bound {
        get {
            return upperBound
        }
        set {
            self = lowerBound..<newValue
        }
    }

    /// A textual description for use in diagnostics.
    public func diagnosticDescription(includePath: Bool = true) -> String {
        let path = includePath ? lowerBound.source?.path ?? "" : ""
        var result = ""
        if !path.isEmpty {
            result += "\(path):"
        }
        result += "\(lowerBound)"
        if lowerBound != upperBound {
            result += "-\(upperBound)"
        }
        return result
    }
}
