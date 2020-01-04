//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import XCTest


extension Bool {
    
    public func assert(message: StaticString = #function,
                       file: StaticString = #file,
                       line: UInt = #line) {
        XCTAssert(self, message.description, file: file, line: line)
    }
}

