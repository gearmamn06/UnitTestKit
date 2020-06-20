//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/01.
//

import Foundation


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

    public func answer<V>(_ name: String) -> V? {
        return self.resolve(name: name.stub_prefix) { $0 as? V }
    }
    
    public func answer<V>(_ name: String, mapping: ((Any) -> V?)) -> V? {
        return self.resolve(name: name.stub_prefix, mapping: mapping)
    }
}


// MARK: - Spyable protocol

public protocol Spyable: Containable { }

extension Spyable {
    
    public func spy(_ name: String) {
        self.spy(name, args: ())
    }
    
    public func spy<A>(_ name: String, args: A) {
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


// MARK: - Mockable

public protocol Mockable: Containable { }

extension Mockable {

    public func expect<V>(_ name: String,
                          verifying: @escaping (V) -> Void) {
        self.register(name: name.mock_prefix, value: verifying)
    }
    
    public func verify<V>(name: String, args: V) {
        let verifying = self.resolve(name: name.mock_prefix) { $0 as? (V) -> Void }
        verifying?(args)
    }
}


// MARK: - Stuntable as Test Double

public protocol Stuntable: Stubbale, Mockable, Spyable { }

extension Stuntable {

    public var asSpy: Spyable {
        return self
    }

    public var asStub: Stubbale {
        return self
    }

    public var asMock: Mockable {
        return self
    }
}
