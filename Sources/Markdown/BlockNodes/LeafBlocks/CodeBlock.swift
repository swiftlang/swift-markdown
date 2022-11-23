/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A code block.
public struct CodeBlock: BlockMarkup {
    public var _data: _MarkupData
    init(_ raw: RawMarkup) throws {
        guard case .codeBlock = raw.data else {
            throw RawMarkup.Error.concreteConversionError(from: raw, to: CodeBlock.self)
        }
        let absoluteRaw = AbsoluteRawMarkup(markup: raw, metadata: MarkupMetadata(id: .newRoot(), indexInParent: 0))
        self.init(_MarkupData(absoluteRaw))
    }

    init(_ data: _MarkupData) {
        self._data = data
    }
}

// MARK: - Public API

public extension CodeBlock {
    /// Create a code block with raw `code` and optional `language`.
    init(language: String? = nil, _ code: String) {
        try! self.init(RawMarkup.codeBlock(parsedRange: nil, code: code, language: language))
    }

    /// The name of the syntax or programming language of the code block, which may be `nil` when unspecified.
    var language: String? {
        get {
            guard case let .codeBlock(_, language) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return language
        }
        set {
            _data = _data.replacingSelf(.codeBlock(parsedRange: nil, code: code, language: newValue))
        }
    }

    /// The raw text representing the code of this block.
    var code: String {
        get {
            guard case let .codeBlock(code, _) = _data.raw.markup.data else {
                fatalError("\(self) markup wrapped unexpected \(_data.raw)")
            }
            return code
        }
        set {
            _data = _data.replacingSelf(.codeBlock(parsedRange: nil, code: newValue, language: language))
        }
    }

    // MARK: Visitation

    func accept<V: MarkupVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitCodeBlock(self)
    }
}
