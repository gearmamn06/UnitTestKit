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
    
    var mocking_prefix: String {
        return "mocking_\(self)"
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

public protocol Mocking: Containable { }

extension Mocking {
    
    public func register(_ name: String) {
        self.register(name: name.mocking_prefix, value: ())
    }
    
    public func register<V>(_ name: String, value: V) {
        self.register(name: name.mocking_prefix, value: value)
    }
    
    public func registerResult<S, E>(_ name: String, result: Result<S, E>) {
        self.register(name: name.mocking_prefix, value: result)
    }
    
    public func registerFuture<O, E>(_ name: String, future: Future<O, E>) {
        self.register(name: name.mocking_prefix, value: future)
    }
    
    public func registerPublisher<P: Publisher>(_ name: String, publisher: P) {
        self.register(name: name.mocking_prefix, value: publisher)
    }

    public func resolve<V>(_ name: String) -> V? {
        return self.resolve(name: name.mocking_prefix) { $0 as? V }
    }
    
    public func resolve<V>(_ name: String, mapping: ((Any) -> V?)) -> V? {
        return self.resolve(name: name.mocking_prefix, mapping: mapping)
    }
    
    public func resolve<S, E: Error>(_ name: String, fallback: Result<S, E>) -> Result<S, E> {
        return self.resolve(name: name.mocking_prefix, mapping: { $0 as? Result<S, E>}) ?? fallback
    }
    
    public func resolve<O, E: Error>(_ name: String, fallback: Future<O, E>) -> Future<O, E> {
        return self.resolve(name: name.mocking_prefix, mapping: { $0 as? Future<O, E> }) ?? fallback
    }
    
    public func resolve<P: Publisher>(_ name: String, fallback: P) -> P {
        return self.resolve(name: name.mocking_prefix, mapping: { $0 as? P }) ?? fallback
    }
}


// MARK: - verify called

extension Mocking {
    
    public func verify(_ name: String) {
        self.verify(name, args: ())
    }
    
    public func verify<A>(_ name: String, args: A) {
        self.register(name: name.spy_prefix, value: args)
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
}
