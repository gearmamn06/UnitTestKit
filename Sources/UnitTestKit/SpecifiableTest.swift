//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import XCTest
import Combine


public struct UnitTestArrange<Waiting> {
    
    let waiting: Waiting
    
    init(_ waiting: Waiting) {
        self.waiting = waiting
    }
}


public struct UnitTestAct<Waiting, Response> {
    
    let arrange: UnitTestArrange<Waiting>
    let action: () -> Response
    
    init(_ arrange: UnitTestArrange<Waiting>, action: @escaping () -> Response) {
        self.arrange = arrange
        self.action = action
    }
}


public protocol SpecifiableTest {}


extension SpecifiableTest {
    
    public func given(_ setup: () -> Void) -> UnitTestArrange<Void> {
        setup()
        return .init(())
    }
    
    public func given<P: Publisher>(wait: P, setup: () -> Void) -> UnitTestArrange<P> {
        setup()
        return UnitTestArrange(wait)
    }
}


extension UnitTestArrange where Waiting: Publisher {
    
    public func when(_ action: @escaping () -> Void) -> UnitTestAct<Waiting, Void> {
        return .init(self, action: action)
    }
}


extension UnitTestArrange where Waiting == Void {
    
    public func whenWait<P: Publisher>(_ action: @escaping () -> P) -> UnitTestAct<Void, P> {
        return .init(self, action: action)
    }
    
    public func when<V>(_ action: () -> V) -> Result<V, Never> {
        let result = Result<V, Never>.success(action())
        return result
    }
}

extension UnitTestAct where Waiting: Publisher, Response == Void {
    
    public func then(take: Int,
                     timeout: TimeInterval = TestConsts.timeout,
                     file: StaticString = #file,
                     line: UInt = #line,
                     assert: ([Waiting.Output]) -> Void) {
        
        let waitRsult = self.arrange.waiting
            .wait(take, timeout: timeout, triger: self.action)
        
        switch waitRsult {
        case .success(let _outputs):
            guard let outputs = _outputs else {
                XCTFail("no event occurred", file: file, line: line)
                return
            }
            assert(outputs)
        
        case .failure(let error):
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }
    
    public func then(timeout: TimeInterval = TestConsts.timeout,
                     file: StaticString = #file,
                     line: UInt = #line,
                     assert: (Waiting.Output) -> Void) {
        
        self.then(take: 1, timeout: timeout, file: file, line: line) { outputs in
            guard let output = outputs.first else {
                XCTFail("no event occurred", file: file, line: line)
                return
            }
            assert(output)
        }
    }
    
    public func thenFail(timeout: TimeInterval = TestConsts.timeout,
                         file: StaticString = #file,
                         line: UInt = #line,
                         assert: (Waiting.Failure) -> Void) {
        
        let waitResult = self.arrange.waiting
            .waitFailure(timeout: timeout, trigger: self.action)
        
        switch waitResult {
        case .success(let _error):
            guard let error = _error else {
                XCTFail("no failure event occurred", file: file, line: line)
                return
            }
            assert(error)
            
        case .failure(let error):
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }
    
    public func thenFinish(timeout: TimeInterval = TestConsts.timeout,
                           file: StaticString = #file,
                           line: UInt = #line,
                           assert: () -> Void) {
        
        let waitResult = self.arrange.waiting
            .waitFinish(timeout: timeout, trigger: self.action)
        
        switch waitResult {
        case .success:
            assert()
            
        case .failure(let error):
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }
}


extension UnitTestAct where Waiting == Void, Response: Publisher {
    
    public func then(timeout: TimeInterval = TestConsts.timeout,
                     file: StaticString = #file,
                     line: UInt = #line,
                     assert: (Response.Output) -> Void) {
        
        self.then(take: 1, timeout: timeout, file: file, line: line) { outputs in
            guard let output = outputs.first else {
                XCTFail("no event occurred", file: file, line: line)
                return
            }
            assert(output)
        }
    }
    
    public func then(take: Int,
                     timeout: TimeInterval = TestConsts.timeout,
                     file: StaticString = #file,
                     line: UInt = #line,
                     assert: ([Response.Output]) -> Void) {
        
        let waitRsult = self.action()
            .wait(take, timeout: timeout)
        
        switch waitRsult {
        case .success(let _outputs):
            guard let outputs = _outputs else {
                XCTFail("no event occurred", file: file, line: line)
                return
            }
            assert(outputs)
        
        case .failure(let error):
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }
    
    public func thenFail(take: Int = 1,
                         timeout: TimeInterval = TestConsts.timeout,
                         file: StaticString = #file,
                         line: UInt = #line,
                         assert: (Response.Failure) -> Void) {
        let waitResult = self.action()
            .waitFailure(timeout: timeout)
        
        switch waitResult {
        case .success(let _error):
            guard let error = _error else {
                XCTFail("no failure event occurred", file: file, line: line)
                return
            }
            assert(error)
            
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func thenFinish(timeout: TimeInterval = TestConsts.timeout,
                           file: StaticString = #file,
                           line: UInt = #line,
                           assert: () -> Void) {
        let waitResult = self.action()
            .waitFinish(timeout: timeout)
        
        switch waitResult {
        case .success:
            assert()
            
        case .failure(let error):
            XCTFail(error.localizedDescription, file: file, line: line)
        }
    }
}


extension Result where Failure == Never {
    
    public func then(file: StaticString = #file, line: UInt = #line, assert: (Success) -> Void) {
        switch self {
        case .success(let s):
            assert(s)
        default:
            XCTFail("no assert", file: file, line: line)
        }
    }
}


enum PubliserWaitError: Error {
    case expectNotFulFill(_ detail: String)
    case unexpectedErrorOccurs(error: Error)
}


extension Publisher {
    
    func wait(_ takeCount: Int,
              timeout: TimeInterval = TestConsts.timeout,
              triger: (() -> Void)? = nil) -> Result<[Output]?, Error> {
        
        let expect = XCTestExpectation()
        expect.expectedFulfillmentCount = takeCount
        
        var actualCount = 0
        
        var outputs: [Output]?
        let valueReceived: (Output) -> Void = { output in
            outputs = (outputs ?? []) + [output]
            actualCount += 1
            expect.fulfill()
        }
        let subscribing: AnyCancellable! = self
            .sink(receiveCompletion: { _ in }, receiveValue: valueReceived)
        triger?()
        
        let result = XCTWaiter.wait(for: [expect], timeout: timeout)
        subscribing?.cancel()
        if case .timedOut = result {
            let detail = "publisher not emit \(takeCount) outputs"
            return .failure(PubliserWaitError.expectNotFulFill(detail))
        }
        
        return .success(outputs)
    }
    
    func waitFailure(timeout: TimeInterval = TestConsts.timeout,
                     trigger: (() -> Void)? = nil) -> Result<Failure?, Error> {
        
        let expect = XCTestExpectation()
        
        var fail: Failure?
        
        let streamEnd: (Subscribers.Completion<Failure>) -> Void = { complete in
            if case let .failure(error) = complete {
                fail = error
            }
            expect.fulfill()
        }
        
        let subscribing: AnyCancellable! = self
            .sink(receiveCompletion: streamEnd, receiveValue: { _ in })
        trigger?()
        
        let result = XCTWaiter.wait(for: [expect], timeout: timeout)
        subscribing?.cancel()
        if case .timedOut = result {
            return .failure(PubliserWaitError.expectNotFulFill(""))
        }
        
        return .success(fail)
    }
    
    func waitFinish(timeout: TimeInterval = TestConsts.timeout,
                    trigger: (() -> Void)? = nil) -> Result<Void, Error> {
        
        let expect = XCTestExpectation()
        var fail: Failure?
        
        let streamEnd: (Subscribers.Completion<Failure>) -> Void = { complete in
            if case let .failure(error) = complete {
                fail = error
            }
            expect.fulfill()
        }
        
        let subscribing: AnyCancellable! = self
            .sink(receiveCompletion: streamEnd, receiveValue: { _ in })
        trigger?()
        
        let result = XCTWaiter.wait(for: [expect], timeout: timeout)
        subscribing?.cancel()
        if case .timedOut = result {
            return .failure(PubliserWaitError.expectNotFulFill(""))
        }
        
        if let error = fail {
            return .failure(PubliserWaitError.unexpectedErrorOccurs(error: error))
        }
        
        return .success(())
    }
}
