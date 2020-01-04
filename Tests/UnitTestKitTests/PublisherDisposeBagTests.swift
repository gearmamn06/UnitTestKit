//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import XCTest
import Combine

@testable import UnitTestKit


class PublisherDisposeBagTests: XCTestCase {
    
    var subject: PassthroughSubject<Int, Never>!
    var bag: PublisherDisposeBag!
    
    override func setUp() {
        super.setUp()
        bag = PublisherDisposeBag()
        subject = PassthroughSubject()
    }
    
    override func tearDown() {
        bag = nil
        subject = nil
        super.tearDown()
    }
    
    func testBag_append() {
        // given
        let subscribtion = self.subject.sink(receiveValue: { _ in })
        
        // when
        self.bag.append(subscribtion)
        
        // then
        (self.bag.isEmpty == false).assert()
    }
    
    func testBag_whenDeinit_clearAllSubscribtion() {
        // given
        var called = false
        let subscriptions = (0..<10)
            .map { _ in
                self.subject.sink(receiveValue: { _ in
                    called = true
                })
            }
        subscriptions.forEach {
            self.bag.append($0)
        }
        
        // when
        self.bag = nil
        self.subject.send(10)
        
        // then
        (called == false).assert()
    }
    
    func testAnyCancellable_appendToBag() {
        // given
        // when
        self.subject
            .sink(receiveValue: { _ in })
            .disposed(by: &self.bag)
        
        // then
        (self.bag.isEmpty == false).assert()
    }
}
