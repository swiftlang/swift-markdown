// Parse a ``String`` as Markdown.

import Markdown

let source = "Some *Markdown* source"
let document = Document(parsing: source)

print(document.debugDescription())
// snippet.hide
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
