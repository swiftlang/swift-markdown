/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#include <stdint.h>

/// The current unique atomic identifier.
uint64_t _cmarkup_current_unique_id(void);

/// Increment the current unique identifier atomically and return it.
uint64_t _cmarkup_increment_and_get_unique_id(void);
