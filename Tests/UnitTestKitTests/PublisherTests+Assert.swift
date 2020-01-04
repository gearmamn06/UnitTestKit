//
//  File.swift
//
//
//  Created by Sudo.park on 2020/01/04.
//

import XCTest
import Combine

@testable import UnitTestKit

class PublisherTests_Assert: XCTestCase {
    
    private var disposeBag: Set<AnyCancellable>!

    private var publiser: AnyPublisher<Int, Error>!
    private var future: Future<Int, Error>!
    
    private func makeFuture(_ value: Int,
                                 delay: TimeInterval) -> Future<Int, Error> {
        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                promise(.success(value))
            }
        }
    }
    
    private func makePublisher() -> AnyPublisher<Int, Error> {
        let justs = Array(0..<10).map{ Just($0).eraseToAnyPublisher() }
        let seedEvent = Empty<Int, Error>().eraseToAnyPublisher()
        return justs.reduce(into: seedEvent, { acc, just in
            let delayed = just
                .delay(for: .milliseconds(10), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
                .mapError{ _ in NSError(domain: "", code: 0, userInfo: nil) as Error }
            acc = acc.append(delayed).eraseToAnyPublisher()
        })
        .eraseToAnyPublisher()
    }
    
    override func setUp() {
        super.setUp()
        self.disposeBag = []
    }
    
    override func tearDown() {
        self.disposeBag = nil
        super.tearDown()
    }
}


extension PublisherTests_Assert {
    
    func testPublisherAssert_withVerifyingClosure() {
        
        self.makePublisher()
            .assert(count: 10) {
                return $0 == Array(0..<10)
        }
    }
    
    func testPublisherAssert_withVerifyClosureAndExactCount() {
        
        self.makePublisher()
            .assert(count: 10, countExactly: true) {
                return $0 == Array(0..<10)
        }
    }
    
    func testPubliserAssert_whenExpectedEqutableOutputs() {
        
        self.makePublisher()
            .assert(Array(0..<10))
    }
    
    func testPublisherAssert_assertFailureOccur() {
        // given
        struct DummyError: Error {}
        
        // when
        let errorEvent = Future<Int, Error>{ $0(.failure(DummyError())) }
        
        // then
        errorEvent.assertFailure(message: #function) { error in
            return error is DummyError
        }
    }
    
    func testPublisherAssert_afterTrigger() {
        // given
        let publisher = self.makePublisher()
        let trigger = PassthroughSubject<Int, Error>()
        let combined = trigger.prefix(1)
            .append(publisher)
        
        // when
        // then
        combined.assert(Array(-1..<10), trigger: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                trigger.send(-1)
            }
        })
    }
}
