/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown

class MarkupVisitorTests: XCTestCase {
    struct IntegerConverter: MarkupVisitor {
        var value: Int
        
        mutating func defaultVisit(_: Markdown.Markup) -> Int {
            defer { value += 1 }
            return value
        }
    }
    
    
    // A compile time check for PAT support
    func testMarkupVisitorPrimaryAssociatedType() {
        var visitor: some MarkupVisitor<Int> = IntegerConverter(value: 1)
        let markup = Text("")
        XCTAssertEqual(visitor.visit(markup), 1)
        XCTAssertEqual(visitor.visit(markup), 2)
        var mappedVisitor: some MarkupVisitor<Int> = visitor.map { $0 * $0 }  
        XCTAssertEqual(mappedVisitor.visit(markup), 9)
        XCTAssertEqual(mappedVisitor.visit(markup), 16)
        XCTAssertEqual(visitor.visit(markup), 3)
    }
}

struct _MappVisitor<A: MarkupVisitor, B>: MarkupVisitor {
    typealias Result = B
    init(visitor: A, _ transform: @escaping (A.Result) -> B) {
        self.visitor = visitor
        self.transform = transform
    }
    private var visitor: A
    private let transform: (A.Result) -> B
    
    mutating func defaultVisit(_ markup: Markdown.Markup) -> B {
        transform(visitor.defaultVisit(markup))
    }
}

extension MarkupVisitor {
    func map<U>(_ transform: @escaping (Self.Result) -> U) -> some MarkupVisitor<U> {
        _MappVisitor(visitor: self, transform)
    }
}
