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
                     assert: ([Waiting.Output]) -> Void) {
        
        let waitRsult = self.arrange.waiting
            .wait(take, timeout: timeout, triger: self.action)
        
        switch waitRsult {
        case .success(let _outputs):
            guard let outputs = _outputs else {
                XCTFail("no event occurred")
                return
            }
            assert(outputs)
        
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func then(timeout: TimeInterval = TestConsts.timeout,
                     assert: (Waiting.Output) -> Void) {
        
        let waitResult = self.arrange.waiting
            .wait(1, timeout: timeout, triger: self.action)
        
        switch waitResult {
        case .success(let _outputs):
            guard let output = _outputs?.first else {
                XCTFail("no event occurred")
                return
            }
            assert(output)
        
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func thenFail(take: Int = 1,
                         timeout: TimeInterval = TestConsts.timeout,
                         assert: (Waiting.Failure) -> Void) {
        
        let waitResult = self.arrange.waiting
            .waitFailure(take, timeout: timeout, trigger: self.action)
        
        switch waitResult {
        case .success(let _error):
            guard let error = _error else {
                XCTFail("no failure event occurred")
                return
            }
            assert(error)
            
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func thenFinish(timeout: TimeInterval = TestConsts.timeout,
                           assert: () -> Void) {
        
        let waitResult = self.arrange.waiting
            .waitFinish(timeout: timeout, trigger: self.action)
        
        switch waitResult {
        case .success:
            assert()
            
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
}


extension UnitTestAct where Waiting == Void, Response: Publisher {
    
    public func then(timeout: TimeInterval = TestConsts.timeout,
                     assert: (Response.Output) -> Void) {
        
        let waitRsult = self.action()
            .wait(1, timeout: timeout)
        
        switch waitRsult {
        case .success(let _outputs):
            guard let output = _outputs?.first else {
                XCTFail("no event occurred")
                return
            }
            assert(output)
        
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func then(take: Int,
                     timeout: TimeInterval = TestConsts.timeout,
                     assert: ([Response.Output]) -> Void) {
        
        let waitRsult = self.action()
            .wait(take, timeout: timeout)
        
        switch waitRsult {
        case .success(let _outputs):
            guard let outputs = _outputs else {
                XCTFail("no event occurred")
                return
            }
            assert(outputs)
        
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func thenFail(take: Int = 1,
                         timeout: TimeInterval = TestConsts.timeout,
                         assert: (Response.Failure) -> Void) {
        let waitResult = self.action()
            .waitFailure(take, timeout: timeout)
        
        switch waitResult {
        case .success(let _error):
            guard let error = _error else {
                XCTFail("no failure event occurred")
                return
            }
            assert(error)
            
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
    
    public func thenFinish(timeout: TimeInterval = TestConsts.timeout,
                           assert: () -> Void) {
        let waitResult = self.action()
            .waitFinish(timeout: timeout)
        
        switch waitResult {
        case .success:
            assert()
            
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
    }
}


extension Result where Failure == Never {
    
    public func then(_ assert: (Success) -> Void) {
        switch self {
        case .success(let s):
            assert(s)
        default:
            XCTFail("no assert")
        }
    }
}


enum PubliserWaitError: Error {
    case expectNotFulFill(_ detail: String)
}


extension Publisher {
    
    func wait(_ takeCount: Int,
              timeout: TimeInterval = TestConsts.timeout,
              triger: (() -> Void)? = nil) -> Result<[Output]?, Error> {
        
        let expect = XCTestExpectation()
        
        var outputs: [Output]?
        var subscribing: AnyCancellable?
        
        subscribing = self
            .collect(takeCount)
            .first()
            .sink(receiveCompletion: { complete in
                switch complete {
                case .finished:
                    expect.fulfill()
                default: break
                }
                subscribing?.cancel()
            }, receiveValue: {
                outputs = $0
            })
        
        triger?()
        
        let result = XCTWaiter.wait(for: [expect], timeout: timeout)
        if case .timedOut = result {
            let detail = "publisher not emit \(takeCount) outputs"
            return .failure(PubliserWaitError.expectNotFulFill(detail))
        }
        
        return .success(outputs)
    }
    
    func waitFailure(_ takeCount: Int,
                     timeout: TimeInterval = TestConsts.timeout,
                     trigger: (() -> Void)? = nil) -> Result<Failure?, Error> {
        
        let expect = XCTestExpectation()
        
        var fail: Failure?
        var subscribing: AnyCancellable?
        
        subscribing = self
            .collect(takeCount)
            .first()
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .failure(let error):
                    fail = error
                    expect.fulfill()
                default: break
                }
                subscribing?.cancel()
                
            }, receiveValue: { _ in })
        trigger?()
        
        let result = XCTWaiter.wait(for: [expect], timeout: timeout)
        
        if case .timedOut = result {
            return .failure(PubliserWaitError.expectNotFulFill(""))
        }
        
        return .success(fail)
    }
    
    func waitFinish(timeout: TimeInterval = TestConsts.timeout,
                    trigger: (() -> Void)? = nil) -> Result<Void, Error> {
        
        let expect = XCTestExpectation()
        
        var subscribing: AnyCancellable?
        
        subscribing = self
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .finished:
                    expect.fulfill()
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                }
                subscribing?.cancel()
                
            }, receiveValue: { _ in })
        trigger?()
        
        let result = XCTWaiter.wait(for: [expect], timeout: timeout)
        
        if case .timedOut = result {
            return .failure(PubliserWaitError.expectNotFulFill(""))
        }
        
        return .success(())
    }
}
