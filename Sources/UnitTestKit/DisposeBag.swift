//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import Foundation
import Combine


public class PublisherDisposeBag {
    
    fileprivate var cancellables: Set<AnyCancellable> = []
    
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
    
    func disposed(by disposebag: inout PublisherDisposeBag) {
        
        self.store(in: &disposebag.cancellables)
    }
}
