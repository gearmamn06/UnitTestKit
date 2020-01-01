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

public protocol Containable {}

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
    
    func resolve<V>(name: String, mapping: ((Any) -> V?)? = nil) -> V? {
        guard let anyValue = self.container.get(name) else {
            return nil
        }
        if let mapping = mapping {
            return mapping(anyValue)
        }
        return anyValue as? V
    }
}


// MARK: - Spyable protocol

public protocol Spyable: Containable { }

extension Spyable {

    public func spy(_ name: String) {
        self.register(name: name.spy_prefix, value: ())
        self.increaseCallCount(name)
    }
    
    public func spy(_ name: String, args: Any) {
        self.register(name: name.spy_prefix, value: args)
        self.increaseCallCount(name)
    }
    
    public func called(_ name: String) -> Bool {
        if let _ : Void = self.resolve(name: name.spy_prefix) {
            return true
        }
        return false
    }
    
    public func called(_ name: String, times: Int) -> Bool {
        let countMap: [String: Int] = self.resolve(name: count_key) ?? [:]
        return (countMap[name] ?? 0) == times
    }
    
    public func called<A: Equatable>(_ name: String, withArgs: A) -> Bool {
        if let args: A = self.resolve(name: name.spy_prefix) {
            return args == withArgs
        }
        return false
    }
    
    public func called<A>(_ name: String, withArgsVerity: (A) -> Bool) -> Bool {
        if let args: A = self.resolve(name: name.spy_prefix) {
            return withArgsVerity(args)
        }
        return false
    }
}


extension Spyable {
    
    private var count_key: String {
        return ".call_count_key"
    }
    
    private func increaseCallCount(_ name: String) {
        var countMap: [String: Int] = self.resolve(name: count_key) ?? [:]
        countMap[name] = (countMap[name] ?? 0) + 1
        self.register(name: count_key, value: countMap)
    }
}


// MARK: - Helper extensions

extension Bool {
    
    public func then(_ action: () -> Void) {
        if self {
            action()
        }
    }
}
