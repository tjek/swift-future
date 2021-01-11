///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

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
        on queue: DispatchQueue? = nil,
        _ callback: @escaping (Success) -> Void
        ) -> Future
        where Response == Result<Success, Failure> {
            
            return self.mapResult { val in
                if let q = queue {
                    q.async { callback(val) }
                } else {
                    callback(val)
                }
                return val
            }
    }
    
    public func observeResultError<Success, Failure>(
        on queue: DispatchQueue? = nil,
        _ callback: @escaping (Failure) -> Void
        ) -> Future
        where Response == Result<Success, Failure> {
            
            return self.mapResultError { err in
                if let q = queue {
                    q.async { callback(err) }
                } else {
                    callback(err)
                }
                return err
            }
    }
    
    /// Return a non-Result Future, where the failure case is mapped to a success value
    public func replaceError<Success, Failure>(with errorMap: @escaping (Failure) -> Success) -> Future<Success>
        where Response == Result<Success, Failure> {
            return self.map { res in
                switch res {
                case .success(let success):
                    return success
                case .failure(let error):
                    return errorMap(error)
                }
            }
    }
    
    public func eraseToAnyError<Success, Failure>() -> FutureResult<Success>
        where Response == Result<Success, Failure> {
            self.mapResultError({ $0 as Error })
    }
    
    /// By default always retry if the Result is a failure.
    public func retryResult<Success, Failure>(
        times maxRetryCount: Int,
        whileFailure shouldRetryFailure: @escaping (Failure) -> Bool = { _ in true },
        whileSuccess shouldRetrySuccess: @escaping (Success) -> Bool = { _ in false }
    ) -> Future
        where Response == Result<Success, Failure> {
            return self.retry(times: maxRetryCount) {
                switch $0 {
                case .success(let success):
                    return shouldRetrySuccess(success)
                case .failure(let error):
                    return shouldRetryFailure(error)
                }
            }
    }
}

/**
 Performs the array of Futures in series, one after the other.
 
 If _any_ of the futures fail, none of the remaining futures will be performed.
 */
public func batchResult<Success, Failure: Error>(
    _ futures: [Future<Result<Success, Failure>>]
    ) -> Future<Result<[Success], Failure>> {
    
    return futures.reduce(Future<Result<[Success], Failure>>(value: .success([])), { accumFuture, nextFuture in
        accumFuture.flatMapResult { accumResponses in
            nextFuture.mapResult { accumResponses + [$0] }
        }
    })
}

/**
 Performs Future<Result<A>>, then performs Future<Result<B>>, in sequence.
 
 If Future<Result<A>> fails, Future<Result<B>> will never be run.
 Only if all Futures succeed will their success values be combined.
 */
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
    
    return a.flatMapResult { aVal in
        b.mapResult { bVal in
            combine(aVal, bVal)
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
    
    return a.flatMapResult { aVal in
        b.flatMapResult { bVal in
            c.mapResult { cVal in
                combine(aVal, bVal, cVal)
            }
        }
    }
}
