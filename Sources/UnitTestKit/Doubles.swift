//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import Foundation
import Combine


private var baseContainerKey: String = "base_container"

private extension String {
    
    var spy_prefix: String {
        return "spy_\(self)"
    }
    
    var stub_prefix: String {
        return "stub_\(self)"
    }
    
    var mock_prefix: String {
        return "mock_\(self)"
    }
}


// MARK: - container: storable

private class Container {
    
    private var _storage: [String: Any] = [:]
    
    func put(_ key: String, value: Any) {
        self._storage[key] = value
    }
    
    func get(_ key: String) -> Any? {
        return self._storage[key]
    }
    
    var isEmpty: Bool {
        return self._storage.isEmpty
    }
}


// MARK: - containable protocol

public protocol Containable: class {}

extension Containable {
    
    private var container: Container {
        if let value = objc_getAssociatedObject(self, &baseContainerKey) as? Container {
            return value
        }
        let container = Container()
        objc_setAssociatedObject(self,
                                 &baseContainerKey,
                                 container,
                                 objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return container
    }
    
    var isEmpty: Bool {
        return self.container.isEmpty
    }
    
    func register(name: String, value: Any) {
        self.container.put(name, value: value)
    }
    
    func resolve<V>(name: String, mapping: ((Any) -> V?)) -> V? {
        guard let anyValue = self.container.get(name) else {
            return nil
        }
        return mapping(anyValue)
    }
}


// MARK: - Stub

public protocol Stubbale: Containable { }

extension Stubbale {
    
    public func stub(_ name: String) {
        self.register(name: name.stub_prefix, value: ())
    }
    
    public func stub<V>(_ name: String, value: V) {
        self.register(name: name.stub_prefix, value: value)
    }
    
    public func stubResult<S, E>(_ name: String, result: Result<S, E>) {
        self.register(name: name.stub_prefix, value: result)
    }
    
    public func stubFuture<O, E>(_ name: String, future: Future<O, E>) {
        self.register(name: name.stub_prefix, value: future)
    }
    
    public func stubPublisher<P: Publisher>(_ name: String, publisher: P) {
        self.register(name: name.stub_prefix, value: publisher)
    }

    public func answer<V>(_ name: String) -> V? {
        return self.resolve(name: name.stub_prefix) { $0 as? V }
    }
    
    public func answer<V>(_ name: String, mapping: ((Any) -> V?)) -> V? {
        return self.resolve(name: name.stub_prefix, mapping: mapping)
    }
    
    public func answer<S, E: Error>(_ name: String, fallback: Result<S, E>) -> Result<S, E> {
        return self.resolve(name: name.stub_prefix, mapping: { $0 as? Result<S, E>}) ?? fallback
    }
    
    public func answer<O, E: Error>(_ name: String, fallback: Future<O, E>) -> Future<O, E> {
        return self.resolve(name: name.stub_prefix, mapping: { $0 as? Future<O, E> }) ?? fallback
    }
    
    public func answer<P: Publisher>(_ name: String, fallback: P) -> P {
        return self.resolve(name: name.stub_prefix, mapping: { $0 as? P }) ?? fallback
    }
}


// MARK: - Spyable protocol

public protocol Spyable: Containable { }

extension Spyable {
    
    public func record(_ name: String) {
        self.record(name, args: ())
    }
    
    public func record<A>(_ name: String, args: A) {
        self.register(name: name.spy_prefix, value: args)
        self.increaseCallCount(name)
    }
    
    public func called(_ name: String) -> Bool {
        let args = self.resolve(name: name.spy_prefix, mapping: { $0 })
        return args != nil
    }
    
    public func called<A: Equatable>(_ name: String, withArgs: A) -> Bool {
        let args = self.resolve(name: name.spy_prefix, mapping: { $0 as? A })
        return args == withArgs
    }
    
    public func called(_ name: String, withArgs: (Any?) -> Bool) -> Bool {
        let args = self.resolve(name: name.spy_prefix, mapping: { $0 })
        return withArgs(args)
    }
    
    public func called(_ name: String, times: Int) -> Bool {
        let countMap = self.resolve(name: count_key) { $0 as? [String: Int] } ?? [:]
        return countMap[name] == times
    }
}


extension Spyable {
    
    private var count_key: String {
        return ".call_count_key"
    }
    
    private func increaseCallCount(_ name: String) {
        var countMap = self.resolve(name: count_key) { $0 as? [String: Int] } ?? [:]
        countMap[name] = (countMap[name] ?? 0) + 1
        self.register(name: count_key, value: countMap)
    }
}
