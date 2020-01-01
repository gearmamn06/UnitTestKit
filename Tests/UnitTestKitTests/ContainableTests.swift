//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import XCTest

@testable import UnitTestKit


class ContainableTests: XCTestCase {
    
    var container: DummyContainer!
    
    override func setUp() {
        super.setUp()
        self.container = DummyContainer()
    }
    
    override func tearDown() {
        self.container = nil
        super.tearDown()
    }
}


// MARK: Test initial state

extension ContainableTests {
    
    func testContainer_whenInitialState_isEmpty() {
        XCTAssert(container.isEmpty)
    }
    
    func testContainer_whenResused_isEmpty() {
        // given
        container.register(name: "key1", value: 1)
        container.register(name: "key2", value: 2)
        
        // when
        container = DummyContainer()
        
        // then
        XCTAssert(container.isEmpty)
    }
}


// MARK: Test put and get

extension ContainableTests {
    
    private func registerData() {
        container.register(name: "k1", value: 1)
        container.register(name: "k2", value: "dummy_string")
    }
    
    func testContainer_whenSomeDataRegistered_isNotEmpty() {
        // given
        registerData()
        
        // then
        XCTAssert(container.isEmpty == false)
    }
    
    func testContainer_whenSomeDataRegistered_dataIsResolvable() {
        // given
        registerData()
        
        // when
        let intValue: Int? = container.resolve(name: "k1")
        let stringValue: String? = container.resolve(name: "k2")
        
        // then
        XCTAssert(intValue == 1)
        XCTAssert(stringValue == "dummy_string")
    }
    
    func testContainer_whenResolveWithCustomMapping_dataIsResolvable() {
        // given
        let dictionary: [String: Any] = [
            "k1": 1,
            "k2": "dummy_string"
        ]
        container.register(name: "args", value: dictionary)
        
        // when
        let stringValue: String? = container.resolve(name: "args") { args in
            guard let dic = args as? [String: Any] else {
                return nil
            }
            return dic["k2"] as? String
        }
        
        // then
        XCTAssert(stringValue == "dummy_string")
    }
    
    func testContainer_whenNoMatchedDataExists_returnNil() {
        // given
        registerData()
        
        // when
        let intValue: Int? = container.resolve(name: "wrong_key")
        
        // then
        XCTAssert(intValue == nil)
    }
}


extension ContainableTests {
    
    class DummyContainer: Containable {}
}
