//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

public typealias FutureOptional<Value> = Future<Optional<Value>>

extension Future {
    
    public func mapOptional<Value, NewValue>(
        _ transform: @escaping (Value) -> NewValue
        ) -> Future<Optional<NewValue>>
        where Response == Optional<Value> {
            
            return self.map { $0.map(transform) }
    }
    
    public func flatMapOptional<Value, NewValue>(
        _ transform: @escaping (Value) -> Future<Optional<NewValue>>
        ) -> Future<Optional<NewValue>>
        where Response == Optional<Value> {
            
            return self.flatMap({ optional in
                Future<Optional<NewValue>> { callback in
                    if let value = optional {
                        transform(value).run(callback)
                    } else {
                        callback(nil)
                    }
                }
            })
    }
    
    public func flatMapOptionalNone<Value>(
        _ transform: @escaping () -> Future<Optional<Value>>
        ) -> Future<Optional<Value>>
        where Response == Optional<Value> {
            
            return self.flatMap({ optional in
                Future<Optional<Value>> { callback in
                    if let value = optional {
                        callback(value)
                    } else {
                        transform().run(callback)
                    }
                }
            })
    }
    
    public func zippedOptional<Value, OtherValue>(
        _ other: Future<Optional<OtherValue>>
        ) -> Future<Optional<(Value, OtherValue)>>
        where Response == Optional<Value> {
            
            return self.zippedWithOptional(other) { ($0, $1) }
    }
    
    public func zippedWithOptional<Value, OtherValue, FinalValue>(
        _ other: Future<Optional<OtherValue>>,
        _ combine: @escaping (Value, OtherValue) -> FinalValue
        ) -> Future<Optional<FinalValue>>
        where Response == Optional<Value> {
            
            return self.zippedWith(other) {
                switch ($0, $1) {
                case let (value?, otherValue?):
                    return combine(value, otherValue)
                default:
                    return nil
                }
            }
    }
    
    public func observeOptionalSome<Value>(
        on queue: DispatchQueue? = nil,
        _ callback: @escaping (Value) -> Void
        ) -> Future
        where Response == Optional<Value> {
            
            return self.mapOptional { val in
                if let q = queue {
                    q.async { callback(val) }
                } else {
                    callback(val)
                }
                return val
            }
    }
    
    /// Return a non-optional Future, where the nil case is mapped to a non-optional value.
    public func replaceNone<Value>(with noneValue: @escaping () -> Value) -> Future<Value>
        where Response == Optional<Value> {
            return self.map { res in
                switch res {
                case let success?:
                    return success
                case nil:
                    return noneValue()
                }
            }
    }
    
    /// Always retry if the optional result is nil, otherwise only when shouldRetry returns true (false by default).
    public func retryOptional<Value>(
        times maxRetryCount: Int,
        while shouldRetry: @escaping (Value) -> Bool = { _ in false }
    ) -> Future
        where Response == Value? {
            return self.retry(times: maxRetryCount) {
                if let val = $0 {
                    return shouldRetry(val)
                } else {
                    return true
                }
            }
    }
    
}
