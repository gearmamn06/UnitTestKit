//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import XCTest


open class BaseTestCase: XCTestCase {
    
    public var cancelBag: CancelBag!
    public var timeout = TestConsts.timeout
    
    override open func setUp() {
        super.setUp()
        self.cancelBag = CancelBag()
    }
    
    override open func tearDown() {
        self.cancelBag = nil
        super.tearDown()
    }
}
