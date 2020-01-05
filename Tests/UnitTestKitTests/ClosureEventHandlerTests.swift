//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/05.
//

import XCTest
import Combine

@testable import UnitTestKit


class ClosureEventHandlerTests: BaseTestCase {
    
    private var handler: ClosureEventHandler<Int>!
    
    override func setUp() {
        super.setUp()
        self.handler = ClosureEventHandler()
    }
    
    override func tearDown() {
        self.handler = nil
        super.tearDown()
    }
}


extension ClosureEventHandlerTests {
    
    func testHandler_whenCreateAndConvertToPublisherInLine_aliveInMemory() {
        
        func emitEvent(_ closure: @escaping (Int) -> Void) {
            (0..<10).forEach { int in
                let delay = Double(int) * 0.01
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    closure(int)
                }
            }
        }
        // given
        let expect = expectation(description: "handler가 publisher를 생성하고 구독되는 중에 메모리에 존재하여 이벤트를 전달해야함")
        expect.expectedFulfillmentCount = 10
        
        let handler = ClosureEventHandler<Int>()
        emitEvent(handler.receiver.send)
        
        // when
        var values = [Int]()
        handler.eraseToAnyPublisher()
            .sink(receiveValue: { value in
                values.append(value)
                expect.fulfill()
            })
            .disposed(by: &self.disposeBag)
        
        // then
        self.waitForExpectations(timeout: self.timeout) { _ in
            (values.sorted() == Array(0..<10)).assert()
        }
    }
    
    func testHandler_replayPreviousEvents_whenSubscriptionLater() {
        // given
        let expect = expectation(description: "핸들러가 구독되기 이전에 방출되었던 이벤트들을 함께 방출해야함")
        expect.expectedFulfillmentCount = 10
        
        (0..<10).forEach {
            handler.receiver.send($0)
        }
        
        // when
        var values = [Int]()
        self.handler.eraseToAnyPublisher()
            .sink(receiveValue: { value in
                values.append(value)
                expect.fulfill()
            })
            .disposed(by: &self.disposeBag)
        
        // then
        self.waitForExpectations(timeout: self.timeout) { _ in
            (values == Array(0..<10)).assert()
        }
    }
    
    func testHandler_whenSubscriptionStart_stopBuffering() {
        // given
        
        // when
        handler.eraseToAnyPublisher()
            .sink(receiveValue: { _ in })
            .disposed(by: &self.disposeBag)
        
        // then
        (handler.buffering == nil).assert()
    }
    
    func testHandler_emitAllEventsPreviousAndCurrent() {
        // given
        let expect = expectation(description: "과거와 현재 이벤트 모두 방출")
        expect.expectedFulfillmentCount = 20
        
        var values = [Int]()
        
        // when
        (0..<10).forEach {
            self.handler.receiver.send($0)
        }
        self.handler.eraseToAnyPublisher()
            .sink(receiveValue: { value in
                values.append(value)
                expect.fulfill()
            })
            .disposed(by: &self.disposeBag)
        
        (10..<20).forEach {
            self.handler.receiver.send($0)
        }
        
        // then
        self.waitForExpectations(timeout: self.timeout) { _ in
            (values == Array(0..<20)).assert()
        }
    }
}
