//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

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
    
    
    public func zip<Success, OtherSuccess, Failure>(
        _ other: Future<Result<OtherSuccess, Failure>>
        ) -> Future<Result<(Success, OtherSuccess), Failure>>
        where Response == Result<Success, Failure> {
            
            return self.zipWith(other) { $0.zip($1) }
    }
    
    public func zipWith<Success, OtherSuccess, FinalSuccess, Failure>(
        _ other: Future<Result<OtherSuccess, Failure>>,
        _ combine: @escaping (Success, OtherSuccess) -> FinalSuccess
        ) -> Future<Result<FinalSuccess, Failure>>
        where Response == Result<Success, Failure> {
            
            return self.zipWith(other) { $0.zipWith($1, combine) }
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

// TODO: mapCollection 
