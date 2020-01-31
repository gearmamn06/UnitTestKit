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
        
        let _values = self.arrange.waiting
            .wait(take, timeout: timeout, triger: self.action)
        guard let values = _values else {
            XCTFail("no event occurred")
            return
        }
        assert(values)
    }
    
    public func then(timeout: TimeInterval = TestConsts.timeout,
                     assert: (Waiting.Output) -> Void) {
        
        let _values = self.arrange.waiting
            .wait(1, timeout: timeout, triger: self.action)
        guard let values = _values, let first = values.first else {
            XCTFail("no event occurred")
            return
        }
        assert(first)
    }
    
    public func thenFail(take: Int = 1,
                         timeout: TimeInterval = TestConsts.timeout,
                         assert: (Waiting.Failure) -> Void) {
        guard let fail = self.arrange.waiting
            .waitFailure(take, timeout: timeout, trigger: self.action) else {
                XCTFail("no event occurred")
                return
        }
        assert(fail)
    }
    
    public func thenFinish(timeout: TimeInterval = TestConsts.timeout,
                           assert: () -> Void) {
        
        self.arrange.waiting
            .waitFinish(timeout: timeout, trigger: self.action)
        
        assert()
    }
}


extension UnitTestAct where Waiting == Void, Response: Publisher {
    
    public func then(timeout: TimeInterval = TestConsts.timeout,
                     assert: (Response.Output) -> Void) {
        let _values = self.action()
            .wait(1, timeout: timeout)
        guard let values = _values, let first = values.first else {
            XCTFail("no event occurred")
            return
        }
        assert(first)
    }
    
    public func then(take: Int,
                     timeout: TimeInterval = TestConsts.timeout,
                     assert: ([Response.Output]) -> Void) {
        let _values = self.action()
            .wait(take, timeout: timeout)
        guard let values = _values else {
            XCTFail("no event occurred")
            return
        }
        assert(values)
    }
    
    public func thenFail(take: Int = 1,
                         timeout: TimeInterval = TestConsts.timeout,
                         assert: (Response.Failure) -> Void) {
        guard let fail = self.action()
            .waitFailure(take, timeout: timeout) else {
                XCTFail("no event occurred")
                return
        }
        assert(fail)
    }
    
    public func thenFinish(timeout: TimeInterval = TestConsts.timeout,
                           assert: () -> Void) {
        self.action()
            .waitFinish(timeout: timeout)
        
        assert()
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

extension Publisher {
    
    func wait(_ takeCount: Int,
              timeout: TimeInterval = TestConsts.timeout,
              triger: (() -> Void)? = nil) -> [Output]? {
        
        let expect = XCTestExpectation()
        let waiter = XCTWaiter()
        
        var outputs: [Output]?
        var subscribing: AnyCancellable?
        
        subscribing = self
            .collect(takeCount)
            .prefix(1)
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
        waiter.wait(for: [expect], timeout: timeout)
        
        return outputs
    }
    
    func waitFailure(_ takeCount: Int,
                     timeout: TimeInterval = TestConsts.timeout,
                     trigger: (() -> Void)? = nil) -> Failure? {
        
        let expect = XCTestExpectation()
        let waiter = XCTWaiter()
        
        var fail: Failure?
        var subscribing: AnyCancellable?
        
        subscribing = self
            .collect(takeCount)
            .prefix(1)
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
        waiter.wait(for: [expect], timeout: timeout)
        
        return fail
    }
    
    func waitFinish(timeout: TimeInterval = TestConsts.timeout,
                    trigger: (() -> Void)? = nil) {
        
        let expect = XCTestExpectation()
        let waiter = XCTWaiter()
        
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
        waiter.wait(for: [expect], timeout: timeout)
    }
}
