/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A `MarkupVisitor` with the capability to rewrite elements in the tree.
public protocol MarkupRewriter: MarkupVisitor where Result == Markup? {}

extension MarkupRewriter {
    public mutating func defaultVisit(_ markup: Markup) -> Markup? {
        let newChildren = markup.children.compactMap {
            return self.visit($0)
        }
        return markup.withUncheckedChildren(newChildren)
    }
}
