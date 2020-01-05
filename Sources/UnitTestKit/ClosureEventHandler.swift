//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/05.
//

import Foundation
import Combine


public class ClosureEventHandler<T> {
    
    public let receiver = PassthroughSubject<T, Never>()
    
    var buffering: AnyCancellable?
    private var buffer: [T] = []
    
    public init() {
        
        self.startBuffering()
    }
    
    private func startBuffering() {
        
        self.buffering = self.receiver
            .sink(receiveValue: { [weak self] value in
                self?.buffer.append(value)
            })
    }
    
    private func clearBuffering() {
        self.buffering?.cancel()
        self.buffering = nil
    }
    
    deinit {
        self.clearBuffering()
        print("deinit!👹")
    }
}

extension ClosureEventHandler {
    
    func eraseToAnyPublisher() -> AnyPublisher<T, Never> {
        
        let previousEvents = self.buffer.publisher
            .map{ $0 }
            .eraseToAnyPublisher()
        
        let eventsFromNow = self.receiver
            .handleEvents(receiveSubscription: { [weak self] _ in
                self?.clearBuffering()
            })
        
        return previousEvents
            .append(eventsFromNow)
            .eraseToAnyPublisher()
    }
}
