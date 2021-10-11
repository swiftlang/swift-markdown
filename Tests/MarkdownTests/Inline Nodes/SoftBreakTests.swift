/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import Markdown

final class SoftBreakTests: XCTestCase {
    /// Tests that creation doesn't crash.
    func testSoftBreak() {
        _ = SoftBreak()
    }
}
