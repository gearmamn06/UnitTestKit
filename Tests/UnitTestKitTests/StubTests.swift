//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import XCTest
import Combine

@testable import UnitTestKit


class StubTests: XCTestCase {
    
    private var disposeBag: Set<AnyCancellable>!
    private var stub: StubObject!
    
    override func setUp() {
        self.disposeBag = []
        self.stub = StubObject()
        super.setUp()
    }
    
    override func tearDown() {
        self.disposeBag = nil
        self.stub = nil
        super.tearDown()
    }
}


extension StubTests {
    
    func testStub_whenStub_returnAsyncStubbingResult() {
        // given
        let expect = expectation(description: "resolve stub value as future")
        self.stub.stub("download", value: Result<Int, Error>.success(100).asFuture().eraseToAnyPublisher())
        
        // when
        self.stub.download()
            .sink(receiveCompletion: { _ in },
                  receiveValue: { value in
                    if value == 100 {
                        expect.fulfill()
                    }
            })
            .store(in: &self.disposeBag)
        
        // then
        self.waitForExpectations(timeout: 1)
    }
    
    func testStub_whenStubbed_returnAnswer() {
        // given
        let expect = expectation(description: "resolve and return answer")
        self.stub.stub("download", value: Result<Int, Error>.success(100).asFuture().eraseToAnyPublisher())
        
        // when
        stub.download()
            .sink(receiveCompletion: { _ in },
                  receiveValue: { value in
                    if value == 100 {
                        expect.fulfill()
                    }
                })
            .store(in: &self.disposeBag)
        
        // then
        self.waitForExpectations(timeout: 1)
    }
    
    func testStub_whenNotStubbed_notReturnAnswer() {
        // given
        let expect = expectation(description: "not return answer")
        expect.isInverted = true
        
        // when
        stub.download()
            .sink(receiveCompletion: { _ in },
                  receiveValue: { value in
                    if value == 100 {
                        expect.fulfill()
                    }
                })
            .store(in: &self.disposeBag)
        
        // then
        self.waitForExpectations(timeout: 0.001)
    }
}


extension StubTests {
    
    class StubObject: Stubbale {
        
        func download() -> AnyPublisher<Int, Error> {
            return self.answer("download") ?? Empty().eraseToAnyPublisher()
        }
    }
}


private extension Result {
    
    func asFuture() -> Future<Success, Failure> {
        return Future { promise in
            promise(self)
        }
    }
}
