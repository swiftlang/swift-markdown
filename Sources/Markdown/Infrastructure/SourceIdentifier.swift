/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(Foundation)
import Foundation
public typealias SourceIdentifier = URL
#else
/// Lightweight replacement for URL in Embedded Swift contexts.
public struct SourceIdentifier: Hashable, Sendable {
    public var path: String
    public init(path: String) { self.path = path }
}
#endif
