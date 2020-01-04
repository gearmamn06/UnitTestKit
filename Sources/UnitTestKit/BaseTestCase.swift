//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import XCTest


open class BaseTestCase: XCTestCase {
    
    public var disposeBag: PublisherDisposeBag!
    public var timeout = TestConsts.timeout
    
    override open func setUp() {
        super.setUp()
        self.disposeBag = PublisherDisposeBag()
    }
    
    override open func tearDown() {
        self.disposeBag = nil
        super.tearDown()
    }
}
