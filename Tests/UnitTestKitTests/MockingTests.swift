//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import XCTest
import Combine

@testable import UnitTestKit


class MockingTests: XCTestCase {
    
    private var disposeBag: Set<AnyCancellable>!
    private var mock: MockObject!
    
    override func setUp() {
        self.disposeBag = []
        self.mock = MockObject()
        super.setUp()
    }
    
    override func tearDown() {
        self.disposeBag = nil
        self.mock = nil
        super.tearDown()
    }
}


extension MockingTests {
    
    func testStub_whenStub_returnAsyncStubbingResult() {
        // given
        let expect = expectation(description: "resolve stub value as future")
        self.mock.register("download", value: Result<Int, Error>.success(100).asFuture().eraseToAnyPublisher())
        
        // when
        self.mock.download()
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
        self.mock.register("download", value: Result<Int, Error>.success(100).asFuture().eraseToAnyPublisher())
        
        // when
        mock.download()
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
        mock.download()
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
    
    private var dummyError: Error {
        struct DummyError: Error { }
        return DummyError()
    }
    
    func testStub_stubResultAndGetAnswer() {
        // given
        let result: Result<Int, Error> = .success(2)
        self.mock.registerResult("result", result: result)
        
        // when
        let answer: Result<Int, Error> = self.mock.resolve("result", fallback: .failure(self.dummyError))
        
        // then
        if case let .success(value) = answer, value == 2 {
            XCTAssert(true)
        } else {
            XCTFail()
        }
    }
    
    func testStub_stubFutureAndGetAnswer() {
        // given
        let expect = expectation(description: "get answer stubbed value as future")
        let future: Future<Int, Error> = .init{ $0(.success(2)) }
        self.mock.registerFuture("future", future: future)
        
        // when
        let answer: Future<Int, Error> = self.mock.resolve("future", fallback: .init{ $0(.failure(self.dummyError)) })
        
        // then
        _ = answer
            .sink(receiveCompletion: { _ in },
                  receiveValue: { value in
                    expect.fulfill()
                    XCTAssertEqual(value, 2)
                  })
        self.waitForExpectations(timeout: 1)
    }
}


extension MockingTests {
    
    class MockObject: Mocking {
        
        func download() -> AnyPublisher<Int, Error> {
            return self.resolve("download") ?? Empty().eraseToAnyPublisher()
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
