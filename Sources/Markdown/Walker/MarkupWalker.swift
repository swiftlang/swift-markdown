/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An interface for walking a `Markup` tree without altering it.
public protocol MarkupWalker: MarkupVisitor where Result == Void {}

extension MarkupWalker {
    /// Continue walking by descending in the given element.
    /// 
    /// - Parameter markup: the element whose children the walker should visit.
    public mutating func descendInto(_ markup: Markup) {
        for child in markup.children {
            visit(child)
        }
    }
    public mutating func defaultVisit(_ markup: Markup) {
        descendInto(markup)
    }
}
