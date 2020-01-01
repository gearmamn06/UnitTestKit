//
//  File 2.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import XCTest
import Combine


public protocol Expectable {}

public class AsyncClosureExpectation<Closure>: Expectable {
    
    private var closure: Closure
    private let expect = XCTestExpectation(description: "wait")
    
    init(closure: Closure) {
        self.closure = closure
    }
}

public struct ExpectedValue<Value>: Expectable {
    
    private let value: Value
    
    init(_ value: Value) {
        self.value = value
    }
}


public class SpecifiedTestCase: XCTestCase {
    
    private var scheduledAction: (() -> Void)?
    
    override public func setUp() {
        self.scheduledAction = nil
        super.setUp()
    }
    
    override public func tearDown() {
        self.scheduledAction = nil
        super.tearDown()
    }
    
    /// given: setup test
    public func given(_ setUp: () -> Void) -> Self {
        setUp()
        return self
    }
    
    /// when: action for sync mutate state
    public func when(_ action: @escaping () -> Void) -> Self {
        self.scheduledAction = action
        return self
    }
    
    /// when: action for sync result
    public func when<E>(_ action: @escaping () -> E) -> ExpectedValue<E> {
        let result = action()
        return ExpectedValue(result)
    }
    
    /// when: action for async -> result as a publisher
    public func when<P: Publisher>(_ action: @escaping () -> P) -> P {
        return action()
    }
    
    /// when: action fo async -> result in a closure
    public func when<Closure>(_ action: @escaping () -> Closure)
        -> AsyncClosureExpectation<Closure>
    {
        let expectedClosure = action()
        return AsyncClosureExpectation(closure: expectedClosure)
    }
    
    /// then: assertion for sync result
    public func then(_ assert: () -> Void) {
        self.scheduledAction?()
        assert()
    }
}


extension Publisher {
    
    public func then(_ assertion: (Self) -> Void) {
        assertion(self)
    }
}

extension Publisher {
    
    func expectation(_ message: String? = nil) -> XCTestExpectation {
        let message = message ?? "wait for future result"
        let expect = XCTestExpectation(description: message)
        return expect
    }
    
    
    public func assert(takes: Int = 1,
                       message: String? = nil,
                       verify: @escaping (Result<[Output], Failure>) -> Bool) -> AnyCancellable {
        
        let expect = expectation(message)
        
        var outputs: [Output] = []
        return self
        .prefix(takes)
            .sink(receiveCompletion: { complete in
                switch complete {
                case .failure(let error):
                    if verify(.failure(error)) {
                        expect.fulfill()
                    }
                    
                case .finished:
                    if verify(.success(outputs)) {
                        expect.fulfill()
                    }
                }
                
            }, receiveValue: { output in
                outputs.append(output)
            })
    }
    
    public func assert(takes: Int,
                       message: String? = nil,
                       verify: @escaping ([Output]) -> Bool) -> AnyCancellable {
        return self
            .assert(takes: takes, message: message) { (result: Result<[Output], Failure>) in
                switch result {
                case .success(let outputs):
                    return verify(outputs)
                    
                default: break
                }
                return false
        }
    }
}

extension Publisher where Output: Equatable {
    
    public func assert(_ expectedValues: [Output],
                       message: String? = nil) -> AnyCancellable {
        
        let expect = expectation(message)
        
        var outputs: [Output] = []
        return self
            .prefix(expectedValues.count)
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .finished:
                    if outputs == expectedValues {
                        expect.fulfill()
                    }
                    
                default: break
                }
                
            }, receiveValue: { output in
                outputs.append(output)
            })
    }
}

extension Future {
    
    public func assert(_ message: String? = nil,
                       verify: @escaping (Result<Output, Failure>) -> Bool) -> AnyCancellable {
        
        let expect = expectation(message)
        return self
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .failure(let error):
                    if verify(.failure(error)) {
                        expect.fulfill()
                    }
                    
                default: break
                }
                
            }, receiveValue: { output in
                if verify(.success(output)) {
                    expect.fulfill()
                }
            })
    }
    
    public func assert(_ message: String? = nil,
                       verify: @escaping (Output) -> Bool) -> AnyCancellable {
        return self.assert(message) { (result: Result<Output, Failure>) in
            switch result {
            case .success(let output):
                return verify(output)
                
            default: break
            }
            
            return false
        }
    }
    
}

extension Future where Output: Equatable {
    
    public func assert(_ expected: Output,
                       message: String? = nil) -> AnyCancellable {
        
        return self.assert([expected], message: message)
    }
}
