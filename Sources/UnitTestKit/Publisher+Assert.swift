//
//  File.swift
//
//
//  Created by Sudo.park on 2020/01/01.
//

import Foundation
import Combine
import XCTest


// MARK: - Publisher assert output

extension Publisher {
    
    public func assert(count: Int = 1,
                       timeout: TimeInterval = TestConsts.timeout,
                       countExactly: Bool = false,
                       message: StaticString = #function,
                       file: StaticString = #file,
                       line: UInt = #line,
                       trigger: (() -> Void)? = nil,
                       compare: ([Output]) -> Bool) {
        
        let expect = XCTestExpectation()
        let expectCount: XCTestExpectation? = countExactly ? XCTestExpectation() : nil
        expectCount?.expectedFulfillmentCount = count
        
        let waiter = XCTWaiter()
        
        var outputs: [Output] = []
        let subscribing = self.prefix(count)
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .failure(let error):
                    XCTFail(error.localizedDescription)
                    
                case .finished:
                    expect.fulfill()
                }
                
            }, receiveValue: { output in
                outputs.append(output)
                expectCount?.fulfill()
            })
        
        let expectations = [expect, expectCount].compactMap{ $0 }

        trigger?()
        waiter.wait(for: expectations, timeout: timeout)
        subscribing.cancel()
        
        (compare(outputs))
            .assert(message: message, file: file, line: line)
    }
}


extension Publisher where Output: Equatable {
    
    public func assert(_ expectedValues: [Output],
                       timeout: TimeInterval = TestConsts.timeout,
                       countExactly: Bool = false,
                       message: StaticString = #function,
                       file: StaticString = #file,
                       line: UInt = #line,
                       trigger: (() -> Void)? = nil) {
        
        self.assert(count: expectedValues.count,
                    timeout: timeout,
                    countExactly: countExactly,
                    message: message,
                    file: file,
                    line: line,
                    trigger: trigger) {
                        $0 == expectedValues
        }
    }
    
}


// MARK: - Publisher assert failure

extension Publisher {
    
    public func assertFailure(count: Int = 1,
                              timeout: TimeInterval = TestConsts.timeout,
                              message: StaticString = #function,
                              file: StaticString = #file,
                              line: UInt = #line,
                              trigger: (() -> Void)? = nil,
                              compareFailure: (Failure) -> Bool) {
        
        let expect = XCTestExpectation()
        let waiter = XCTWaiter()
        
        var failure: Failure?
        
        let subscribing = self.prefix(count)
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .failure(let error):
                    failure = error
                    expect.fulfill()
                    
                default: break
                }
                
            }, receiveValue: { _ in })
        
        trigger?()
        waiter.wait(for: [expect], timeout: timeout)
        subscribing.cancel()
        
        guard let fail = failure else {
            XCTFail("failure not occur, message: \(message)")
            return
        }
        
        (compareFailure(fail))
            .assert(message: message,
                    file: file,
                    line: line)
    }
}
