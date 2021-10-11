/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class AtomicCounterTests: XCTestCase {
    func testIncremental() {
        XCTAssertEqual(AtomicCounter.current, AtomicCounter.current)
        XCTAssertNotEqual(AtomicCounter.next(), AtomicCounter.next())
    }

    func testSimultaneousFetch() {
        var counters = Set<UInt64>()
        let group = DispatchGroup()
        let fetchQueue = DispatchQueue(label: "AtomicCounterTests.testSimultaneousFetch.fetch", attributes: [.concurrent])
        let collectQueue = DispatchQueue(label: "AtomicCounterTests.testSimultaneousFetch.collect")
        let numTasks = 4
        let idsPerQueue = 200000
        for _ in 0..<numTasks {
            group.enter()
            fetchQueue.async {
                let ids = (0..<idsPerQueue).map { _ in AtomicCounter.next() }
                collectQueue.sync {
                    for id in ids {
                        counters.insert(id)
                    }
                }
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(numTasks * idsPerQueue, counters.count)
    }
}
