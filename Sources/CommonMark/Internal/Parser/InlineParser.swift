/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

internal import BasicContainers

/// A 3×5 `Int` matrix - rows indexed by `length % 3`, columns by delimiter-char index (`*_~'"`) - used as the emphasis `openersBottom` search-floor table.
///
/// Tuple-backed with unsafe indexing so it back-deploys and stack-allocates (a nested `InlineArray` would be value-generic and require the anyAppleOS 26 runtime). Offsets are multiples of `Int` stride over an `Int`-aligned tuple, so loads are aligned.
internal struct OpenersBottom {
    private var storage: (Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int, Int)

    internal init(fill: Int) {
        storage = (fill, fill, fill, fill, fill, fill, fill, fill, fill, fill, fill, fill, fill, fill, fill)
    }

    internal subscript(_ row: Int, _ col: Int) -> Int {
        get {
            withUnsafeBytes(of: storage) {
                $0.load(fromByteOffset: (row * 5 + col) * MemoryLayout<Int>.stride, as: Int.self)
            }
        }
        set {
            withUnsafeMutableBytes(of: &storage) {
                $0.storeBytes(of: newValue, toByteOffset: (row * 5 + col) * MemoryLayout<Int>.stride, as: Int.self)
            }
        }
    }
}

/// Inline-level Markdown parsing functions.
extension BlockParser {

    /// Parse the inline content of `parent`. The raw byte content of the parent has already been materialized into `content` (resolved from a `Chunk`, typically pointing into `storage.strings`) by the block parser.
    ///
    /// On exit, `parent` has zero or more inline child nodes attached. Returns without emitting any child if `content` is empty.
    mutating func parseInline(
        content: borrowing ContentSpan,
        into parent: DocumentStorage.Index,
        preserveWhitespace: Bool = false,
        delimiters: inout UniqueArray<DelimiterRecord>,
        brackets: inout UniqueArray<BracketRecord>
    ) throws (MarkdownDocument.Error) {
        if content.isEmpty {
            return
        }
        // The delimiter and bracket stacks are caller-owned scratch buffers, reused across every paragraph in the document. Reset them to empty rather than allocating per call.
        delimiters.removeAll(keepingCapacity: true)
        brackets.removeAll(keepingCapacity: true)
        
        // The content region carries which buffer it came from; hoist it once for the buffer-agnostic helpers (entity matching, `Scanners`, `readByte`) that read by global offset.
        let inSource = content.inSource
        var cursor = content.startOffset
        let endOffset = content.endOffset
        var pendingTextStart = cursor
        var lastDelim: Int? = nil
        var lastBracket: Int? = nil
        var noLinkOpeners = false

        // Hoisted once for the plain-text skip in the `default` case below.
        let strikethroughEnabled = storage.options.contains(.strikethrough)
        let gfmAutolinkEnabled = storage.options.contains(.gfmAutolink)
        let smartEnabled = storage.options.contains(.smart)

        while cursor < endOffset {
            let byte = content[cursor]
            switch byte {
            case UInt8(ascii: "`"):
                if let span = matchCodeSpan(
                    start: cursor,
                    end: endOffset,
                    content: content
                ) {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    // Code-span content: replace newlines with single spaces (per CommonMark §6.1) before applying the single-space-strip rule. Keep the original chunk if there are no newlines so we don't materialize for the common case.
                    let normalized = normalizeCodeSpanContent(span.content)
                    let normalizedRef = storage.intern(normalized)
                    let codeIdx = storage.appendNode(
                        NodeRecord(
                            kind: .codeInline(backtickCount: span.backtickCount),
                            parent: parent,
                            data: .literal(normalizedRef)
                        )
                    )
                    storage.appendChild(codeIdx, to: parent)
                    stampInline(codeIdx, cursor, span.afterClose, content: content)
                    cursor = span.afterClose
                    pendingTextStart = cursor
                    continue
                }
                // No matching close - skip past the run; the backticks become part of the pending text region.
                cursor = scanBacktickRun(
                    start: cursor,
                    end: endOffset,
                    content: content
                )

            case UInt8(ascii: "\n"):
                // Inline-only / preserve-whitespace mode: a newline is literal text, not a soft/hard break. Leave it in the pending-text region (it has already been normalized to `\n` by `parseInlineOnly`) and step past it.
                if preserveWhitespace {
                    cursor += 1
                    continue
                }
                let info = classifyLineBreak(
                    at: cursor,
                    pendingTextStart: pendingTextStart,
                    content: content
                )
                flushPendingText(
                    start: pendingTextStart,
                    end: info.textEnd,
                    content: content,
                    into: parent,
                    // A hard break's stripped trailing spaces / backslash still belong to the preceding text node's source range (cmark stamps it up to the newline at `cursor`).
                    rangeEnd: info.isHard ? cursor : nil
                )
                let kind: MarkdownNode.Kind = info.isHard ? .lineBreak : .softBreak
                let breakIdx = storage.appendNode(NodeRecord(kind: kind, parent: parent))
                storage.appendChild(breakIdx, to: parent)
                cursor += 1
                pendingTextStart = cursor
                
            case UInt8(ascii: "&"):
                let entity = if inSource {
                    EntityParser.matchEntity(start: cursor, end: endOffset, source: sourceBytes)
                } else {
                    EntityParser.matchEntity(start: cursor, end: endOffset, source: storage.strings.span)
                }
                if let entity {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    let decoded = Self.appendUTF8Bytes(
                        bytes: entity.bytes,
                        count: entity.count,
                        into: &storage.strings
                    )
                    let decodedRef = storage.intern(decoded)
                    let textIdx = storage.appendNode(
                        NodeRecord(kind: .text, parent: parent, data: .literal(decodedRef))
                    )
                    storage.appendChild(textIdx, to: parent)
                    stampInline(textIdx, cursor, entity.afterSemi, content: content)
                    cursor = entity.afterSemi
                    pendingTextStart = cursor
                    continue
                }
                cursor += 1
                
            case UInt8(ascii: "<"):
                if let auto = matchAutolink(
                    start: cursor,
                    end: endOffset,
                    content: content
                ) {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    emitAutolink(
                        auto: auto,
                        into: parent,
                        content: content
                    )
                    cursor = auto.afterClose
                    pendingTextStart = cursor
                    continue
                }
                if let htmlEnd = matchInlineHTML(
                    start: cursor,
                    end: endOffset,
                    content: content
                ) {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    let chunk = content.chunk(
                        offset: cursor,
                        length: htmlEnd - cursor
                    )
                    let chunkRef = storage.intern(chunk)
                    let nodeIdx = storage.appendNode(
                        NodeRecord(kind: .htmlInline, parent: parent, data: .literal(chunkRef))
                    )
                    storage.appendChild(nodeIdx, to: parent)
                    stampInline(nodeIdx, cursor, htmlEnd, content: content)
                    cursor = htmlEnd
                    pendingTextStart = cursor
                    continue
                }
                cursor += 1
                
            case UInt8(ascii: "*"), UInt8(ascii: "_"):
                cursor = try handleDelimRun(
                    char: byte,
                    start: cursor,
                    end: endOffset,
                    content: content,
                    parent: parent,
                    delimiters: &delimiters,
                    lastDelim: &lastDelim,
                    pendingTextStart: &pendingTextStart
                )

            case UInt8(ascii: "~"):
                if storage.options.contains(.strikethrough) {
                    cursor = try handleDelimRun(
                        char: byte,
                        start: cursor,
                        end: endOffset,
                        content: content,
                        parent: parent,
                        delimiters: &delimiters,
                        lastDelim: &lastDelim,
                        pendingTextStart: &pendingTextStart
                    )
                } else {
                    cursor += 1
                }
                
            case UInt8(ascii: "["):
                flushPendingText(
                    start: pendingTextStart,
                    end: cursor,
                    content: content,
                    into: parent
                )
                let textChunk = content.chunk(offset: cursor, length: 1)
                let textRef = storage.intern(textChunk)
                let textIdx = storage.appendNode(
                    NodeRecord(kind: .text, parent: parent, data: .literal(textRef))
                )
                storage.appendChild(textIdx, to: parent)
                try pushBracket(
                    kind: .link,
                    inlText: textIdx,
                    delimPosition: lastDelim ?? -1,
                    brackets: &brackets,
                    lastBracket: &lastBracket,
                    noLinkOpeners: &noLinkOpeners
                )
                cursor += 1
                pendingTextStart = cursor
                
            case UInt8(ascii: "!"):
                if cursor + 1 < endOffset,
                   content[cursor + 1] == UInt8(ascii: "[") {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    let textChunk = content.chunk(offset: cursor, length: 2)
                    let textRef = storage.intern(textChunk)
                    let textIdx = storage.appendNode(
                        NodeRecord(kind: .text, parent: parent, data: .literal(textRef))
                    )
                    storage.appendChild(textIdx, to: parent)
                    try pushBracket(
                        kind: .image,
                        inlText: textIdx,
                        delimPosition: lastDelim ?? -1,
                        brackets: &brackets,
                        lastBracket: &lastBracket,
                        noLinkOpeners: &noLinkOpeners
                    )
                    cursor += 2
                    pendingTextStart = cursor
                } else {
                    cursor += 1
                }
                
            case UInt8(ascii: "^"):
                if cursor + 1 < endOffset,
                   content[cursor + 1] == UInt8(ascii: "[") {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    let textChunk = content.chunk(offset: cursor, length: 2)
                    let textRef = storage.intern(textChunk)
                    let textIdx = storage.appendNode(
                        NodeRecord(kind: .text, parent: parent, data: .literal(textRef))
                    )
                    storage.appendChild(textIdx, to: parent)
                    try pushBracket(
                        kind: .attribute,
                        inlText: textIdx,
                        delimPosition: lastDelim ?? -1,
                        brackets: &brackets,
                        lastBracket: &lastBracket,
                        noLinkOpeners: &noLinkOpeners
                    )
                    cursor += 2
                    pendingTextStart = cursor
                } else {
                    cursor += 1
                }
                
            case UInt8(ascii: "]"):
                flushPendingText(
                    start: pendingTextStart,
                    end: cursor,
                    content: content,
                    into: parent
                )
                cursor = handleCloseBracket(
                    cursor: cursor,
                    end: endOffset,
                    content: content,
                    parent: parent,
                    delimiters: &delimiters,
                    lastDelim: &lastDelim,
                    brackets: &brackets,
                    lastBracket: &lastBracket,
                    noLinkOpeners: &noLinkOpeners
                )
                pendingTextStart = cursor

            case UInt8(ascii: "\\"):
                // Backslash escape: `\<ASCII punct>` emits the punct as a single-byte text node. `\<newline>` is detected by the line-break handler when we hit the newline. Anything else leaves the backslash as literal text.
                if cursor + 1 < endOffset {
                    let next = content[cursor + 1]
                    if next.isASCIIPunct {
                        flushPendingText(
                            start: pendingTextStart,
                            end: cursor,
                            content: content,
                            into: parent
                        )
                        let punctChunk = content.chunk(
                            offset: cursor + 1,
                            length: 1
                        )
                        let punctRef = storage.intern(punctChunk)
                        let textIdx = storage.appendNode(
                            NodeRecord(kind: .text, parent: parent, data: .literal(punctRef))
                        )
                        storage.appendChild(textIdx, to: parent)
                        cursor += 2
                        pendingTextStart = cursor
                        continue
                    }
                }
                cursor += 1
                
            case UInt8(ascii: ":"), UInt8(ascii: "w"), UInt8(ascii: "W"), UInt8(ascii: "@"):
                if storage.options.contains(.gfmAutolink),
                   let auto = matchGFMAutolink(
                    trigger: byte,
                    cursor: cursor,
                    end: endOffset,
                    content: content
                   ) {
                    flushPendingText(
                        start: pendingTextStart,
                        end: auto.urlStart,
                        content: content,
                        into: parent
                    )
                    emitGFMAutolink(
                        auto: auto,
                        content: content,
                        into: parent
                    )
                    cursor = auto.urlEnd
                    pendingTextStart = cursor
                    continue
                }
                cursor += 1
                
            case UInt8(ascii: "'"), UInt8(ascii: "\""):
                // Smart quotes: push a quote delimiter (resolved to curly open/close in `processEmphasis`). Without `.smart`, the byte is ordinary text.
                if smartEnabled {
                    cursor = try handleQuoteDelim(
                        char: byte,
                        start: cursor,
                        end: endOffset,
                        content: content,
                        parent: parent,
                        delimiters: &delimiters,
                        lastDelim: &lastDelim,
                        pendingTextStart: &pendingTextStart
                    )
                } else {
                    cursor += 1
                }

            case UInt8(ascii: "-"):
                // Smart dashes: a run of 2+ hyphens becomes en/em dashes. A lone `-` is left in the pending-text region (identical text, fewer nodes).
                if smartEnabled {
                    cursor = handleSmartHyphen(
                        start: cursor,
                        end: endOffset,
                        content: content,
                        parent: parent,
                        pendingTextStart: &pendingTextStart
                    )
                } else {
                    cursor += 1
                }

            case UInt8(ascii: "."):
                // Smart ellipsis: exactly `...` becomes a single ellipsis. Other runs of dots stay in the pending-text region.
                if smartEnabled,
                   cursor + 2 < endOffset,
                   content[cursor + 1] == UInt8(ascii: "."),
                   content[cursor + 2] == UInt8(ascii: ".") {
                    flushPendingText(
                        start: pendingTextStart,
                        end: cursor,
                        content: content,
                        into: parent
                    )
                    let ellipsisRef = internSmartLiteral(Self.ellipsis)
                    let textIdx = storage.appendNode(
                        NodeRecord(kind: .text, parent: parent, data: .literal(ellipsisRef))
                    )
                    storage.appendChild(textIdx, to: parent)
                    cursor += 3
                    pendingTextStart = cursor
                } else {
                    cursor += 1
                }

            default:
                // Plain text: SIMD-skip to the next inline-significant byte instead of stepping one byte at a time. The skipped run stays pending and is flushed when that byte emits.
                cursor = content.nextSignificant(
                    from: cursor,
                    strikethrough: strikethroughEnabled,
                    gfmAutolink: gfmAutolinkEnabled,
                    smart: smartEnabled
                )
            }
        }
        flushPendingText(
            start: pendingTextStart,
            end: endOffset,
            content: content,
            into: parent
        )
        processEmphasis(
            stackBottom: -1,
            delimiters: &delimiters,
            lastDelim: &lastDelim
        )
    }

    // MARK: - Links / images (bracket stack)

    /// Bracket-stack opener kind. `.link` and `.attribute` reset `noLinkOpeners` when pushed; `.image` does not.
    internal enum BracketKind {
        case link
        case image
        case attribute
    }

    /// Bracket-stack entry recording an open `[` (LINK), `![` (IMAGE), or `^[` (ATTRIBUTE - fork-specific extended-attribute syntax). Like the delimiter stack, it's a doubly-linked list embedded in an array; `previous` is an index into `brackets` (or `nil`).
    internal struct BracketRecord {
        var kind: BracketKind
        var inlText: DocumentStorage.Index
        /// Delimiter-stack index at time of push. Passed to `processEmphasis` as `stackBottom` after a successful link match so emphasis inside the link text gets resolved without leaking out.
        var delimPosition: Int
        /// `true` once any later bracket has been pushed on top of this one. Used to disqualify the shortcut-reference form for outer brackets that contain nested ones.
        var bracketAfter: Bool
        var previous: Int?
    }

    private func pushBracket(kind: BracketKind, inlText: DocumentStorage.Index, delimPosition: Int, brackets: inout UniqueArray<BracketRecord>, lastBracket: inout Int?, noLinkOpeners: inout Bool) throws (MarkdownDocument.Error) {
        if let lastBracket {
            brackets[lastBracket].bracketAfter = true
        }
        let prev = lastBracket
        let newIdx = brackets.count
        brackets.append(BracketRecord(
            kind: kind,
            inlText: inlText,
            delimPosition: delimPosition,
            bracketAfter: false,
            previous: prev
        ))
        lastBracket = newIdx
        if kind != .image {
            noLinkOpeners = false
        }
    }

    private func popBracket(brackets: inout UniqueArray<BracketRecord>, lastBracket: inout Int?) {
        if let last = lastBracket {
            lastBracket = brackets[last].previous
        }
    }
    
    /// Process a `]` while the parent's child list contains any text/inline nodes that were emitted after the matching `[`. Returns the new cursor position.
    private mutating func handleCloseBracket(cursor: Int, end: Int, content: borrowing ContentSpan, parent: DocumentStorage.Index, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?, brackets: inout UniqueArray<BracketRecord>, lastBracket: inout Int?, noLinkOpeners: inout Bool) -> Int {
        let inSource = content.inSource
        let initialPos = cursor + 1
        var pos = initialPos
        // No bracket open: emit `]` literal and return.
        guard let openerIdx = lastBracket else {
            emitBracketLiteral(at: cursor, content: content, parent: parent)
            return pos
        }
        let openerKind = brackets[openerIdx].kind
        let openerInl = brackets[openerIdx].inlText
        let openerDelimPos = brackets[openerIdx].delimPosition
        let openerBracketAfter = brackets[openerIdx].bracketAfter
        if openerKind == .attribute {
            return handleCloseBracketAttribute(
                cursor: cursor,
                end: end,
                content: content,
                parent: parent,
                openerInl: openerInl,
                openerDelimPos: openerDelimPos,
                delimiters: &delimiters,
                lastDelim: &lastDelim,
                brackets: &brackets,
                lastBracket: &lastBracket
            )
        }
        let isImage = openerKind == .image
        // Inactive link opener: just pop and emit `]`.
        if !isImage && noLinkOpeners {
            popBracket(brackets: &brackets, lastBracket: &lastBracket)
            emitBracketLiteral(at: cursor, content: content, parent: parent)
            return pos
        }
        // Get the byte position of the `[` (or `!` of `![`) so we can derive the shortcut-form label range later.
        let openerByteStart: Int
        if case .literal(let ref) = storage[openerInl].data {
            openerByteStart = storage.chunk(of: ref).offset
        } else {
            popBracket(brackets: &brackets, lastBracket: &lastBracket)
            emitBracketLiteral(at: cursor, content: content, parent: parent)
            return pos
        }
        var url: Chunk = .empty
        var title: Chunk = .empty
        var matched = false
        // Try inline link: `(url "title")`.
        if pos < end,
           content[pos] == UInt8(ascii: "(") {
            let afterParen = pos + 1
            let afterSpaces1 = skipSpaceChars(start: afterParen, end: end, content: content)
            if let dest = matchLinkDestination(Chunk(offset: afterSpaces1, length: end - afterSpaces1, inSource: inSource)) {
                let afterDest = dest.afterEnd
                let afterSpaces2 = skipSpaceChars(start: afterDest, end: end, content: content)
                var titleEnd = afterDest
                var maybeTitle: Chunk = .empty
                if afterSpaces2 > afterDest,
                   let t = matchLinkTitle(Chunk(offset: afterSpaces2, length: end - afterSpaces2, inSource: inSource)) {
                    maybeTitle = t.chunk
                    titleEnd = t.afterEnd
                }
                let afterTitleSpaces = skipSpaceChars(start: titleEnd, end: end, content: content)
                if afterTitleSpaces < end,
                   content[afterTitleSpaces] == UInt8(ascii: ")") {
                    pos = afterTitleSpaces + 1
                    url = EntityParser.unescapeURLChunk(dest.chunk, source: sourceBytes, into: &storage)
                    title = EntityParser.unescapeURLChunk(maybeTitle, source: sourceBytes, into: &storage)
                    matched = true
                }
            }
            if !matched {
                pos = initialPos
            }
        }
        // Try reference link forms: full `[label]`, collapsed `[]`, or shortcut.
        if !matched {
            var labelChunk: Chunk?
            var afterRefForm = pos
            if let lab = matchLinkLabel(Chunk(offset: pos, length: end - pos, inSource: inSource)) {
                labelChunk = content.chunk(
                    offset: lab.interior.offset,
                    length: lab.interior.length
                )
                afterRefForm = lab.afterEnd
            }
            // Collapsed `[]` or absent - fall back to shortcut form (the bracket text itself becomes the label) when no inner brackets were nested under this opener.
            let labelLen = labelChunk?.length ?? 0
            if labelLen == 0 && !openerBracketAfter {
                let openerContentStart = openerByteStart + (isImage ? 2 : 1)
                let shortcutLen = cursor - openerContentStart
                if shortcutLen > 0 {
                    labelChunk = content.chunk(
                        offset: openerContentStart,
                        length: shortcutLen
                    )
                }
            }
            if let lc = labelChunk, lc.length > 0 {
                let key = normalizeLabel(
                    chunk: lc
                )
                if !key.isEmpty, let ref = storage.referenceMap[key] {
                    url = ref.destination
                    title = ref.title
                    pos = afterRefForm
                    matched = true
                }
            }
        }
        if matched {
            buildLinkOrImage(
                isImage: isImage,
                openerInl: openerInl,
                openerDelimPos: openerDelimPos,
                url: url,
                title: title,
                linkStart: openerByteStart,
                linkEnd: pos,
                inSource: inSource,
                delimiters: &delimiters,
                lastDelim: &lastDelim
            )
            popBracket(brackets: &brackets, lastBracket: &lastBracket)
            if !isImage {
                noLinkOpeners = true
            }
            return pos
        }
        // GFM footnote reference: when no link form matches but the bracket contents start with `^` (and have at least one more byte), treat the whole `[^label]` as a `.footnoteReference`.
        if storage.options.contains(.footnotes),
           !isImage,
           let labelChunk = footnoteRefLabel(
               openerByteStart: openerByteStart,
               closeBracket: cursor,
               content: content
           ) {
            emitFootnoteReference(
                openerInl: openerInl,
                labelChunk: labelChunk
            )
            popBracket(brackets: &brackets, lastBracket: &lastBracket)
            return initialPos
        }
        // No match: pop bracket, emit `]` text, rewind to just past `]`.
        popBracket(brackets: &brackets, lastBracket: &lastBracket)
        emitBracketLiteral(at: cursor, content: content, parent: parent)
        return initialPos
    }

    /// Append a one-byte `]` text node at `cursor`. Used by the failure paths of `handleCloseBracket`.
    private mutating func emitBracketLiteral(at cursor: Int, content: borrowing ContentSpan, parent: DocumentStorage.Index) {
        let chunk = content.chunk(offset: cursor, length: 1)
        let chunkRef = storage.intern(chunk)
        let idx = storage.appendNode(
            NodeRecord(kind: .text, parent: parent, data: .literal(chunkRef))
        )
        storage.appendChild(idx, to: parent)
    }

    /// Construct the `.link` / `.image` node, splice it in front of the opener's `[` text node, reparent every following sibling into it, and remove the opener's `[` text from the tree. Then resolve emphasis inside the link with the bracket's `delimPosition` as the floor.
    private mutating func buildLinkOrImage(isImage: Bool, openerInl: DocumentStorage.Index, openerDelimPos: Int, url: Chunk, title: Chunk, linkStart: Int, linkEnd: Int, inSource: Bool, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?) {
        let parentIdx = storage[openerInl].parent
        let kind: MarkdownNode.Kind = isImage ? .image : .link
        let urlRef = storage.intern(url)
        let titleRef = storage.intern(title)
        let linkIdx = storage.appendNode(NodeRecord(
            kind: kind,
            parent: parentIdx,
            data: .link(url: urlRef, title: titleRef)
        ))
        // The link/image spans from its opening `[`/`![` to just past the closing `)` or reference label.
        stampInline(linkIdx, linkStart, linkEnd, inSource: inSource)
        storage.insertChildBefore(linkIdx, before: openerInl)
        var sib = storage[openerInl].next
        while let sib_ = sib {
            let nextSib = storage[sib_].next
            storage.unlinkChild(sib_)
            storage.appendChild(sib_, to: linkIdx)
            sib = nextSib
        }
        storage.unlinkChild(openerInl)
        processEmphasis(
            stackBottom: openerDelimPos,
            delimiters: &delimiters,
            lastDelim: &lastDelim
        )
    }

    // MARK: - Footnote references

    /// Match a footnote-reference label inside an unmatched `[…]`.
    ///
    /// Returns the label chunk (excluding `[^` and `]`) if the bracket contents start with `^` and contain at least one more byte. The byte positions reference the original chunk via `inSource`.
    private func footnoteRefLabel(openerByteStart: Int, closeBracket: Int, content: borrowing ContentSpan) -> Chunk? {
        let interiorStart = openerByteStart + 1
        if interiorStart >= closeBracket {
            return nil
        }
        if content[interiorStart] != UInt8(ascii: "^") {
            return nil
        }
        let labelStart = interiorStart + 1
        if labelStart >= closeBracket {
            return nil
        }
        return content.chunk(
            offset: labelStart,
            length: closeBracket - labelStart
        )
    }

    /// Splice a `.footnoteReference` node in place of the opener `[`'s text node and any inner-content text nodes.
    ///
    /// Assigns or reuses the 1-based index for this label. If the matching definition is already in `storage.footnoteMap`, increments its `referenceCount`.
    private mutating func emitFootnoteReference(openerInl: DocumentStorage.Index, labelChunk: Chunk) {
        let key = normalizeLabel(chunk: labelChunk)
        let index: Int32
        if let existing = storage.footnoteIndices[key] {
            index = existing
        } else {
            storage.nextFootnoteIndex += 1
            index = storage.nextFootnoteIndex
            storage.footnoteIndices[key] = index
        }
        if let defIdx = storage.footnoteMap[key],
           case .footnoteDefinition(let lbl, let count) = storage[defIdx].data {
            storage[defIdx].data = .footnoteDefinition(
                label: lbl,
                referenceCount: count + 1
            )
        }
        let parentIdx = storage[openerInl].parent
        let labelRef = storage.intern(labelChunk)
        let fnRefIdx = storage.appendNode(NodeRecord(
            kind: .footnoteReference(index: Int(index)),
            parent: parentIdx,
            data: .footnoteReference(label: labelRef)
        ))
        storage.insertChildBefore(fnRefIdx, before: openerInl)
        // Detach inner-content text nodes (the `^label` part). They aren't part of the reference's emitted text - the reference is rendered by the consumer based on its label and index.
        var sib = storage[openerInl].next
        while let sib_ = sib {
            let nextSib = storage[sib_].next
            storage.unlinkChild(sib_)
            sib = nextSib
        }
        storage.unlinkChild(openerInl)
    }

    // MARK: - Extended attributes (`^[..]`)

    /// Resolve a `]` that closes an `^[…]` attribute opener. Tries the inline form `(attrs)` first, then the reference form `[label]` whose label resolves in `storage.attributeReferenceMap`.
    ///
    /// On match emits a `.attribute` node and reparents the inner siblings into it.
    private mutating func handleCloseBracketAttribute(cursor: Int, end: Int, content: borrowing ContentSpan, parent: DocumentStorage.Index, openerInl: DocumentStorage.Index, openerDelimPos: Int, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?, brackets: inout UniqueArray<BracketRecord>, lastBracket: inout Int?) -> Int {
        let inSource = content.inSource
        var pos = cursor + 1
        var attrs: Chunk = .empty
        var matched = false
        // Try inline `(attrs)` form. The attribute scanner allows whitespace and balanced parens - this is *not* a link-URL scan.
        if pos < end,
           content[pos] == UInt8(ascii: "(") {
            let startAttrs = pos + 1
            if let scanned = matchAttributeAttributes(start: startAttrs, end: end, content: content) {
                let endAttrs = scanned.afterEnd
                if endAttrs < end,
                   content[endAttrs] == UInt8(ascii: ")") {
                    attrs = scanned.chunk
                    pos = endAttrs + 1
                    matched = true
                }
            }
        }
        // Try reference form `[label]` looking up in attribute refmap.
        if !matched,
           let lab = matchLinkLabel(Chunk(offset: pos, length: end - pos, inSource: inSource)) {
            let labelChunk = content.chunk(
                offset: lab.interior.offset,
                length: lab.interior.length
            )
            if labelChunk.length > 0 {
                let key = normalizeLabel(
                    chunk: labelChunk
                )
                if !key.isEmpty,
                   let storedAttrs = storage.attributeReferenceMap[key] {
                    attrs = storedAttrs
                    pos = lab.afterEnd
                    matched = true
                }
            }
        }
        if !matched {
            // Fail: pop bracket, emit `]` text. The `^[` text node stays as regular text in the tree, which matches the C behavior.
            popBracket(brackets: &brackets, lastBracket: &lastBracket)
            emitBracketLiteral(at: cursor, content: content, parent: parent)
            return cursor + 1
        }
        // Match: build attribute node, reparent siblings, drop opener `^[`.
        let parentIdx = storage[openerInl].parent
        let attrsRef = storage.intern(attrs)
        let attrIdx = storage.appendNode(NodeRecord(
            kind: .attribute,
            parent: parentIdx,
            data: .attribute(attrsRef)
        ))
        // The `^[…](…)` attribute spans from its opening `^[` to just past the closing form.
        if let openerChunk = literalChunk(of: openerInl) {
            stampInline(attrIdx, openerChunk.offset, pos, inSource: inSource)
        }
        storage.insertChildBefore(attrIdx, before: openerInl)
        var sib = storage[openerInl].next
        while let sib_ = sib {
            let nextSib = storage[sib_].next
            storage.unlinkChild(sib_)
            storage.appendChild(sib_, to: attrIdx)
            sib = nextSib
        }
        storage.unlinkChild(openerInl)
        processEmphasis(
            stackBottom: openerDelimPos,
            delimiters: &delimiters,
            lastDelim: &lastDelim
        )
        popBracket(brackets: &brackets, lastBracket: &lastBracket)
        return pos
    }

    private struct AttributeAttributesMatch {
        var chunk: Chunk
        var afterEnd: Int
    }

    /// Scan the inside of an attribute form's `(…)`.
    ///
    /// Allows whitespace and nested balanced parens up to depth 32. Backslash before ASCII punctuation is treated as an escape (and consumed as a 2-byte unit). Differs from a link-URL scan in that whitespace is not a terminator.
    private func matchAttributeAttributes(start: Int, end: Int, content: borrowing ContentSpan) -> AttributeAttributesMatch? {
        var i = start
        var nbParen = 0
        while i < end {
            let c = content[i]
            if c == UInt8(ascii: "\\") && i + 1 < end {
                let next = content[i + 1]
                if next.isASCIIPunct {
                    i += 2
                    continue
                }
                i += 1
                continue
            }
            if c == UInt8(ascii: "(") {
                nbParen += 1
                if nbParen > 32 {
                    return nil
                }
                i += 1
                continue
            }
            if c == UInt8(ascii: ")") {
                if nbParen == 0 {
                    let chunk = content.chunk(offset: start, length: i - start)
                    return AttributeAttributesMatch(chunk: chunk, afterEnd: i)
                }
                nbParen -= 1
                i += 1
                continue
            }
            i += 1
        }
        return nil
    }

    // MARK: - Emphasis / strong (delimiter stack)

    /// One node in the delimiter stack - the side data structure used by CommonMark's emphasis-resolution algorithm (§6.2 + Appendix). Each record points at a `.text` node whose literal contains the run of `*` or `_` characters scanned during the forward pass.
    ///
    /// The stack is a doubly-linked list embedded in a `UniqueArray<DelimiterRecord>` array - `previous`/`next` are array indices, `nil` means "none". When emphasis is resolved, individual records are unlinked from the list but the array itself isn't shrunk (so other indices stay valid).
    internal struct DelimiterRecord {
        var character: UInt8
        var length: Int
        var canOpen: Bool
        var canClose: Bool
        var inlText: DocumentStorage.Index
        var previous: Int?
        var next: Int?
    }

    /// Scan a maximal run of `c` (`*` or `_`) starting at `start`, classify its left/right-flanking + can_open/can_close per CommonMark 0.31 §6.2, emit a `.text` node for the run, and (if it can open or close) push a delimiter record onto the stack. Returns the offset just past the run.
    ///
    /// The start of the content (`content.startOffset`) determines whether `start - 1` is a real "before" character or implicitly a newline (start of inline content acts like a line break).
    private mutating func handleDelimRun(char: UInt8, start: Int, end: Int, content: borrowing ContentSpan, parent: DocumentStorage.Index, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?, pendingTextStart: inout Int) throws (MarkdownDocument.Error) -> Int {
        let chunkStart = content.startOffset
        var runEnd = start
        while runEnd < end, content[runEnd] == char {
            runEnd += 1
        }
        
        let count = runEnd - start
        // "Before" character - treat content boundaries as a line break.
        let beforeChar: UInt8 = if start > chunkStart { content[start - 1] } else { UInt8(ascii: "\n") }
        // "After" character - same convention at end of content.
        let afterChar: UInt8 = if runEnd < end { content[runEnd] } else { UInt8(ascii: "\n") }
        
        // NBSP detection: U+00A0 in UTF-8 is `0xC2 0xA0`. The single-byte checks above won't catch it, so peek backward from `start` and forward from `runEnd` to detect the multi-byte sequence.
        let beforeIsNBSP = beforeChar == 0xA0 && start - 2 >= chunkStart && content[start - 2] == 0xC2
        let afterIsNBSP = afterChar == 0xC2 && runEnd + 1 < end && content[runEnd + 1] == 0xA0
        let beforeIsSpace = beforeChar.isASCIISpace || beforeIsNBSP
        let beforeIsPunct = beforeChar.isASCIIPunct
        let afterIsSpace = afterChar.isASCIISpace || afterIsNBSP
        let afterIsPunct = afterChar.isASCIIPunct
        let leftFlanking = !afterIsSpace && (!afterIsPunct || beforeIsSpace || beforeIsPunct)
        let rightFlanking = !beforeIsSpace && (!beforeIsPunct || afterIsSpace || afterIsPunct)
        
        let canOpen: Bool
        let canClose: Bool
        if char == UInt8(ascii: "_") {
            // Intraword `_` is rejected on whichever side has letters/digits.
            canOpen = leftFlanking && (!rightFlanking || beforeIsPunct)
            canClose = rightFlanking && (!leftFlanking || afterIsPunct)
        } else {
            canOpen = leftFlanking
            canClose = rightFlanking
        }
        // Non-flanking run: leave it as part of pending text. Don't emit a text node and don't flush - important so GFM autolink scan-back can later consume these bytes (e.g. `a.b-c_d@a.b` - the `_` mustn't fragment the local-part text).
        if !canOpen && !canClose {
            return runEnd
        }
        // Flush pending text up to the run start, then emit the run as text.
        flushPendingText(
            start: pendingTextStart,
            end: start,
            content: content,
            into: parent
        )
        let runChunk = content.chunk(offset: start, length: count)
        let runRef = storage.intern(runChunk)
        let textIdx = storage.appendNode(NodeRecord(kind: .text, parent: parent, data: .literal(runRef)))
        storage.appendChild(textIdx, to: parent)
        let prev = lastDelim
        let newIdx = delimiters.count
        delimiters.append(DelimiterRecord(
            character: char,
            length: count,
            canOpen: canOpen,
            canClose: canClose,
            inlText: textIdx,
            previous: prev,
            next: nil
        ))
        if let prev {
            delimiters[prev].next = newIdx
        }
        lastDelim = newIdx
        pendingTextStart = runEnd
        return runEnd
    }

    /// Resolve emphasis pairs. Walks forward from the first delimiter above `stackBottom` (use `-1` to process the entire stack). For each closer, looks back for the most recent compatible opener and pairs them via `insertEmph`.
    ///
    /// `openersBottom` is the per-(length%3, char) search-floor optimization: once we fail to find an opener for a closer of a given (length%3, char), no later closer of the same shape needs to look behind that point.
    private mutating func processEmphasis(stackBottom: Int, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?) {
        let doubleTilde = storage.options.contains(.strikethroughDoubleTilde)
        // openersBottom[length % 3, char-index]: 0=`*`, 1=`_`, 2=`~`, 3=`'`, 4=`"`.
        var openersBottom = OpenersBottom(fill: stackBottom)
        // Find the earliest (smallest-index) delimiter strictly above stackBottom.
        var closer: Int? = nil
        var walker = lastDelim
        while let w = walker, w > stackBottom {
            closer = w
            walker = delimiters[w].previous
        }
        while let c = closer {
            if !delimiters[c].canClose {
                closer = delimiters[c].next
                continue
            }
            let closerChar = delimiters[c].character
            let charIdx = charIndex(for: closerChar)
            let lenMod = delimiters[c].length % 3
            // Look backward for first matching opener.
            var opener = delimiters[c].previous
            var openerFound = false
            while let o = opener, o > stackBottom,
                  o >= openersBottom[lenMod, charIdx] {
                if delimiters[o].canOpen
                    && delimiters[o].character == closerChar {
                    let cl = delimiters[c]
                    let op = delimiters[o]
                    if closerChar == UInt8(ascii: "~") {
                        // Strikethrough: lengths must match exactly. With the doubleTilde option, both sides must be exactly 2.
                        if doubleTilde {
                            if op.length == 2 && cl.length == 2 {
                                openerFound = true
                                break
                            }
                        } else if op.length == cl.length {
                            openerFound = true
                            break
                        }
                    } else if !(cl.canOpen || op.canClose)
                        || cl.length % 3 == 0
                        || (op.length + cl.length) % 3 != 0 {
                        openerFound = true
                        break
                    }
                }
                opener = delimiters[o].previous
            }
            let oldCloser = c
            if closerChar == UInt8(ascii: "'") || closerChar == UInt8(ascii: "\"") {
                // Smart quote: the closer is already the right (closing) curly form - `handleQuoteDelim` sets `'`→rightSingleQuote and a `"` closer (which by definition `canClose`)→rightDoubleQuote at creation, so re-interning it here would only move its segment to the pool's end and break the pool-contiguity that `consolidateTextNodes` relies on to merge it with its neighbours (e.g. the apostrophe in `it's`). Only the opener needs its glyph flipped.
                let single = closerChar == UInt8(ascii: "'")
                let next = delimiters[c].next
                if openerFound, let opener {
                    setSmartLiteral(
                        of: delimiters[opener].inlText,
                        single ? Self.leftSingleQuote : Self.leftDoubleQuote
                    )
                    removeDelim(opener, delimiters: &delimiters, lastDelim: &lastDelim)
                    removeDelim(oldCloser, delimiters: &delimiters, lastDelim: &lastDelim)
                }
                closer = next
            } else if openerFound, let opener {
                closer = insertEmph(
                    opener: opener,
                    closer: c,
                    delimiters: &delimiters,
                    lastDelim: &lastDelim
                )
            } else {
                closer = delimiters[c].next
            }
            if !openerFound {
                openersBottom[delimiters[oldCloser].length % 3, charIdx] = oldCloser
                if !delimiters[oldCloser].canOpen {
                    removeDelim(oldCloser, delimiters: &delimiters, lastDelim: &lastDelim)
                }
            }
        }
        // Free remaining delimiters above stackBottom.
        while let last = lastDelim, last > stackBottom {
            removeDelim(last, delimiters: &delimiters, lastDelim: &lastDelim)
        }
    }

    private func charIndex(for c: UInt8) -> Int {
        switch c {
        case UInt8(ascii: "_"): return 1
        case UInt8(ascii: "~"): return 2
        case UInt8(ascii: "'"): return 3
        case UInt8(ascii: "\""): return 4
        default: return 0
        }
    }

    /// Pair `opener` with `closer`, build an `.emphasis` (1-char match) or `.strong` (2-char match) node, reparent the inner siblings into it, trim the matched chars off the opener's and closer's text nodes, remove freed delimiters from the stack, and return the next closer to process (which is `closer.next` if we consumed the closer's text fully, otherwise `closer` itself for another round).
    private mutating func insertEmph(opener: Int, closer: Int, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?) -> Int? {
        let openerInl = delimiters[opener].inlText
        let closerInl = delimiters[closer].inlText
        let openerChar = delimiters[opener].character
        var openerNumChars = literalLength(of: openerInl)
        var closerNumChars = literalLength(of: closerInl)
        let useDelims: Int
        let kind: MarkdownNode.Kind
        if openerChar == UInt8(ascii: "~") {
            // Strikethrough: opener and closer have equal length (enforced by processEmphasis). Consume the entire run from each side.
            useDelims = openerNumChars
            kind = .strikethrough
        } else {
            useDelims = (closerNumChars >= 2 && openerNumChars >= 2) ? 2 : 1
            kind = useDelims == 1 ? .emphasis : .strong
        }
        openerNumChars -= useDelims
        closerNumChars -= useDelims
        // Capture the source span of the consumed delimiters BEFORE trimming the opener/closer literals: the emph/strong node spans from the first consumed opener delimiter to the last consumed closer delimiter (e.g. `*a*` → 1:1-1:3, delimiters included). The opener's delimiters sit at the END of its run; the closer's at the START of its run.
        let openerChunk = literalChunk(of: openerInl)
        let closerChunk = literalChunk(of: closerInl)
        // Sync the remaining length back onto the delimiter records - the rule-of-3 check in `processEmphasis` uses `delimiters[i].length`, and partial-pair matches must reflect the reduced length so a `***` opener with `**` closer leaves a `*` available for later pairing.
        delimiters[opener].length = openerNumChars
        delimiters[closer].length = closerNumChars
        // Trim `useDelims` chars off the END of the opener literal.
        storage.trimLiteral(of: openerInl, trimStart: 0, newLength: openerNumChars)
        // Trim `useDelims` chars off the START of the closer literal.
        storage.trimLiteral(of: closerInl, trimStart: useDelims, newLength: closerNumChars)
        // Free intervening delimiters (their inl_text nodes survive - they become children of the new emph/strong).
        var d = delimiters[closer].previous
        while let dd = d, dd != opener {
            let prev = delimiters[dd].previous
            removeDelim(dd, delimiters: &delimiters, lastDelim: &lastDelim)
            d = prev
        }
        // Build the wrapping node and reparent siblings.
        let parentIdx = storage[openerInl].parent
        let emphIdx = storage.appendNode(NodeRecord(kind: kind, parent: parentIdx))
        // Stamp the source range spanning the consumed delimiters on both ends.
        if let openerChunk, let closerChunk {
            let start = openerChunk.offset + openerChunk.length - useDelims
            let end = closerChunk.offset + useDelims
            stampInline(emphIdx, start, end, inSource: openerChunk.inSource)
        }
        var sibling = storage[openerInl].next
        while let sibling_ = sibling, sibling_ != closerInl {
            let nextSibling = storage[sibling_].next
            storage.unlinkChild(sibling_)
            storage.appendChild(sibling_, to: emphIdx)
            sibling = nextSibling
        }
        storage.insertChildAfter(emphIdx, after: openerInl)
        var resultCloser: Int? = closer
        if openerNumChars == 0 {
            storage.unlinkChild(openerInl)
            removeDelim(opener, delimiters: &delimiters, lastDelim: &lastDelim)
        }
        if closerNumChars == 0 {
            storage.unlinkChild(closerInl)
            let next = delimiters[closer].next
            removeDelim(closer, delimiters: &delimiters, lastDelim: &lastDelim)
            resultCloser = next
        }
        return resultCloser
    }

    private func removeDelim(_ idx: Int, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?) {
        let prev = delimiters[idx].previous
        let next = delimiters[idx].next
        if let prev {
            delimiters[prev].next = next
        }
        if let next {
            delimiters[next].previous = prev
        }
        if idx == lastDelim {
            lastDelim = prev
        }
    }

    private func literalLength(of nodeIdx: DocumentStorage.Index) -> Int {
        if case .literal(let ref) = storage[nodeIdx].data {
            return Int(ref.totalLength)
        }
        return 0
    }

    /// The single-segment `Chunk` (offset/length/inSource) backing a leaf text node, or `nil`. Used to recover a delimiter run's source span for emphasis/strong source-range stamping.
    private func literalChunk(of nodeIdx: DocumentStorage.Index) -> Chunk? {
        if case .literal(let ref) = storage[nodeIdx].data, ref.count >= 1 {
            return storage.chunk(of: ref)
        }
        return nil
    }

    // MARK: - Smart punctuation

    /// UTF-8 bytes for the smart-punctuation replacement characters.
    static let leftSingleQuote: StaticString = "\u{2018}"
    static let rightSingleQuote: StaticString = "\u{2019}"
    static let leftDoubleQuote: StaticString = "\u{201C}"
    static let rightDoubleQuote: StaticString = "\u{201D}"
    static let enDash: StaticString = "\u{2013}"
    static let emDash: StaticString = "\u{2014}"
    static let ellipsis: StaticString = "\u{2026}"

    /// Append a constant UTF-8 byte sequence into the string arena.
    private mutating func appendSmartConstant(_ s: StaticString) {
        let ptr = s.utf8Start
        for k in 0..<s.utf8CodeUnitCount {
            storage.strings.append(ptr[k])
        }
    }

    /// Append a constant UTF-8 byte sequence into the string arena and intern it as a literal content ref.
    private mutating func internSmartLiteral(_ s: StaticString) -> ContentRef {
        let offset = storage.strings.count
        appendSmartConstant(s)
        let chunk = Chunk(offset: offset, length: storage.strings.count - offset, inSource: false)
        return storage.intern(chunk)
    }

    /// Replace a text node's literal with a constant smart-punctuation glyph.
    private mutating func setSmartLiteral(of nodeIdx: DocumentStorage.Index, _ s: StaticString) {
        let ref = internSmartLiteral(s)
        storage[nodeIdx].data = .literal(ref)
    }

    /// Handle a run of `-` under `.smart`. A run of two or more hyphens is decomposed into en/em dashes. A lone hyphen is left in the pending-text region. Returns the offset just past the run.
    private mutating func handleSmartHyphen(start: Int, end: Int, content: borrowing ContentSpan, parent: DocumentStorage.Index, pendingTextStart: inout Int) -> Int {
        var runEnd = start
        while runEnd < end,
              content[runEnd] == UInt8(ascii: "-") {
            runEnd += 1
        }
        let numHyphens = runEnd - start
        if numHyphens < 2 {
            // Lone hyphen: leave it in pending text (identical output, no extra node).
            return runEnd
        }
        var enCount = 0
        var emCount = 0
        if numHyphens % 3 == 0 {
            emCount = numHyphens / 3
        } else if numHyphens % 2 == 0 {
            enCount = numHyphens / 2
        } else if numHyphens % 3 == 2 {
            enCount = 1
            emCount = (numHyphens - 2) / 3
        } else {
            enCount = 2
            emCount = (numHyphens - 4) / 3
        }
        flushPendingText(
            start: pendingTextStart,
            end: start,
            content: content,
            into: parent
        )
        let offset = storage.strings.count
        for _ in 0..<emCount {
            appendSmartConstant(Self.emDash)
        }
        for _ in 0..<enCount {
            appendSmartConstant(Self.enDash)
        }
        let chunk = Chunk(offset: offset, length: storage.strings.count - offset, inSource: false)
        let ref = storage.intern(chunk)
        let textIdx = storage.appendNode(
            NodeRecord(kind: .text, parent: parent, data: .literal(ref))
        )
        storage.appendChild(textIdx, to: parent)
        pendingTextStart = runEnd
        return runEnd
    }

    /// Handle a `'` or `"` under `.smart`. Emits a text node carrying the initial curly form and, if the quote can open or close, pushes a delimiter so `processEmphasis` can resolve the open/close pairing.
    ///
    /// Returns the offset just past the quote.
    private mutating func handleQuoteDelim(char: UInt8, start: Int, end: Int, content: borrowing ContentSpan, parent: DocumentStorage.Index, delimiters: inout UniqueArray<DelimiterRecord>, lastDelim: inout Int?, pendingTextStart: inout Int) throws (MarkdownDocument.Error) -> Int {
        let chunkStart = content.startOffset
        // Quotes are limited to a single delimiter character (unlike `*`/`_`/`~` runs).
        let runEnd = start + 1
        let beforeChar: UInt8 = if start > chunkStart { content[start - 1] } else { UInt8(ascii: "\n") }
        let afterChar: UInt8 = if runEnd < end { content[runEnd] } else { UInt8(ascii: "\n") }
        let beforeIsNBSP = beforeChar == 0xA0 && start - 2 >= chunkStart && content[start - 2] == 0xC2
        let afterIsNBSP = afterChar == 0xC2 && runEnd + 1 < end && content[runEnd + 1] == 0xA0
        let beforeIsSpace = beforeChar.isASCIISpace || beforeIsNBSP
        let beforeIsPunct = beforeChar.isASCIIPunct
        let afterIsSpace = afterChar.isASCIISpace || afterIsNBSP
        let afterIsPunct = afterChar.isASCIIPunct
        let leftFlanking = !afterIsSpace && (!afterIsPunct || beforeIsSpace || beforeIsPunct)
        let rightFlanking = !beforeIsSpace && (!beforeIsPunct || afterIsSpace || afterIsPunct)
        // Quote-specific flanking rules.
        let canOpen = leftFlanking && !rightFlanking && beforeChar != UInt8(ascii: "]") && beforeChar != UInt8(ascii: ")")
        let canClose = rightFlanking
        // Initial curly form: `'` is always a right single quote (apostrophe); `"` is a closing quote when it can close, otherwise an opening quote.
        let literal: StaticString
        if char == UInt8(ascii: "'") {
            literal = Self.rightSingleQuote
        } else {
            literal = canClose ? Self.rightDoubleQuote : Self.leftDoubleQuote
        }
        flushPendingText(
            start: pendingTextStart,
            end: start,
            content: content,
            into: parent
        )
        let ref = internSmartLiteral(literal)
        let textIdx = storage.appendNode(
            NodeRecord(kind: .text, parent: parent, data: .literal(ref))
        )
        storage.appendChild(textIdx, to: parent)
        if canOpen || canClose {
            let prev = lastDelim
            let newIdx = delimiters.count
            delimiters.append(DelimiterRecord(
                character: char,
                // The curly glyph is 3 UTF-8 bytes; recording that as the delimiter length makes the rule-of-three opener check (`length % 3 == 0`) always admit a quote pairing.
                length: 3,
                canOpen: canOpen,
                canClose: canClose,
                inlText: textIdx,
                previous: prev,
                next: nil
            ))
            if let prev {
                delimiters[prev].next = newIdx
            }
            lastDelim = newIdx
        }
        pendingTextStart = runEnd
        return runEnd
    }

    // MARK: - Code spans

    private struct CodeSpanMatch {
        var content: Chunk      // the code-span literal (with one-space-each-side trimmed if applicable)
        var afterClose: Int     // offset just past the closing backtick run
        var backtickCount: Int  // number of backticks in the opening/closing run
    }

    /// Match a code span starting at `start` (which must point at a backtick). Returns the resulting content chunk and the offset just past the closing backtick run, or `nil` if no closing run of equal length exists in `start..<end`.
    private func matchCodeSpan(start: Int, end: Int, content: borrowing ContentSpan) -> CodeSpanMatch? {
        let openEnd = scanBacktickRun(start: start, end: end, content: content)
        let runLength = openEnd - start
        // Find a matching same-length backtick run after `openEnd`.
        var i = openEnd
        while i < end {
            let b = content[i]
            if b == UInt8(ascii: "`") {
                let closeEnd = scanBacktickRun(start: i, end: end, content: content)
                if closeEnd - i == runLength {
                    // Return RAW content; the caller normalizes newlines and applies the single-space-strip rule (in that order) since the strip needs the post-normalize bytes to compare against.
                    let contentChunk = content.chunk(
                        offset: openEnd,
                        length: i - openEnd
                    )
                    return CodeSpanMatch(content: contentChunk, afterClose: closeEnd, backtickCount: runLength)
                }
                i = closeEnd
                continue
            }
            i += 1
        }
        return nil
    }

    /// Scan `start..<end` for the run of backticks beginning at `start`. Returns the offset just past the last consecutive backtick.
    private func scanBacktickRun(start: Int, end: Int, content: borrowing ContentSpan) -> Int {
        var i = start
        while i < end, content[i] == UInt8(ascii: "`") {
            i += 1
        }
        return i
    }

    /// Apply CommonMark's code-span normalization to raw content.
    ///
    /// 1. Replace each `\r\n`, `\r`, or `\n` with a single space.
    /// 2. If the result begins AND ends with a space and isn't all spaces, strip one space from each end.
    ///
    /// Returns either the original chunk (if no changes) or a new chunk pointing at materialized bytes in `storage.strings`.
    private mutating func normalizeCodeSpanContent(_ chunk: Chunk) -> Chunk {
        // Quick scan for newlines.
        var hasNewline = false
        let endOff = chunk.offset + chunk.length
        for i in chunk.offset..<endOff {
            let b = readByte(at: i, in: chunk)
            if b == UInt8(ascii: "\n") || b == UInt8(ascii: "\r") {
                hasNewline = true
                break
            }
        }
        var workChunk: Chunk
        if hasNewline {
            // Materialize with newlines replaced by spaces.
            let outOffset = storage.strings.count
            var i = chunk.offset
            while i < endOff {
                let b = readByte(at: i, in: chunk)
                if b == UInt8(ascii: "\r") {
                    storage.strings.append(UInt8(ascii: " "))
                    i += 1
                    if i < endOff,
                       readByte(at: i, in: chunk) == UInt8(ascii: "\n") {
                        // CRLF: collapse to one space.
                        i += 1
                    }
                    continue
                }
                if b == UInt8(ascii: "\n") {
                    storage.strings.append(UInt8(ascii: " "))
                    i += 1
                    continue
                }
                storage.strings.append(b)
                i += 1
            }
            workChunk = Chunk(
                offset: outOffset,
                length: storage.strings.count - outOffset,
                inSource: false
            )
        } else {
            workChunk = chunk
        }
        // Now apply the single-space-strip rule on the (possibly newline-normalized) chunk.
        return trimSingleSpaces(workChunk)
    }

    /// Apply CommonMark's "code-span single-space-strip" rule.
    ///
    /// If the content is non-empty, begins with a space, ends with a space, and contains at least one non-space byte, strip exactly one space from each end.
    private func trimSingleSpaces(_ chunk: Chunk) -> Chunk {
        let start = chunk.offset
        let end = chunk.range.upperBound
        if start < end,
           readByte(at: start, in: chunk) == UInt8(ascii: " "),
           readByte(at: end - 1, in: chunk) == UInt8(ascii: " ") {
            // Verify there's at least one non-space byte strictly between the two enclosing spaces. For 1- and 2-byte runs there are no inner bytes, so the strip rule doesn't apply.
            let innerStart = start + 1
            let innerEnd = end - 1
            var hasNonSpace = false
            if innerStart < innerEnd {
                for j in innerStart..<innerEnd {
                    let b = readByte(at: j, in: chunk)
                    if b != UInt8(ascii: " ") {
                        hasNonSpace = true
                        break
                    }
                }
            }
            if hasNonSpace {
                return chunk.extracting(1..<(chunk.length - 1))
            }
        }
        return chunk
    }

    // MARK: - Line breaks

    private struct LineBreakInfo {
        var isHard: Bool
        var textEnd: Int  // exclusive end of the pending-text region (excludes the marker bytes)
    }

    /// Decide whether the `\n` at `newlineOffset` is a soft or hard line break. CommonMark 0.31 §6.6 / §6.7:
    /// - Hard if a `\` immediately precedes the newline (with at least one byte in the pending-text region).
    /// - Hard if 2+ spaces immediately precede the newline.
    /// - Soft otherwise.
    /// Returns the kind plus the offset at which to truncate pending text (excluding the marker bytes - backslash or trailing spaces).
    private func classifyLineBreak(at newlineOffset: Int, pendingTextStart: Int, content: borrowing ContentSpan) -> LineBreakInfo {
        // Backslash hard break.
        if newlineOffset > pendingTextStart {
            let prev = content[newlineOffset - 1]
            if prev == UInt8(ascii: "\\") {
                return LineBreakInfo(isHard: true, textEnd: newlineOffset - 1)
            }
        }
        // Trailing-space hard break.
        var i = newlineOffset
        var spaces = 0
        while i > pendingTextStart {
            let prev = content[i - 1]
            if prev == UInt8(ascii: " ") {
                spaces += 1
                i -= 1
            } else {
                break
            }
        }
        if spaces >= 2 {
            return LineBreakInfo(isHard: true, textEnd: i)
        }
        // Soft break: still trim trailing spaces (and tabs) so the rendered output doesn't preserve them.
        var softEnd = newlineOffset
        while softEnd > pendingTextStart {
            let prev = content[softEnd - 1]
            if prev == UInt8(ascii: " ") || prev == UInt8(ascii: "\t") {
                softEnd -= 1
            } else {
                break
            }
        }
        return LineBreakInfo(isHard: false, textEnd: softEnd)
    }

    // MARK: - Autolinks

    private struct AutolinkMatch {
        var interior: Range<Int>  // bytes between `<` and `>` (the visible text)
        var afterClose: Int       // offset just past the closing `>`
        var isEmail: Bool
    }

    /// Try to match an autolink starting at `start` (which points at `<`). CommonMark 0.31 §6.4. URI form first, email form as fallback.
    private func matchAutolink(start: Int, end: Int, content: borrowing ContentSpan) -> AutolinkMatch? {
        if let uri = matchURIAutolink(start: start, end: end, content: content) {
            return uri
        }
        return matchEmailAutolink(start: start, end: end, content: content)
    }

    /// URI autolink: `<scheme:rest>` where scheme is `[A-Za-z][A-Za-z0-9+.-]{1,31}` and rest contains no `<`, `>`, ASCII whitespace, or ASCII control characters.
    private func matchURIAutolink(start: Int, end: Int, content: borrowing ContentSpan) -> AutolinkMatch? {
        var i = start + 1
        if i >= end {
            return nil
        }
        let first = content[i]
        if !first.isASCIILetter {
            return nil
        }
        i += 1
        var schemeChars = 1
        while i < end, schemeChars < 32 {
            let b = content[i]
            let ok = b.isASCIILetter
                || b.isASCIIDigit
                || b == UInt8(ascii: "+")
                || b == UInt8(ascii: ".")
                || b == UInt8(ascii: "-")
            if !ok {
                break
            }
            i += 1
            schemeChars += 1
        }
        // Need at least 2-char scheme and a `:`.
        if schemeChars < 2 || i >= end {
            return nil
        }
        if content[i] != UInt8(ascii: ":") {
            return nil
        }
        i += 1
        // Scan body until `>`.
        let bodyStart = start + 1
        while i < end {
            let b = content[i]
            if b == UInt8(ascii: ">") {
                return AutolinkMatch(
                    interior: bodyStart..<i,
                    afterClose: i + 1,
                    isEmail: false
                )
            }
            if b == UInt8(ascii: "<") || b == UInt8(ascii: " ") || b == UInt8(ascii: "\t")
                || b == UInt8(ascii: "\n") || b == UInt8(ascii: "\r") || b < 0x20 || b == 0x7F {
                return nil
            }
            i += 1
        }
        return nil
    }

    /// Email autolink: a relaxed approximation of the CommonMark email pattern. `<local@domain>` with `local` from a generous punctuation set and `domain` made of dot-separated labels. We don't enforce the full RFC here - pragmatic matches at the cost of some divergence from the spec.
    private func matchEmailAutolink(start: Int, end: Int, content: borrowing ContentSpan) -> AutolinkMatch? {
        var i = start + 1
        let bodyStart = i
        // Local part: 1+ local-allowed chars, no `@`.
        var localChars = 0
        while i < end {
            let b = content[i]
            if b == UInt8(ascii: "@") {
                break
            }
            if !isEmailLocalChar(b) {
                return nil
            }
            i += 1
            localChars += 1
        }
        if localChars == 0 || i >= end {
            return nil
        }
        // `@`
        if content[i] != UInt8(ascii: "@") {
            return nil
        }
        i += 1
        // Domain: 1+ labels separated by `.`. Each label: letter/digit, optional letters/digits/hyphens, ending with letter/digit. Up to 63 chars per label.
        let domainStart = i
        let labelStart = i
        while i < end {
            let b = content[i]
            if b == UInt8(ascii: ">") {
                break
            }
            i += 1
        }
        if i == domainStart || i >= end {
            return nil
        }
        // Validate domain structure.
        if !validateEmailDomain(range: labelStart..<i, content: content) {
            return nil
        }
        _ = labelStart
        return AutolinkMatch(
            interior: bodyStart..<i,
            afterClose: i + 1,
            isEmail: true
        )
    }

    private func isEmailLocalChar(_ b: UInt8) -> Bool {
        if b.isASCIILetter || b.isASCIIDigit {
            return true
        }
        switch b {
        case UInt8(ascii: "."), UInt8(ascii: "!"), UInt8(ascii: "#"), UInt8(ascii: "$"),
             UInt8(ascii: "%"), UInt8(ascii: "&"), UInt8(ascii: "'"), UInt8(ascii: "*"),
             UInt8(ascii: "+"), UInt8(ascii: "/"), UInt8(ascii: "="), UInt8(ascii: "?"),
             UInt8(ascii: "^"), UInt8(ascii: "_"), UInt8(ascii: "`"), UInt8(ascii: "{"),
             UInt8(ascii: "|"), UInt8(ascii: "}"), UInt8(ascii: "~"), UInt8(ascii: "-"):
            return true
        default:
            return false
        }
    }

    private func validateEmailDomain(range: Range<Int>, content: borrowing ContentSpan) -> Bool {
        if range.isEmpty {
            return false
        }
        var i = range.lowerBound
        var labelStart = i
        var labelLen = 0
        while i <= range.upperBound {
            let atEnd = i == range.upperBound
            let b: UInt8 = atEnd ? UInt8(ascii: ".") : content[i]
            if b == UInt8(ascii: ".") {
                // End of label.
                if labelLen == 0 || labelLen > 63 {
                    return false
                }
                // Label can't start or end with hyphen.
                let firstByte = content[labelStart]
                let lastByte = content[i - 1]
                if firstByte == UInt8(ascii: "-") || lastByte == UInt8(ascii: "-") {
                    return false
                }
                if atEnd {
                    return true
                }
                labelStart = i + 1
                labelLen = 0
            } else {
                if !(b.isASCIILetter || b.isASCIIDigit || b == UInt8(ascii: "-")) {
                    return false
                }
                labelLen += 1
            }
            i += 1
        }
        return true
    }

    /// Emit a `.link` node + a single `.text` child for an autolink match.
    ///
    /// For email forms, the URL gets a `mailto:` prefix and is materialized into the string arena. For URI forms, the URL chunk references the original interior bytes directly.
    private mutating func emitAutolink(auto: AutolinkMatch, into parent: DocumentStorage.Index, content: borrowing ContentSpan) {
        let urlChunk: Chunk
        if auto.isEmail {
            // Build `mailto:` + interior into the string arena.
            let offset = storage.strings.count
            let prefix: StaticString = "mailto:"
            let prefixLen = prefix.utf8CodeUnitCount
            let prefixPtr = prefix.utf8Start
            for k in 0..<prefixLen {
                storage.strings.append(prefixPtr[k])
            }
            for j in auto.interior {
                storage.strings.append(content[j])
            }
            // Materialized into the arena, so `inSource: false` regardless of `content`'s buffer.
            urlChunk = Chunk(offset: offset, length: storage.strings.count - offset, inSource: false)
        } else {
            urlChunk = content.chunk(
                offset: auto.interior.lowerBound,
                length: auto.interior.count
            )
        }
        let textChunk = content.chunk(
            offset: auto.interior.lowerBound,
            length: auto.interior.count
        )
        let urlRef = storage.intern(urlChunk)
        let textRef = storage.intern(textChunk)
        let linkIdx = storage.appendNode(
            NodeRecord(
                kind: .link,
                parent: parent,
                data: .link(url: urlRef, title: .empty)
            )
        )
        storage.appendChild(linkIdx, to: parent)
        // The link spans the whole `<…>`; the text child spans just the interior visible bytes.
        stampInline(linkIdx, auto.interior.lowerBound - 1, auto.afterClose, content: content)
        let textIdx = storage.appendNode(
            NodeRecord(kind: .text, parent: linkIdx, data: .literal(textRef))
        )
        storage.appendChild(textIdx, to: linkIdx)
        stampInline(textIdx, auto.interior.lowerBound, auto.interior.upperBound, content: content)
    }

    // MARK: - Raw inline HTML

    /// Match raw inline HTML starting at `start` (which points at `<`). Returns the offset just past the closing `>`, or `nil` if the bytes do not form one of the six accepted patterns:
    ///
    /// - open tag: `<name attrs… />` / `<name>`
    /// - close tag: `</name>`
    /// - comment: `<!--…-->` (and the empty forms `<!-->` / `<!--->`)
    /// - processing instruction: `<?…?>`
    /// - declaration: `<!NAME …>`
    /// - CDATA section: `<![CDATA[…]]>`
    ///
    /// CommonMark 0.31 §6.6.
    private func matchInlineHTML(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        let after = start + 1
        if after >= end {
            return nil
        }
        let c = content[after]
        switch c {
        case UInt8(ascii: "!"):
            return matchHTMLBangForm(start: start, end: end, content: content)
        case UInt8(ascii: "?"):
            return matchHTMLProcessingInstruction(start: start, end: end, content: content)
        case UInt8(ascii: "/"):
            return matchHTMLCloseTag(start: start, end: end, content: content)
        default:
            if c.isASCIILetter {
                return matchHTMLOpenTag(start: start, end: end, content: content)
            }
            return nil
        }
    }

    /// Match an HTML open tag starting at `<`.
    ///
    /// Tagname `[A-Za-z][A-Za-z0-9-]*`, then any number of attributes (each preceded by `spacechar+`), then optional trailing whitespace, optional `/`, then `>`.
    private func matchHTMLOpenTag(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        var i = start + 1
        // Tag name.
        guard let afterName = scanTagName(start: i, end: end, content: content) else {
            return nil
        }
        i = afterName
        // Attributes.
        while i < end {
            let saved = i
            // Need at least one spacechar.
            let afterSpaces = skipSpaceChars(start: i, end: end, content: content)
            if afterSpaces == saved {
                break
            }
            // Then the attribute name (or we may just be skipping trailing whitespace before `/>` / `>`).
            guard let afterAttr = scanAttribute(start: afterSpaces, end: end, content: content) else {
                i = afterSpaces
                break
            }
            i = afterAttr
        }
        // Optional trailing whitespace, optional `/`, then `>`.
        i = skipSpaceChars(start: i, end: end, content: content)
        if i < end, content[i] == UInt8(ascii: "/") {
            i += 1
        }
        if i >= end {
            return nil
        }
        if content[i] != UInt8(ascii: ">") {
            return nil
        }
        return i + 1
    }

    /// Match an HTML close tag `</name spacechar* >` starting at `<`.
    private func matchHTMLCloseTag(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        // Skip the leading `</`.
        var i = start + 2
        guard let afterName = scanTagName(
            start: i, end: end,
            content: content
        ) else {
            return nil
        }
        i = skipSpaceChars(start: afterName, end: end, content: content)
        if i >= end {
            return nil
        }
        if content[i] != UInt8(ascii: ">") {
            return nil
        }
        return i + 1
    }

    /// Dispatch `<!`-prefixed HTML forms: comment, CDATA, declaration.
    private func matchHTMLBangForm(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        // start[0] == '<', start[1] == '!' guaranteed by caller.
        let i = start + 2
        if i >= end {
            return nil
        }
        let next = content[i]
        if next == UInt8(ascii: "-") {
            return matchHTMLComment(start: start, end: end, content: content)
        }
        if next == UInt8(ascii: "[") {
            return matchHTMLCDATA(start: start, end: end, content: content)
        }
        return matchHTMLDeclaration(start: start, end: end, content: content)
    }

    /// Match `<!--…-->`. Accepts the empty forms `<!-->` and `<!--->` per HTML5, then scans for the first `-->` terminator (rejecting NUL bytes in the body).
    private func matchHTMLComment(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        // Need at least `<!--`.
        if start + 4 > end {
            return nil
        }
        if content[start + 2] != UInt8(ascii: "-") || content[start + 3] != UInt8(ascii: "-") {
            return nil
        }
        let bodyStart = start + 4
        // <!-->
        if bodyStart < end, content[bodyStart] == UInt8(ascii: ">") {
            return bodyStart + 1
        }
        // <!--->
        if bodyStart + 1 < end, content[bodyStart] == UInt8(ascii: "-"), content[bodyStart + 1] == UInt8(ascii: ">") {
            return bodyStart + 2
        }
        var i = bodyStart
        while i + 3 <= end {
            let b0 = content[i]
            if b0 == 0 {
                return nil
            }
            if b0 == UInt8(ascii: "-") && content[i + 1] == UInt8(ascii: "-") && content[i + 2] == UInt8(ascii: ">") {
                return i + 3
            }
            i += 1
        }
        return nil
    }

    /// Match `<![CDATA[…]]>`.
    private func matchHTMLCDATA(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        // Need `<![CDATA[`.
        let prefixLen = 9
        if start + prefixLen > end {
            return nil
        }
        let prefix: StaticString = "<![CDATA["
        let prefixPtr = prefix.utf8Start
        for k in 0..<prefixLen {
            if content[start + k] != prefixPtr[k] {
                return nil
            }
        }
        var i = start + prefixLen
        while i + 3 <= end {
            let b0 = content[i]
            if b0 == 0 {
                return nil
            }
            if b0 == UInt8(ascii: "]")
                && content[i + 1] == UInt8(ascii: "]")
                && content[i + 2] == UInt8(ascii: ">") {
                return i + 3
            }
            i += 1
        }
        return nil
    }

    /// Match `<!NAME …>` where NAME is `[A-Z]+`, followed by at least one spacechar, any non-`>` non-NUL chars, then `>`.
    private func matchHTMLDeclaration(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        var i = start + 2
        var nameLen = 0
        while i < end {
            let b = content[i]
            if b.isUppercaseASCIILetter {
                nameLen += 1
                i += 1
            } else {
                break
            }
        }
        if nameLen == 0 {
            return nil
        }
        let afterSpaces = skipSpaceChars(
            start: i, end: end,
            content: content
        )
        if afterSpaces == i {
            return nil
        }
        i = afterSpaces
        while i < end {
            let b = content[i]
            if b == 0 {
                return nil
            }
            if b == UInt8(ascii: ">") {
                return i + 1
            }
            i += 1
        }
        return nil
    }

    /// Match `<?…?>`. Body may be empty; scans for the first `?>` terminator rejecting NUL bytes.
    private func matchHTMLProcessingInstruction(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        var i = start + 2
        while i + 2 <= end {
            let b0 = content[i]
            if b0 == 0 {
                return nil
            }
            if b0 == UInt8(ascii: "?")
                && content[i + 1] == UInt8(ascii: ">") {
                return i + 2
            }
            i += 1
        }
        return nil
    }

    /// Scan `[A-Za-z][A-Za-z0-9-]*`. Returns the offset just past the last tag-name byte, or `nil` if the first byte isn't a letter.
    private func scanTagName(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        if start >= end {
            return nil
        }
        let first = content[start]
        if !first.isASCIILetter {
            return nil
        }
        var i = start + 1
        while i < end {
            let b = content[i]
            let ok = b.isASCIILetter
                || b.isASCIIDigit
                || b == UInt8(ascii: "-")
            if !ok {
                break
            }
            i += 1
        }
        return i
    }

    /// Scan one attribute: `attributename attributevaluespec?` (caller has already consumed the leading `spacechar+`). Returns the offset just past the attribute, or `nil` if no attribute name is present.
    private func scanAttribute(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        // attributename = [a-zA-Z_:][a-zA-Z0-9:._-]*
        if start >= end {
            return nil
        }
        let first = content[start]
        let isFirstChar = first.isASCIILetter || first == UInt8(ascii: "_") || first == UInt8(ascii: ":")
        if !isFirstChar {
            return nil
        }
        var i = start + 1
        while i < end {
            let b = content[i]
            let ok = b.isASCIILetter
                || b.isASCIIDigit
                || b == UInt8(ascii: ":")
                || b == UInt8(ascii: ".")
                || b == UInt8(ascii: "_")
                || b == UInt8(ascii: "-")
            if !ok {
                break
            }
            i += 1
        }
        // Optional value spec: spacechar* '=' spacechar* attributevalue
        let savedAfterName = i
        let afterSpace1 = skipSpaceChars(
            start: i, end: end,
            content: content
        )
        if afterSpace1 < end,
           content[afterSpace1] == UInt8(ascii: "=") {
            let afterEq = afterSpace1 + 1
            let afterSpace2 = skipSpaceChars(
                start: afterEq, end: end,
                content: content
            )
            guard let afterValue = scanAttributeValue(
                start: afterSpace2, end: end,
                content: content
            ) else {
                return nil
            }
            return afterValue
        }
        return savedAfterName
    }

    /// Scan an attribute value: unquoted, single-quoted, or double-quoted.
    private func scanAttributeValue(start: Int, end: Int, content: borrowing ContentSpan) -> Int? {
        if start >= end {
            return nil
        }
        let first = content[start]
        if first == UInt8(ascii: "'") || first == UInt8(ascii: "\"") {
            var i = start + 1
            while i < end {
                let b = content[i]
                if b == 0 {
                    return nil
                }
                if b == first {
                    return i + 1
                }
                i += 1
            }
            return nil
        }
        // Unquoted value: 1+ of [^ \t\r\n\v\f"'=<>`\x00].
        var i = start
        var count = 0
        while i < end {
            let b = content[i]
            if b == 0 {
                break
            }
            if b.isASCIISpace
                || b == UInt8(ascii: "\"")
                || b == UInt8(ascii: "'")
                || b == UInt8(ascii: "=")
                || b == UInt8(ascii: "<")
                || b == UInt8(ascii: ">")
                || b == UInt8(ascii: "`") {
                break
            }
            count += 1
            i += 1
        }
        if count == 0 {
            return nil
        }
        return i
    }

    /// Skip zero or more spacechar bytes. Spacechar = ` `, `\t`, `\n`, `\r`, VT (0x0B), FF (0x0C). Returns the offset just past the run.
    private func skipSpaceChars(start: Int, end: Int, content: borrowing ContentSpan) -> Int {
        var i = start
        while i < end {
            let b = content[i]
            if !b.isASCIISpace {
                break
            }
            i += 1
        }
        return i
    }

    // MARK: - GFM extended autolinks

    /// Form of a matched GFM autolink - affects how the destination URL is built when the node is emitted (`www.` needs a synthetic `http://` prefix; emails need `mailto:`).
    private enum GFMAutolinkForm {
        case uri      // already has http:// or https:// or ftp:// prefix
        case www      // needs http:// synthesized
        case email    // needs mailto: synthesized
    }

    /// Result of a GFM bare-URL / email match. Carries the visible text range (used for the link's child `.text` node) plus the form so the emit step knows whether to synthesize a scheme prefix.
    private struct GFMAutolinkMatch {
        var urlStart: Int
        var urlEnd: Int
        var form: GFMAutolinkForm
    }

    /// Dispatch a GFM autolink trial based on the trigger byte. Returns nil if no autolink starts at / contains `cursor`.
    private func matchGFMAutolink(trigger: UInt8, cursor: Int, end: Int, content: borrowing ContentSpan) -> GFMAutolinkMatch? {
        switch trigger {
        case UInt8(ascii: ":"):
            return matchGFMSchemeAutolink(
                colon: cursor, end: end,
                content: content
            )
        case UInt8(ascii: "w"), UInt8(ascii: "W"):
            return matchGFMWWWAutolink(
                start: cursor, end: end,
                content: content
            )
        case UInt8(ascii: "@"):
            return matchGFMEmailAutolink(
                at: cursor, end: end,
                content: content
            )
        default:
            return nil
        }
    }

    /// `:`-triggered: looks back for `http`/`https`/`ftp`, then forward for `//` and a URL body.
    private func matchGFMSchemeAutolink(colon: Int, end: Int, content: borrowing ContentSpan) -> GFMAutolinkMatch? {
        let chunkStart = content.startOffset
        if colon + 2 >= end {
            return nil
        }
        if content[colon + 1] != UInt8(ascii: "/") || content[colon + 2] != UInt8(ascii: "/") {
            return nil
        }
        guard let schemeStart = matchSchemeBackward(colon: colon, content: content) else {
            return nil
        }
        if schemeStart > chunkStart {
            let pre = content[schemeStart - 1]
            if !isValidGFMPreceding(pre) {
                return nil
            }
        }
        let urlEnd = scanGFMURLBody(start: colon + 3, end: end, content: content)
        let trimmedEnd = trimTrailingPunctuation(urlStart: schemeStart, urlEnd: urlEnd, content: content)
        if trimmedEnd <= colon + 3 {
            return nil
        }
        if !chunkContainsDot(start: colon + 3, end: trimmedEnd, content: content) {
            return nil
        }
        return GFMAutolinkMatch(
            urlStart: schemeStart,
            urlEnd: trimmedEnd,
            form: .uri
        )
    }

    /// Find the start position of `http`, `https`, or `ftp` ending just before `colon`. Returns the scheme's first-byte offset, or nil.
    private func matchSchemeBackward(colon: Int, content: borrowing ContentSpan) -> Int? {
        let chunkStart = content.startOffset
        if colon - 5 >= chunkStart,
           bytesEqual(at: colon - 5, target: "https", content: content) {
            return colon - 5
        }
        if colon - 4 >= chunkStart,
           bytesEqual(at: colon - 4, target: "http", content: content) {
            return colon - 4
        }
        if colon - 3 >= chunkStart,
           bytesEqual(at: colon - 3, target: "ftp", content: content) {
            return colon - 3
        }
        return nil
    }

    /// `w`/`W`-triggered: matches `www.` followed by a URL body.
    private func matchGFMWWWAutolink(start: Int, end: Int, content: borrowing ContentSpan) -> GFMAutolinkMatch? {
        let chunkStart = content.startOffset
        if start > chunkStart {
            let pre = content[start - 1]
            if !isValidGFMPreceding(pre) {
                return nil
            }
        }
        if start + 4 > end {
            return nil
        }
        if !bytesEqual(at: start, target: "www.", content: content) {
            return nil
        }
        let urlEnd = scanGFMURLBody(start: start + 4, end: end, content: content)
        let trimmedEnd = trimTrailingPunctuation(
            urlStart: start, urlEnd: urlEnd,
            content: content
        )
        if trimmedEnd <= start + 4 {
            return nil
        }
        return GFMAutolinkMatch(urlStart: start, urlEnd: trimmedEnd, form: .www)
    }

    /// `@`-triggered: scans backward for the email local part and forward for the domain.
    private func matchGFMEmailAutolink(at: Int, end: Int, content: borrowing ContentSpan) -> GFMAutolinkMatch? {
        let chunkStart = content.startOffset
        var localStart = at
        while localStart > chunkStart {
            let b = content[localStart - 1]
            if isEmailLocalChar(b) {
                localStart -= 1
            } else {
                break
            }
        }
        if localStart == at {
            return nil
        }
        if localStart > chunkStart {
            let pre = content[localStart - 1]
            if !isValidGFMPreceding(pre) {
                return nil
            }
        }
        // Domain: 1+ labels separated by `.`.
        var i = at + 1
        let domainStart = i
        var hasDot = false
        while i < end {
            let b = content[i]
            if b.isASCIILetter || b.isASCIIDigit || b == UInt8(ascii: "-") || b == UInt8(ascii: "_") {
                i += 1
            } else if b == UInt8(ascii: ".") {
                hasDot = true
                i += 1
            } else {
                break
            }
        }
        // Before any trailing-punct trim, the last char of the scanned domain must be alphanumeric or `.`. This is what rejects `a.b-c_d@a.b_` - the trailing `_` is not alpha/`.`, so the whole match dies before we could trim it off.
        if i <= at + 1 {
            return nil
        }
        let preTrimLast = content[i - 1]
        let preTrimAlnumOrDot = preTrimLast.isASCIILetter || preTrimLast.isASCIIDigit || preTrimLast == UInt8(ascii: ".")
        if !preTrimAlnumOrDot {
            return nil
        }
        let trimmedEnd = trimTrailingPunctuation(urlStart: localStart, urlEnd: i, content: content)
        if !hasDot || domainStart == i || trimmedEnd <= at + 1 {
            return nil
        }
        let last = content[trimmedEnd - 1]
        let lastIsAlnum = last.isASCIILetter || last.isASCIIDigit
        if !lastIsAlnum {
            return nil
        }
        // GFM rule: the last domain label must not contain `_` (#631 case 4). Walk back from `trimmedEnd` to find the start of the last label.
        var labelScan = trimmedEnd
        while labelScan > domainStart {
            let prev = content[labelScan - 1]
            if prev == UInt8(ascii: ".") {
                break
            }
            labelScan -= 1
        }
        for k in labelScan..<trimmedEnd {
            if content[k] == UInt8(ascii: "_") {
                return nil
            }
        }
        return GFMAutolinkMatch(urlStart: localStart, urlEnd: trimmedEnd, form: .email)
    }

    /// Emit a `.link` node + a single `.text` child for a GFM autolink match. `www.` and email forms get a synthetic scheme prefix (`http://` or `mailto:`) materialized into the string arena.
    private mutating func emitGFMAutolink(auto: GFMAutolinkMatch, content: borrowing ContentSpan, into parent: DocumentStorage.Index) {
        let urlChunk: Chunk
        switch auto.form {
        case .uri:
            urlChunk = content.chunk(
                offset: auto.urlStart,
                length: auto.urlEnd - auto.urlStart
            )
        case .www:
            urlChunk = materializeAutolinkURL(
                prefix: "http://",
                start: auto.urlStart, end: auto.urlEnd,
                content: content
            )
        case .email:
            urlChunk = materializeAutolinkURL(
                prefix: "mailto:",
                start: auto.urlStart, end: auto.urlEnd,
                content: content
            )
        }
        let textChunk = content.chunk(
            offset: auto.urlStart,
            length: auto.urlEnd - auto.urlStart
        )
        let urlRef = storage.intern(urlChunk)
        let textRef = storage.intern(textChunk)
        let linkIdx = storage.appendNode(NodeRecord(
            kind: .link,
            parent: parent,
            data: .link(url: urlRef, title: .empty)
        ))
        storage.appendChild(linkIdx, to: parent)
        let textIdx = storage.appendNode(NodeRecord(
            kind: .text, parent: linkIdx, data: .literal(textRef)
        ))
        storage.appendChild(textIdx, to: linkIdx)
    }

    /// Append `prefix` + the content bytes of `start..<end` into `storage.strings`, returning a chunk pointing at the appended region.
    ///
    /// The bytes are read from `content` (the scratch/source view, independent of `storage.strings`) so the read region doesn't alias the buffer being appended to.
    private mutating func materializeAutolinkURL(prefix: StaticString, start: Int, end: Int, content: borrowing ContentSpan) -> Chunk {
        let offset = storage.strings.count
        let prefixLen = prefix.utf8CodeUnitCount
        let prefixPtr = prefix.utf8Start
        for k in 0..<prefixLen {
            storage.strings.append(prefixPtr[k])
        }
        for j in start..<end {
            storage.strings.append(content[j])
        }
        return Chunk(
            offset: offset,
            length: storage.strings.count - offset,
            inSource: false
        )
    }

    /// Walk forward accepting non-whitespace, non-`<`, non-`>` bytes.
    private func scanGFMURLBody(
        start: Int,
        end: Int,
        content: borrowing ContentSpan
    ) -> Int {
        var i = start
        while i < end {
            let b = content[i]
            if b.isASCIISpace || b == UInt8(ascii: "<") || b == UInt8(ascii: ">") {
                break
            }
            i += 1
        }
        return i
    }

    /// Peel trailing `.,?:!*_~` and unmatched trailing `)` per the GFM autolink trim rules.
    private func trimTrailingPunctuation(urlStart: Int, urlEnd: Int, content: borrowing ContentSpan) -> Int {
        var i = urlEnd
        var changed = true
        while changed && i > urlStart {
            changed = false
            while i > urlStart {
                let b = content[i - 1]
                switch b {
                case UInt8(ascii: "."), UInt8(ascii: ","), UInt8(ascii: "?"),
                     UInt8(ascii: ":"), UInt8(ascii: "!"), UInt8(ascii: "*"),
                     UInt8(ascii: "_"), UInt8(ascii: "~"):
                    i -= 1
                    changed = true
                default:
                    break
                }
                let stopHere: Bool
                if i <= urlStart {
                    stopHere = true
                } else {
                    let again = content[i - 1]
                    switch again {
                    case UInt8(ascii: "."), UInt8(ascii: ","), UInt8(ascii: "?"),
                         UInt8(ascii: ":"), UInt8(ascii: "!"), UInt8(ascii: "*"),
                         UInt8(ascii: "_"), UInt8(ascii: "~"):
                        stopHere = false
                    default:
                        stopHere = true
                    }
                }
                if stopHere {
                    break
                }
            }
            var open = 0
            var close = 0
            for j in urlStart..<i {
                let b = content[j]
                if b == UInt8(ascii: "(") { open += 1 }
                else if b == UInt8(ascii: ")") { close += 1 }
            }
            while close > open && i > urlStart {
                let b = content[i - 1]
                if b == UInt8(ascii: ")") {
                    i -= 1
                    close -= 1
                    changed = true
                } else {
                    break
                }
            }
            // GFM rule: a trailing `&entity;`-like sequence is treated as separate text. If the URL ends with `;`, scan back for an `&` that delimits an entity candidate (only ASCII letters/digits between them).
            if i > urlStart, content[i - 1] == UInt8(ascii: ";") {
                var k = i - 2
                var ok = true
                while k >= urlStart {
                    let b = content[k]
                    if b == UInt8(ascii: "&") {
                        break
                    }
                    let isAlnum = b.isASCIILetter
                        || b.isASCIIDigit
                    if !isAlnum {
                        ok = false
                        break
                    }
                    k -= 1
                }
                if ok && k >= urlStart,
                   content[k] == UInt8(ascii: "&") {
                    i = k
                    changed = true
                }
            }
        }
        return i
    }

    private func chunkContainsDot(start: Int, end: Int, content: borrowing ContentSpan) -> Bool {
        var i = start
        while i < end {
            if content[i] == UInt8(ascii: ".") {
                return true
            }
            i += 1
        }
        return false
    }

    /// Allowlist of characters that may directly precede a GFM autolink trigger (`http://`, `www.`, `local@host`).
    ///
    /// Only whitespace, `*`, `_`, `~`, `(` count as valid boundaries; everything else (including `<`) disqualifies the autolink so it can't trigger inside an angle-bracket autolink that failed validation.
    private func isValidGFMPreceding(_ b: UInt8) -> Bool {
        switch b {
        case UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"),
             UInt8(ascii: "*"), UInt8(ascii: "_"), UInt8(ascii: "~"), UInt8(ascii: "("):
            return true
        default:
            return false
        }
    }

    /// Compare bytes at `start..(start+target.utf8CodeUnitCount)` against the static-string target.
    private func bytesEqual(at start: Int, target: StaticString, content: borrowing ContentSpan) -> Bool {
        let len = target.utf8CodeUnitCount
        let ptr = target.utf8Start
        for k in 0..<len {
            if content[start + k] != ptr[k] {
                return false
            }
        }
        return true
    }

    /// Append a flat UTF-8 byte array to `bytes` and return a chunk pointing at the appended region.
    private static func appendUTF8Bytes(bytes: Bytes8, count: Int, into out: inout UniqueArray<UInt8>) -> Chunk {
        let offset = out.count
        for i in 0..<count {
            out.append(bytes[i])
        }
        return Chunk(offset: offset, length: count, inSource: false)
    }

    // MARK: - Helpers

    /// Emit a `.text` node spanning `start..<end` if non-empty.
    ///
    /// `rangeEnd` defaults to `end` but may be set larger to extend the node's *source range* past its content - e.g. a hard line break's text node owns the trailing spaces/backslash that were stripped from its content (cmark stamps the text up to the newline), so the content is `[start, end)` while the range is `[start, rangeEnd)`.
    private mutating func flushPendingText(start: Int, end: Int, content: borrowing ContentSpan, into parent: DocumentStorage.Index, rangeEnd: Int? = nil) {
        if end <= start {
            return
        }
        let chunk = content.chunk(offset: start, length: end - start)
        let chunkRef = storage.intern(chunk)
        let textIdx = storage.appendNode(
            NodeRecord(kind: .text, parent: parent, data: .literal(chunkRef))
        )
        storage.appendChild(textIdx, to: parent)
        stampInline(textIdx, start, rangeEnd ?? end, content: content)
    }

    /// Stamp `node`'s source byte range.
    ///
    /// Gated on positions + source-backed content: when the block's inline content is source-backed, the parser's global cursor offsets ARE original-source byte offsets, so a construct bounded by `[start, end)` maps directly. Arena-backed content (multi-line joins) doesn't map to source and is left unstamped (handled separately).
    @inline(__always)
    mutating func stampInline(_ node: DocumentStorage.Index, _ start: Int, _ end: Int, inSource: Bool) {
        if positionsEnabled, inSource {
            storage.setSourceStart(node, start)
            storage.setSourceEnd(node, end)
        }
    }

    /// Stamp `node`'s source range from *virtual* content offsets, resolving each through `content.sourceOffset(ofVirtual:)`.
    ///
    /// This is the multi-segment-aware path: a single-segment source span maps identity (same as the `inSource:` overload), single-segment arena maps to nil (skipped), and a multi-segment span walks its segment list - so a construct inside a multi-line blockquote/list paragraph gets real source positions. `end` is *exclusive* (one past the last byte), so the last content byte `end - 1` is resolved and incremented; this also maps an `end` that lands on the synthetic line-join newline back to just past the preceding source byte.
    @inline(__always)
    mutating func stampInline(_ node: DocumentStorage.Index, _ start: Int, _ end: Int, content: borrowing ContentSpan) {
        guard positionsEnabled, end > start,
              let s = content.sourceOffset(ofVirtual: start),
              let lastByte = content.sourceOffset(ofVirtual: end - 1) else {
            return
        }
        storage.setSourceStart(node, s)
        storage.setSourceEnd(node, lastByte + 1)
    }

    /// Merge runs of adjacent `.text` children into single nodes, recursing into containers.
    ///
    /// Smart-punctuation / entity substitutions emit their replacement as a separate text node (e.g. `"Markdown"` + `"’"` + `"s "`); cmark coalesces them into one text run. The merged node's content is the concatenation of the runs' segments and its source range is their union.
    mutating func consolidateTextNodes(_ parent: DocumentStorage.Index) {
        var child = storage[parent].firstChild
        while let current = child {
            if storage[current].kind == .text {
                // Absorb all immediately-following text siblings into `current`. Stop if a pair can't be merged (non-contiguous segment runs) so the loop always makes progress - otherwise the un-merged sibling would be revisited forever.
                while let next = storage[current].next, storage[next].kind == .text {
                    if !mergeTextNode(next, into: current) {
                        break
                    }
                }
            } else {
                consolidateTextNodes(current)
            }
            child = storage[current].next
        }
    }

    /// Merge `source` into the preceding text node `dest`, unioning their source ranges and unlinking `source`.
    ///
    /// When the two runs are pool-contiguous (the common case for adjacent text) this just widens `dest`'s `ContentRef` - no new segments. Otherwise (e.g. a smart-punctuation glyph re-interned at the pool's end sits between them) it appends copies of both runs' segments as a fresh combined run, so consolidation still merges them.
    @discardableResult
    private mutating func mergeTextNode(_ source: DocumentStorage.Index, into dest: DocumentStorage.Index) -> Bool {
        guard case .literal(let destRef) = storage[dest].data,
              case .literal(let srcRef) = storage[source].data else {
            return false
        }
        if destRef.first + destRef.count == srcRef.first {
            // Pool-contiguous: widen the destination's `ContentRef` in place (no new segments, no intern).
            storage[dest].data = .literal(ContentRef(
                first: destRef.first,
                count: destRef.count + srcRef.count,
                totalLength: destRef.totalLength + srcRef.totalLength
            ))
        } else {
            // Non-contiguous: append copies of both runs' segments to the pool end as a new combined run. Each segment is read into a local before appending, so the read access ends before the mutating append - no aliasing of the growing `segments` pool.
            let newFirst = Int32(storage.segments.count)
            for i in 0..<Int(destRef.count) {
                let seg = storage.segments[Int(destRef.first) + i]
                storage.segments.append(seg)
            }
            for i in 0..<Int(srcRef.count) {
                let seg = storage.segments[Int(srcRef.first) + i]
                storage.segments.append(seg)
            }
            storage[dest].data = .literal(ContentRef(
                first: newFirst,
                count: destRef.count + srcRef.count,
                totalLength: destRef.totalLength + srcRef.totalLength
            ))
        }
        if positionsEnabled {
            let a = storage.sourceRanges[dest]
            let b = storage.sourceRanges[source]
            if a.start >= 0, b.start >= 0 {
                storage.sourceRanges[dest] = DocumentStorage.SourceByteRange(
                    start: min(a.start, b.start),
                    end: max(a.end, b.end)
                )
            } else if a.start < 0 {
                storage.sourceRanges[dest] = b
            }
        }
        storage.unlinkChild(source)
        return true
    }
}
