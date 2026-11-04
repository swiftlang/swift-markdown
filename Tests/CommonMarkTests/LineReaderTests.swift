/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import BasicContainers
@testable import CommonMark

@Suite("Line Reader Tests")
struct LineReaderTests {
    func collectRangesAndStrings(_ str: String) -> ([Range<Int>], [String]) {
        let utf8 = UniqueArray<UInt8>(copying: str.utf8)
        var reader = LineReader(source: utf8.span)
        var lineRangeOutput: [Range<Int>] = []
        var lineOutput: [String] = []

        while let line = reader.next() {
            lineRangeOutput.append(reader.lineRange)
            var bytes: [UInt8] = []
            for i in 0..<line.count {
                bytes.append(line[i])
            }
            lineOutput.append(String(decoding: bytes, as: UTF8.self))
        }

        return (lineRangeOutput, lineOutput)
    }
    
    @Test("Line counting")
    func lineCounting() {
        let str = "aa\nbb\ncc"
        let expectedRange = [
            0..<2,
            3..<5,
            6..<8
        ]
        
        let expectedLines = ["aa", "bb", "cc"]
        
        let (lineRangeOutput, lineOutput) = collectRangesAndStrings(str)
        #expect(expectedRange == lineRangeOutput)
        #expect(expectedLines == lineOutput)
    }
    
    @Test("CRLF handling")
    func crlfHandling() {
        let str = "aa\r\nbb\rcc"
        let expectedRange = [
            0..<2,
            4..<6,
            7..<9
        ]
        
        let expectedLines = ["aa", "bb", "cc"]
        
        let (lineRangeOutput, lineOutput) = collectRangesAndStrings(str)
        #expect(expectedRange == lineRangeOutput)
        #expect(expectedLines == lineOutput)
    }
    
    @Test("Leading tab")
    func leadingTab() {
        let str = "\tfoo\tbaz\t\tbim\n"
        let expectedRange = [
            0..<13
        ]
        let expectedLines = [
            "\tfoo\tbaz\t\tbim"
        ]
        
        let (lineRangeOutput, lineOutput) = collectRangesAndStrings(str)
        #expect(expectedRange == lineRangeOutput)
        #expect(expectedLines == lineOutput)
    }
}
