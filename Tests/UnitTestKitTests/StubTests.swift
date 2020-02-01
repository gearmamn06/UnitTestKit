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
        self.stub.stubbing("download", value: Result<Int, Error>.success(100).toFuture )
        
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
    
    func testStub_whenStubError_returnError() {
        // given
        struct DownloadError: Error { }
        
        let expect = expectation(description: "resolve stub error as future")
        self.stub.stubbing("download", value: Result<Int, Error>.failure(DownloadError()).toFuture )
        
        // when
        self.stub.download()
            .sink(receiveCompletion: { complete in
                switch complete {
                case .failure(let error):
                    if let _ = error as? DownloadError {
                        expect.fulfill()
                    }
                default: break
                }
            }, receiveValue: { _ in })
            .store(in: &self.disposeBag)
        
        // then
        self.waitForExpectations(timeout: 1)
    }
}


extension StubTests {
    
    class StubObject: Stubbale {
        
        func download() -> Future<Int, Error> {
            return self.stubbedOutput("download") ?? Future{ _ in }
        }
    }
}


private extension Result {
    
    var toFuture: Future<Success, Failure> {
        return Future { promise in
            switch self {
            case .success(let output):
                promise(.success(output))
                
            case .failure(let error):
                promise(.failure(error))
            }
        }
    }
}
