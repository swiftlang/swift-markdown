/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class ListItemContainerTests: XCTestCase {
    
    // MARK: OrderedList
    
    func testOrderedListFromSequence() {
        let expectedItems = (0..<2).map {
            ListItem(Paragraph(Text("\($0)")))
        }
        let ol = OrderedList(expectedItems)
        let gottenItems = Array(ol.listItems)
        XCTAssertEqual(expectedItems.count, gottenItems.count)
        for (expected, gotten) in zip(expectedItems, gottenItems) {
            XCTAssertEqual(expected.detachedFromParent.debugDescription(), gotten.detachedFromParent.debugDescription())
        }
    }

    func testOrderedListWithItems() {
        let items: [ListItem] = [ListItem(Paragraph()), ListItem(ThematicBreak()), ListItem(HTMLBlock(""))]
        var ol = OrderedList(items)
        ol.setListItems(items)
        XCTAssertEqual(3, Array(ol.listItems).count)
        var itemIterator = ol.listItems.makeIterator()
        XCTAssertTrue(itemIterator.next()?.child(at: 0) is Paragraph)
        XCTAssertTrue(itemIterator.next()?.child(at: 0) is ThematicBreak)
        XCTAssertTrue(itemIterator.next()?.child(at: 0) is HTMLBlock)
    }
    
    func testOrderedListReplacingItemsInRange() {
        let list = OrderedList(Array(repeating: ListItem(Paragraph(Text("OK"))), count: 3))
        
        do { // Insert one
            let insertedItem = ListItem(Paragraph(Text("Inserted")))
            var newList = list
            newList.replaceItemsInRange(0..<0, with: CollectionOfOne(insertedItem))
            XCTAssertEqual(insertedItem.debugDescription(), (newList.child(at: 0) as! ListItem).detachedFromParent.debugDescription())
            XCTAssertEqual(4, newList.childCount)
        }
        
        do { // Insert multiple
            let insertedItems = Array(repeating: ListItem(Paragraph(Text("Inserted"))), count: 3)
            var newList = list
            newList.replaceItemsInRange(0..<0, with: insertedItems)
            let expectedDump = """
                OrderedList
                ├─ ListItem
                │  └─ Paragraph
                │     └─ Text "Inserted"
                ├─ ListItem
                │  └─ Paragraph
                │     └─ Text "Inserted"
                ├─ ListItem
                │  └─ Paragraph
                │     └─ Text "Inserted"
                ├─ ListItem
                │  └─ Paragraph
                │     └─ Text "OK"
                ├─ ListItem
                │  └─ Paragraph
                │     └─ Text "OK"
                └─ ListItem
                   └─ Paragraph
                      └─ Text "OK"
                """
            XCTAssertEqual(expectedDump, newList.debugDescription())
            XCTAssertEqual(6, newList.childCount)
        }
        
        do { // Replace one
            let replacementItem = ListItem(Paragraph(Text("Replacement")))
            var newList = list
            newList.replaceItemsInRange(0..<1, with: CollectionOfOne(replacementItem))
            XCTAssertEqual(replacementItem.debugDescription(), (newList.child(at: 0) as! ListItem).detachedFromParent.debugDescription())
            XCTAssertEqual(3, newList.childCount)
        }
        
        do { // Replace many
            let replacementItem = ListItem(Paragraph(Text("Replacement")))
            var newList = list
            newList.replaceItemsInRange(0..<2, with: CollectionOfOne(replacementItem))
            let expectedDump = """
                OrderedList
                ├─ ListItem
                │  └─ Paragraph
                │     └─ Text "Replacement"
                └─ ListItem
                   └─ Paragraph
                      └─ Text "OK"
                """
            XCTAssertEqual(expectedDump, newList.debugDescription())
            XCTAssertEqual(2, newList.childCount)
        }
        
        do { // Replace all
            let replacementItem = ListItem(Paragraph(Text("Replacement")))
            var newList = list
            newList.replaceItemsInRange(0..<3, with: CollectionOfOne(replacementItem))
            let expectedDump = """
                OrderedList
                └─ ListItem
                   └─ Paragraph
                      └─ Text "Replacement"
                """
            XCTAssertEqual(expectedDump, newList.debugDescription())
            XCTAssertEqual(1, newList.childCount)
        }
    }
        
    // MARK: UnorderedList

    func testUnorderedListFromSequence() {
        let expectedItems = (0..<2).map {
            ListItem(Paragraph(Text("\($0)")))
        }
        let ul = UnorderedList(expectedItems)
        let gottenItems = Array(ul.listItems)
        XCTAssertEqual(expectedItems.count, gottenItems.count)
        for (expected, gotten) in zip(expectedItems, gottenItems) {
            XCTAssertEqual(expected.detachedFromParent.debugDescription(), gotten.detachedFromParent.debugDescription())
        }
    }
}
