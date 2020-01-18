//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import Combine


public final class CancelBag {
    
    fileprivate var cancellables: Set<AnyCancellable> = []
    
    public init() {}
    
    deinit {
        self.cancellables.forEach {
            $0.cancel()
        }
        self.cancellables.removeAll()
    }
    
    public func append(_ cancellable: AnyCancellable) {
        self.cancellables.insert(cancellable)
    }
    
    var isEmpty: Bool {
        return self.cancellables.isEmpty
    }
}


extension AnyCancellable {
    
    public func disposed( by cancelBag: CancelBag) {
        cancelBag.cancellables.insert(self)
    }
}
