//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

public typealias FutureResult<Value> = Future<Swift.Result<Value, Error>>

extension Future {
    
    public func mapResult<Success, NewSuccess, Failure>(
        _ transform: @escaping (Success) -> NewSuccess
        ) -> Future<Result<NewSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return self.map { $0.map(transform) }
    }
    
    public func mapResultError<Success, Failure, NewFailure>(
        _ transform: @escaping (Failure) -> NewFailure
        ) -> Future<Result<Success, NewFailure>>
        where Response == Result<Success, Failure> {
            
            return self.map { $0.mapError(transform) }
    }
    
    public func flatMapResult<Success, NewSuccess, Failure>(
        _ transform: @escaping (Success) -> Future<Result<NewSuccess, Failure>>
        ) -> Future<Result<NewSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return self.flatMap({ result in
                Future<Result<NewSuccess, Failure>> { callback in
                    switch result {
                    case let .success(s):
                        transform(s).run { callback($0) }
                    case let .failure(error):
                        callback(.failure(error))
                    }
                }
            })
    }
    
    public func flatMapResultError<Success, Failure, NewFailure>(
        _ transform: @escaping (Failure) -> Future<Result<Success, NewFailure>>
        ) -> Future<Result<Success, NewFailure>>
        where Response == Result<Success, Failure> {
            
            return self.flatMap({ result in
                Future<Result<Success, NewFailure>> { callback in
                    switch result {
                    case let .success(s):
                        callback(.success(s))
                    case let .failure(error):
                        transform(error).run { callback($0) }
                    }
                }
            })
    }
    
    public func zippedResult<Success, OtherSuccess, Failure>(
        _ other: Future<Result<OtherSuccess, Failure>>
        ) -> Future<Result<(Success, OtherSuccess), Failure>>
        where Response == Result<Success, Failure> {
            
            return zipResult(self, other)
    }
    
    public func zippedWithResult<Success, OtherSuccess, FinalSuccess, Failure>(
        _ other: Future<Result<OtherSuccess, Failure>>,
        _ combine: @escaping (Success, OtherSuccess) -> FinalSuccess
        ) -> Future<Result<FinalSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return zipResultWith(self, other, combine: combine)
    }
    
    public func observeResultSuccess<Success, Failure>(
        _ callback: @escaping (Success) -> Void
        ) -> Future
        where Response == Result<Success, Failure> {
            
            return self.mapResult {
                callback($0)
                return $0
            }
    }
    
    public func observeResultError<Success, Failure>(
        _ callback: @escaping (Failure) -> Void
        ) -> Future
        where Response == Result<Success, Failure> {
            
            return self.mapResultError {
                callback($0)
                return $0
            }
    }
}

public func zipResult<A, B, Failure>(
    _ a: Future<Result<A, Failure>>,
    _ b: Future<Result<B, Failure>>
    ) -> Future<Result<(A, B), Failure>> {
    
    return zipResultWith(a, b) { ($0, $1) }
}

public func zipResultWith<A, B, FinalSuccess, Failure>(
    _ a: Future<Result<A, Failure>>,
    _ b: Future<Result<B, Failure>>,
    combine: @escaping (A, B) -> FinalSuccess
    ) -> Future<Result<FinalSuccess, Failure>> {
    
    return zipWith(a, b) {
        switch ($0, $1) {
        case let (.success(a), .success(b)):
            return .success(combine(a, b))
        case let (.failure(error), _),
             let (_, .failure(error)):
            return .failure(error)
        }
    }
}

public func zipResult3<A, B, C, Failure>(
    _ a: Future<Result<A, Failure>>,
    _ b: Future<Result<B, Failure>>,
    _ c: Future<Result<C, Failure>>
    ) -> Future<Result<(A, B, C), Failure>> {
    
    return zipResult3With(a, b, c) { ($0, $1, $2) }
}

public func zipResult3With<A, B, C, FinalSuccess, Failure>(
    _ a: Future<Result<A, Failure>>,
    _ b: Future<Result<B, Failure>>,
    _ c: Future<Result<C, Failure>>,
    combine: @escaping (A, B, C) -> FinalSuccess
    ) -> Future<Result<FinalSuccess, Failure>> {
    
    return zip3With(a, b, c) {
        switch ($0, $1, $2) {
        case let (.success(a), .success(b), .success(c)):
            return .success(combine(a, b, c))
        case let (.failure(error), _, _),
             let (_, .failure(error), _),
             let (_, _, .failure(error)):
            return .failure(error)
        }
    }
}
