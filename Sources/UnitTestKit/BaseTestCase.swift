//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import XCTest


public protocol TestRule {
    
    associatedtype SUT
    
    var sut: SUT! { get }
    
    func register(spy: Spyable)
    func register(stub: Stubbale)
    
    func spy(_ spyType: Spyable.Type) -> Spyable
    func stub(_ stubType: Stubbale.Type) -> Stubbale
}

open class BaseTestCase: XCTestCase {
    
    public var disposeBag: PublisherDisposeBag!
    public var timeout = TestConsts.timeout
}
