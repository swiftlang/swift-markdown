/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An element with attribute text that wraps other block elements.
///
/// A block directive can be used to tag wrapped block elements or be a novel block element in itself.
/// The contents within may be more block directives or the other typical Markdown elements.
///
/// For example, a block directive could serve as a placeholder for a table of contents that can be rendered
/// and inlined later:
///
/// ```markdown
/// @TOC
///
/// # Title
/// ...
/// ```
///
/// A block directive could also add attribute data to the wrapped elements.
/// Contents inside parentheses `(...)` are considered *argument text*. There is
/// no particular mandatory format for argument text but a default `name: value` style
/// argument parser is included.
///
/// ```markdown
/// @Wrapped(paperStyle: shiny) {
///    - A
///    - B
/// }
/// ```
///
/// Block directives can be indented any amount.
///
/// ```markdown
/// @Outer {
///   @TwoSpaces {
///       @FourSpaces
///   }
/// }
/// ```
///
/// The indentation for the contents of a block directive are measured using
/// the first non-blank line. For example:
///
/// ```markdown
/// @Outer {
///     This line establishes indentation to be removed from these inner contents.
///     This line will line up with the last.
/// }
/// ```
///
/// The parser will see the following logical lines for the inner content,
/// adjusting source locations after the parse.
///
/// ```markdown
/// This line establishes indentation to be removed from these inner contents.
/// This line will line up with the last.
/// ```
public struct BlockDirective: BlockContainer {
    public var _data: _MarkupData

    init(_ raw: RawMarkup) throws {
        guard case .blockDirective = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: BlockDirective.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension BlockDirective {

    /// Create a block directive.
    ///
    /// - parameter name: The name of the directive.
    /// - parameter argumentText: The text to use when interpreting arguments to the directive.
    /// - parameter children: block child elements.
    init<Children: Sequence>(name: String,
                             argumentText: String? = nil,
                             children: Children) where Children.Element == BlockMarkup {
        let argumentSegments = argumentText?.split(separator: "\n",
                                                   maxSplits: .max,
                                                   omittingEmptySubsequences: false).map { lineText -> DirectiveArgumentText.LineSegment in
                                                    let untrimmedText = String(lineText)
                                                    return DirectiveArgumentText.LineSegment(untrimmedText: untrimmedText,
                                                                                             lineStartIndex: untrimmedText.startIndex,
                                                                                             range: nil)
                                                   } ?? []
        try! self.init(.blockDirective(name: name,
                                       nameLocation: nil,
                                       argumentText: DirectiveArgumentText(segments: argumentSegments),
                                       parsedRange: nil,
                                       children.map { $0.raw.markup }))
    }

    /// Create a block directive.
    ///
    /// - parameter name: The name of the directive.
    /// - parameter argumentText: The text to use when interpreting arguments to the directive.
    /// - parameter children: block child elements.
    init(name: String,
         argumentText: String? = nil,
         children: BlockMarkup...) {
        self.init(name: name, argumentText: argumentText, children: children)
    }

    /// The name of the directive.
    var name: String {
        get {
            guard case let .blockDirective(name, _, _) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")

            }
            return name
        }
        set {
            _data = _data.replacingSelf(.blockDirective(name: newValue,
                                                      nameLocation: nil,
                                                      argumentText: argumentText,
                                                      parsedRange: nil,
                                                      _data.raw.markup.copyChildren()))
        }
    }

    /// The source location from which the directive's name was parsed, if it
    /// was parsed from source.
    var nameLocation: SourceLocation? {
        guard case let .blockDirective(_, nameLocation, _) = _data.raw.markup.data else {
            fatalError("\(self) markup wrapped unexpected \(_data.raw)")

        }
        return nameLocation
    }

    /// The source range from which the directive's name was parsed, if it was
    /// parsed from source.
    var nameRange: SourceRange? {
        guard let start = nameLocation else {
            return nil
        }
        let end = SourceLocation(line: start.line, column: start.column + name.utf8.count, source: start.source)
        return start..<end
    }

    /// The textual content that can be interpreted as arguments to the directive.
    var argumentText: DirectiveArgumentText {
        get {
            guard case let .blockDirective(_, _, arguments) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")

            }
            return arguments
        }
        set {
            _data = _data.replacingSelf(.blockDirective(name: name,
                                                      nameLocation: nil,
                                                      argumentText: newValue,
                                                      parsedRange: nil,
                                                      _data.raw.markup.copyChildren()))
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitBlockDirective(self)
    }
}
