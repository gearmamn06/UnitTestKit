//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import Foundation
import Combine

public class PublishRecorder<Output> {
    
    private var buffers = [Output]()
    private var handler: ((Output) -> Void)?
    
    func receive(_ output: Output) -> Void {
        if let handler = handler {
            handler(output)
        } else {
            buffers.append(output)
        }
    }
    
    public func emitAll(_ channel: @escaping (Output) -> Void) {
        self.buffers.forEach {
            channel($0)
        }
        self.handler = { output in
            channel(output)
        }
    }
}

extension Publisher {
    
    public func record(_ disposeBag: inout Set<AnyCancellable>) -> PublishRecorder<Output> {
        let recorder = PublishRecorder<Output>()
        self.sink(receiveCompletion: { _ in },
                  receiveValue: recorder.receive)
            .store(in: &disposeBag)
        return recorder
    }
}
