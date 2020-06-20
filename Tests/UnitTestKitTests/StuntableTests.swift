//
//  Stuntable.swift
//  
//
//  Created by Sudo.park on 2020/06/27.
//

import XCTest
import Combine

@testable import UnitTestKit


protocol CollaboratorProtocol {
    
    func method1(arg1: Int, args2: Int)
    
    func method2() -> AnyPublisher<Int, Never>
    
    func method3(arg: Int)
}

class Sut {
    
    private let collaborator: CollaboratorProtocol
    init(collaborator: CollaboratorProtocol) {
        self.collaborator = collaborator
    }
    
    func foo() {
        self.collaborator.method1(arg1: 1, args2: 2)
    }
    
    func bar() -> AnyPublisher<Int, Never> {
        return self.collaborator.method2()
    }
    
    func baz(_ v: Int) {
        self.collaborator.method3(arg: v * 100)
    }
}


class StuntableTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    private var stuntCollaborator: StuntCollaborator!
    private var sut: Sut!

    override func setUp() {
        super.setUp()
        self.cancellables = []
        self.stuntCollaborator = StuntCollaborator()
        self.sut = Sut(collaborator: self.stuntCollaborator)
    }
    
    override func tearDown() {
        self.cancellables = nil
        self.stuntCollaborator = nil
        self.sut = nil
        super.tearDown()
    }
}


// MARK: - Test Spy

extension StuntableTests {
    
    func test_spyCalled() {
        // given
        // when
        self.sut.foo()
        
        // then
        XCTAssertEqual(self.stuntCollaborator.asSpy.called("method1"), true)
        XCTAssertEqual(self.stuntCollaborator.asSpy.called("method2"), false)
        XCTAssertEqual(self.stuntCollaborator.asSpy.called("method3"), false)
    }
    
    func test_spyCallWithArgs() {
        // given
        // when
        self.sut.foo()
        
        // then
        let argsMap = ["arg1": 1, "arg2": 2]
        XCTAssert(self.stuntCollaborator.asSpy.called("method1", withArgs: argsMap))
        XCTAssert(self.stuntCollaborator.asSpy.called("method1", withArgs: { args in
            return (args as? [String: Int]) == argsMap
        }))
    }
    
    func test_spyCalledTimes() {
        // given
        // when
        (0..<10).forEach { _ in
            self.sut.foo()
        }
        
        // then
        XCTAssert(self.stuntCollaborator.asSpy.called("method1", times: 10))
    }
    
    func test_stubResult() {
        // given
        let expect = expectation(description: "스텁된 결과가 방출")
        expect.expectedFulfillmentCount = 10
        var recordedValues = [Int]()
        
        let ints = Array(0..<10).publisher.eraseToAnyPublisher()
        self.stuntCollaborator.asStub.stub("method2", value: ints)
        
        // when
        self.sut.bar()
            .sink { value in
                recordedValues.append(value)
                expect.fulfill()
            }
            .store(in: &self.cancellables)
        self.wait(for: [expect], timeout: 0.01)
        
        // then
        XCTAssert(recordedValues == Array(0..<10))
    }
    
    func test_notStub() {
        // given
        let expect = expectation(description: "bar의 결과로 이벤트가 발생하면 안됨")
        expect.isInverted = true
        
        // when
        self.sut.bar()
            .sink { _ in
                expect.fulfill()
            }
            .store(in: &self.cancellables)
        
        // then
        self.waitForExpectations(timeout: 0.01)
    }
    
    func test_mock() {
        // given
        let expect = expectation(description: "method3가 불려야함")
        
        self.stuntCollaborator.asMock
            .expect("method3") { (args: Int) in
                if args == 100 {
                    expect.fulfill()
                }
            }
        // when
        self.sut.baz(1)
        
        // then
        self.waitForExpectations(timeout: 0.01)
    }
}


extension StuntableTests {
    
    class StuntCollaborator: CollaboratorProtocol, Stuntable {
        
        func method1(arg1: Int, args2: Int) {
            self.spy("method1", args: ["arg1": arg1, "arg2": args2])
        }
        
        func method2() -> AnyPublisher<Int, Never> {
            return self.answer("method2") ?? Empty().eraseToAnyPublisher()
        }
        
        func method3(arg: Int) {
            self.verify(name: "method3", args: arg)
        }
    }
}
