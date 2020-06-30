//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import Combine
import XCTest


open class BaseTestCase: XCTestCase {
    
    public var cancellables: Set<AnyCancellable>!
    public var timeout = TestConsts.timeout
    
    override open func setUp() {
        super.setUp()
        self.cancellables = []
    }
    
    override open func tearDown() {
        self.cancellables = nil
        super.tearDown()
    }
}
