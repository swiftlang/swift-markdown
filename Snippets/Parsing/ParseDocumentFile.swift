// Parse the contents of a file by its ``URL`` without having to read its contents yourself.

import Foundation
import Markdown

// snippet.hide
let inputFileURL = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("test.md")
// snippet.show
let document = try Document(parsing: inputFileURL)

print(document.debugDescription())
// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
