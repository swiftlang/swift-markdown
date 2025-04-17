/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// The argument text provided to a directive, which can be parsed
/// into various kinds of arguments.
///
/// For example, take the following directive:
///
/// ```markdown
/// @Dir(x: 1,
///      y: 2)
/// ```
///
/// The following line segments would be provided as ``DirectiveArgumentText``,
/// parsed as one logical string:
///
/// ```
/// x: 1,
/// ```
/// ```
/// y: 2
/// ```
public struct DirectiveArgumentText: Equatable, Sendable {

    /// Errors parsing name-value arguments from argument text segments.
    public enum ParseError: Equatable, Sendable {
        /// A duplicate argument was given.
        case duplicateArgument(name: String, firstLocation: SourceLocation, duplicateLocation: SourceLocation)

        /// A character was expected but not found at a source location.
        case missingExpectedCharacter(Character, location: SourceLocation)
        
        /// Unexpected character at a source location.
        case unexpectedCharacter(Character, location: SourceLocation)
    }

    /// A segment of a line of argument text.
    public struct LineSegment: Equatable, Sendable {
        /// The original untrimmed text of the line, from which arguments can be parsed.
        public var untrimmedText: String

        @available(*, deprecated, renamed: "untrimmedText.startIndex")
        public var lineStartIndex: String.Index {
            get { untrimmedText.startIndex }
            set { }
        }

        /// The index from which parsing should start.
        public var parseIndex: String.Index

        /// The range from which a segment was extracted from a line
        /// of source, or `nil` if it was provided by other means.
        public var range: SourceRange?

        /// The segment's text starting from ``parseIndex``.
        public var trimmedText: Substring {
            return untrimmedText[parseIndex...]
        }

        /// Create an argument line segment.
        /// - Parameters:
        ///   - untrimmedText: the segment's untrimmed text from which arguments can be parsed.
        ///   - parseIndex: The index from which parsing should start.
        ///   - range: The range from which a segment was extracted from a line
        ///     of source, or `nil` if the argument text was provided by other means.
        init(untrimmedText: String, parseIndex: String.Index? = nil, range: SourceRange? = nil) {
            self.untrimmedText = untrimmedText
            self.parseIndex = parseIndex ?? untrimmedText.startIndex
            self.range = range
        }

        /// Parse a quoted literal.
        ///
        /// ```
        /// quoted-literal -> " unquoted-literal "
        /// ```
        func parseQuotedLiteral(from line: inout TrimmedLine,
                                parseErrors: inout [ParseError]) -> TrimmedLine.Lex? {
            precondition(line.text.starts(with: "\""))
            _ = line.take(1)

            guard let contents = line.lex(until: {
                switch $0 {
                case "\"":
                    return .stop
                default:
                    return .continue
                }
            }, allowEscape: true, allowEmpty: true) else {
                return nil
            }

            _ = parseCharacter("\"", from: &line,
                               required: true,
                               allowEscape: true,
                               diagnoseIfNotFound: true,
                               parseErrors: &parseErrors)

            return contents
        }

        /// Parse an unquoted literal.
        ///
        /// ```
        /// unquoted-literal -> [^, :){]
        /// ```
        func parseUnquotedLiteral(from line: inout TrimmedLine) -> TrimmedLine.Lex? {
            let result = line.lex(until: {
                switch $0 {
                case ",", " ", ":", ")", "{":
                    return .stop
                default:
                    return .continue
                }
            }, allowEscape: true)
            return result
        }

        /// Parse a literal.
        ///
        /// ```
        /// literal -> quoted-literal
        ///          | unquoted-literal
        /// ```
        func parseLiteral(from line: inout TrimmedLine, parseErrors: inout [ParseError]) -> TrimmedLine.Lex? {
            line.lexWhitespace()
            if line.text.starts(with: "\"") {
                return parseQuotedLiteral(from: &line, parseErrors: &parseErrors)
            } else {
                return parseUnquotedLiteral(from: &line)
            }
        }

        /// Attempt to parse a single character.
        ///
        /// - Parameters:
        ///   - character: the expected character to parse
        ///   - line: the trimmed line from which to parse
        ///   - required: whether the character is required
        ///   - allowEscape: whether to allow the character to be escaped
        ///   - diagnoseIfNotFound: if `true` and the character was both required and not found, emit a diagnostic
        ///   - parseErrors: an array to update with any errors encountered while parsing
        /// - Returns: `true` if the character was found.
        func parseCharacter(_ character: Character,
                            from line: inout TrimmedLine,
                            required: Bool,
                            allowEscape: Bool,
                            diagnoseIfNotFound: Bool,
                            parseErrors: inout [ParseError]) -> Bool {
            guard line.lex(character, allowEscape: allowEscape) != nil || !required else {
                if diagnoseIfNotFound,
                   let expectedLocation = line.location {
                    parseErrors.append(.missingExpectedCharacter(character, location: expectedLocation))
                }
                return false
            }

            return true
        }

        /// Parse the line segment as name-value argument pairs separated by commas.
        ///
        /// ```
        /// arguments -> first-argument name-value-arguments-rest
        /// first-argument -> value-only-argument | name-value-argument
        /// value-only-argument -> literal
        /// name-value-argument -> literal : literal
        /// name-value-arguments -> name-value-argument name-value-arguments-rest
        /// name-value-arguments-rest -> , name-value-arguments | ε
        /// ```
        ///
        /// Note the following aspects of this parsing function.
        ///
        /// - An argument-name pair is only recognized within a single line or line segment;
        ///   that is, an argument cannot span multiple lines.
        /// - A comma is expected between name-value pairs.
        /// - The first argument can be unnamed. An unnamed argument will have an empty ``DirectiveArgument/name`` with no ``DirectiveArgument/nameRange``.
        ///
        /// - Parameter parseErrors: an array to update with any errors encountered while parsing
        /// - Returns: an array of successfully parsed ``DirectiveArgument`` values.
        public func parseNameValueArguments(parseErrors: inout [ParseError]) -> [DirectiveArgument] {
            var arguments = [DirectiveArgument]()

            var line = TrimmedLine(untrimmedText[...],
                                   source: range?.lowerBound.source,
                                   lineNumber: range?.lowerBound.line,
                                   parseIndex: parseIndex
            )
            line.lexWhitespace()
            while !line.isEmptyOrAllWhitespace {
                let name: TrimmedLine.Lex?
                let value: TrimmedLine.Lex
                
                guard let firstLiteral = parseLiteral(from: &line, parseErrors: &parseErrors) else {
                    while parseCharacter(",", from: &line, required: true, allowEscape: false, diagnoseIfNotFound: false, parseErrors: &parseErrors) {
                        if let location = line.location {
                            parseErrors.append(.unexpectedCharacter(",", location: location))
                        }
                    }
                    _ = line.lex(untilCharacter: ",")
                    continue
                }
                
                // The first argument can be without a name.
                // An argument without a name must be followed by a "," or be the only argument. Otherwise the argument will be parsed as a named argument.
                if arguments.isEmpty && (line.isEmptyOrAllWhitespace || line.text.first == ",") {
                    name = nil
                    value = firstLiteral
                } else {
                    _ = parseCharacter(":", from: &line, required: true, allowEscape: false, diagnoseIfNotFound: true, parseErrors: &parseErrors)
                    
                    guard let secondLiteral = parseLiteral(from: &line, parseErrors: &parseErrors) else {
                        while parseCharacter(",", from: &line, required: true, allowEscape: false, diagnoseIfNotFound: false, parseErrors: &parseErrors) {
                            if let location = line.location {
                                parseErrors.append(.unexpectedCharacter(",", location: location))
                            }
                        }
                        _ = line.lex(untilCharacter: ",")
                        continue
                    }
                    name = firstLiteral
                    value = secondLiteral
                }
                
                let nameRange: SourceRange?
                let valueRange: SourceRange?

                if let lineLocation = line.location,
                   let range = name?.range {
                    nameRange = SourceLocation(line: lineLocation.line, column: range.lowerBound.column, source: range.lowerBound.source)..<SourceLocation(line: lineLocation.line, column: range.upperBound.column, source: range.upperBound.source)
                } else {
                    nameRange = nil
                }

                if let lineNumber = line.lineNumber,
                   let range = value.range {
                    valueRange = SourceLocation(line: lineNumber, column: range.lowerBound.column, source: range.lowerBound.source)..<SourceLocation(line: lineNumber, column: range.upperBound.column, source: range.lowerBound.source)
                } else {
                    valueRange = nil
                }
                line.lexWhitespace()
                let hasTrailingComma = parseCharacter(",",
                                                      from: &line,
                                                      required: true,
                                                      allowEscape: false,
                                                      diagnoseIfNotFound: false,
                                                      parseErrors: &parseErrors)

                let argument = DirectiveArgument(name: String(name?.text ?? ""),
                                                 nameRange: nameRange,
                                                 value: String(value.text),
                                                 valueRange: valueRange,
                                                 hasTrailingComma: hasTrailingComma)
                arguments.append(argument)

                line.lexWhitespace()
            }

            return arguments
        }
    }

    /// The segments that make up the argument text.
    public var segments: [LineSegment]

    /// Create a body of argument text as a single, rangeless ``LineSegment``
    /// from a string.
    public init<S: StringProtocol>(_ string: S) {
        let text = String(string)
        self.segments = [LineSegment(untrimmedText: text, range: nil)]
    }

    /// Create a body of argument text from a sequence of ``LineSegment`` elements.
    public init<Segments: Sequence>(segments: Segments) where Segments.Element == LineSegment {
        self.segments = Array(segments)
    }

    /// `true` if there are no segments or all segments consist entirely of whitespace.
    public var isEmpty: Bool {
        return segments.isEmpty || segments.allSatisfy {
            $0.untrimmedText.isEmpty || $0.untrimmedText.allSatisfy {
                $0 == " " || $0 == "\t"
            }
        }
    }

    /// Parse the line segments as name-value argument pairs separated by commas.
    ///
    /// ```
    /// arguments -> first-argument name-value-arguments-rest
    /// first-argument -> value-only-argument | name-value-argument
    /// value-only-argument -> literal
    /// name-value-argument -> literal : literal
    /// name-value-arguments -> name-value-argument name-value-arguments-rest
    /// name-value-arguments-rest -> , name-value-arguments | ε
    /// ```
    ///
    /// Note the following aspects of this parsing function.
    ///
    /// - An argument-name pair is only recognized within a single line or line segment;
    ///   that is, an argument cannot span multiple lines.
    /// - A comma is expected between name-value pairs.
    /// - The first argument can be unnamed. An unnamed argument will have an empty ``DirectiveArgument/name`` with no ``DirectiveArgument/nameRange``.
    ///
    /// - Parameter parseErrors: an array to collect errors while parsing arguments.
    /// - Returns: an array of successfully parsed ``DirectiveArgument`` values.
    public func parseNameValueArguments(parseErrors: inout [ParseError]) -> [DirectiveArgument] {
        var arguments = [DirectiveArgument]()
        for segment in segments {
            let segmentArguments = segment.parseNameValueArguments(parseErrors: &parseErrors)
            for argument in segmentArguments {
                if let originalArgument = arguments.first(where: { $0.name == argument.name }),
                   let firstLocation = originalArgument.nameRange?.lowerBound,
                   let duplicateLocation = argument.nameRange?.lowerBound {
                    parseErrors.append(.duplicateArgument(name: argument.name,
                                                          firstLocation: firstLocation,
                                                          duplicateLocation: duplicateLocation))
                }
                arguments.append(argument)
            }
        }

        if arguments.count > 1 {
            for argument in arguments.prefix(arguments.count - 1) {
                if !argument.hasTrailingComma,
                   let valueRange = argument.valueRange {
                    parseErrors.append(.missingExpectedCharacter(",", location: valueRange.upperBound))
                }
            }
        }
        return arguments
    }

    /// Parse the line segments as name-value argument pairs separated by commas.
    ///
    /// ```
    /// arguments -> first-argument name-value-arguments-rest
    /// first-argument -> value-only-argument | name-value-argument
    /// value-only-argument -> literal
    /// name-value-argument -> literal : literal
    /// name-value-arguments -> name-value-argument name-value-arguments-rest
    /// name-value-arguments-rest -> , name-value-arguments | ε
    /// ```
    ///
    /// Note the following aspects of this parsing function.
    ///
    /// - An argument-name pair is only recognized within a single line or line segment;
    ///   that is, an argument cannot span multiple lines.
    /// - A comma is expected between name-value pairs.
    /// - The first argument can be unnamed. An unnamed argument will have an empty ``DirectiveArgument/name`` with no ``DirectiveArgument/nameRange``.
    ///
    /// - Returns: an array of successfully parsed ``DirectiveArgument`` values.
    ///
    /// This overload discards parse errors.
    ///
    /// - SeeAlso: ``parseNameValueArguments(parseErrors:)``
    public func parseNameValueArguments() -> [DirectiveArgument] {
        var parseErrors = [ParseError]()
        return parseNameValueArguments(parseErrors: &parseErrors)
    }
}

/// A directive argument, parsed from the form `name: value` or `name: "value"`.
public struct DirectiveArgument: Equatable, Sendable {
    /// The name of the argument.
    public var name: String

    /// The range of the argument name if it was parsed from source text.
    public var nameRange: SourceRange?

    /// The value of the argument.
    public var value: String

    /// The range of the argument value if it was parsed from source text.
    public var valueRange: SourceRange?

    /// `true` if the argument value was followed by a comma.
    public var hasTrailingComma: Bool
}

