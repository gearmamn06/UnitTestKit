//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/02.
//

import Foundation
import XCTest


extension Bool {
    
    public func assert(_ message: String = "",
                       file: StaticString = #file,
                       line: UInt = #line) {
        XCTAssert(self, message, file: file, line: line)
    }
}
