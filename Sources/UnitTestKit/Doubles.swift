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
    
    var spy_wait_prefix: String {
        return "spy_wait_\(self)"
    }

    var stub_prefix: String {
        return "stub_\(self)"
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


// MARK: - Spyable protocol

public protocol Spyable: Containable { }

extension Spyable {

    public func spy(_ name: String) {
        self.spy(name, args: ())
    }
    
    public func spy(_ name: String, args: Any) {
        self.register(name: name.spy_prefix, value: args)
        self.increaseCallCount(name)
        let waitCalling: ((Any) -> Void)? = self.resolve(name: name.spy_wait_prefix,
                                                         mapping: { $0 as? (Any) -> Void })
        waitCalling?(args)
    }

    public func isCalled(_ name: String) -> Bool {
        let callCount = self.calledTimes(name)
        return callCount > 0
    }
    
    public func called<T>(_ name: String, mapping: (Any) -> T?) -> T? {
        return self.resolve(name: name.spy_prefix, mapping: mapping)
    }
    
    public func calledTimes(_ name: String) -> Int {
        let countMap = self.resolve(name: count_key) { $0 as? [String: Int] } ?? [:]
        return countMap[name] ?? 0
    }
    
    public func waitCalled(_ name: String, calledWithArgs: @escaping (Any) -> Void) {
        self.register(name: name.spy_wait_prefix, value: calledWithArgs)
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


// MARK: - Stub

public protocol Stubbale: Containable { }

extension Stubbale {
    
    public func stub(_ name: String, value: Any) {
        self.register(name: name.stub_prefix, value: value)
    }
    
    public func answer<T>(_ name: String) -> T? {
        return self.resolve(name: name.stub_prefix) { $0 as? T }
    }
    
    public func answer<T>(_ name: String, mapping: ((Any) -> T?)) -> T? {
        return self.resolve(name: name.stub_prefix, mapping: mapping)
    }
}
