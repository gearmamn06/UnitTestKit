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
    
    private var dummyError: Error {
        struct DummyError: Error { }
        return DummyError()
    }
    
    func testStub_stubResultAndGetAnswer() {
        // given
        let result: Result<Int, Error> = .success(2)
        self.stub.stubResult("result", result: result)
        
        // when
        let answer: Result<Int, Error> = self.stub.answer("result", fallback: .failure(self.dummyError))
        
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
        self.stub.stubFuture("future", future: future)
        
        // when
        let answer: Future<Int, Error> = self.stub.answer("future", fallback: .init{ $0(.failure(self.dummyError)) })
        
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
