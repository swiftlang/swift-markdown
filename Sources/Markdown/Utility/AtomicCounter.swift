/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import CAtomic

/// A wrapper for a 64-bit unsigned atomic singleton counter.
struct AtomicCounter {
    /// The current counter value.
    static var current: UInt64 {
        return _cmarkup_current_unique_id()
    }

    /// Atomically increment and return the latest counter value.
    static func next() -> UInt64 {
        return _cmarkup_increment_and_get_unique_id()
    }
}
