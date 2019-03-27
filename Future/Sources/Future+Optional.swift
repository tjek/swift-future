//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

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
    
    public func zip<Value, OtherValue>(
        _ other: Future<Optional<OtherValue>>
        ) -> Future<Optional<(Value, OtherValue)>>
        where Response == Optional<Value> {
            
            return self.zipWith(other) { ($0, $1) }
    }
    
    public func zipWith<Value, OtherValue, FinalValue>(
        _ other: Future<Optional<OtherValue>>,
        _ combine: @escaping (Value, OtherValue) -> FinalValue
        ) -> Future<Optional<FinalValue>>
        where Response == Optional<Value> {
            
            return self.zipWith(other) { (a: Value?, b: OtherValue?) -> FinalValue? in
                switch (a, b) {
                case let (value?, otherValue?):
                    return combine(value, otherValue)
                default:
                    return nil
                }
            }
    }
    
    public func observeOptionalSome<Value>(
        _ callback: @escaping (Value) -> Void
        ) -> Future
        where Response == Optional<Value> {
            
            return self.mapOptional {
                callback($0)
                return $0
            }
    }
}
