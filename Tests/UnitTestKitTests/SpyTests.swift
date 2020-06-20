//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import XCTest

@testable import UnitTestKit


class SpyTests: XCTestCase {
    
    private var spy: SpyObject!
    
    override func setUp() {
        super.setUp()
        self.spy = SpyObject()
    }
    
    override func tearDown() {
        self.spy = nil
        super.tearDown()
    }
}


extension SpyTests {
    
    func testSpy_selectedMethodCalled() {
        // when
        spy.method1()

        // then
        XCTAssert(spy.called("method1") == true)
        XCTAssert(spy.called("method2") == false)
    }
    
    func testSpy_methodCalledWithArgs() {
        // when
        spy.method2(int: 100)
        
        // then
        XCTAssert(spy.called("method2", withArgs: 100))
    }
    
    func testSpy_checkCallCount() {
        // given
        // when
        (0..<10).forEach { _ in
            self.spy.method1()
        }
        
        // then
        XCTAssert(spy.called("method1", times: 10))
    }
}


extension SpyTests {
    
    class SpyObject: Spyable {
        
        func method1() {
            self.spy("method1")
        }
        
        func method2(int: Int) {
            self.spy("method2", args: int)
        }
        
        func method3(_ arg1: Int, arg2: String) {
            self.spy("method3", args: [
                "arg1": arg1,
                "arg2": arg2
            ])
        }
    }
}
