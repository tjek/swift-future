//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

public struct Future<Response> {
    public typealias Callback = (Response) -> Void
    public let run: (@escaping Callback) -> Void
    
    public init(run: @escaping (@escaping Callback) -> Void) {
        self.run = run
    }
}

extension Future {
    public init(value: Response) {
        self.init(run: { $0(value) })
    }
    
    public init(work: @escaping () -> Response) {
        self.init(run: { $0(work()) })
    }
}

extension Future {
    
    /**
     Transform the response of the reciever, once it has been run.
     */
    public func map<NewResponse>(
        _ transform: @escaping (Response) -> NewResponse
        ) -> Future<NewResponse> {
        
        return Future<NewResponse> { callback in
            self.run {
                callback(transform($0))
            }
        }
    }
    
    /**
     Transform the response of the reciever into a new future.
     
     This is the equivalent of "and then do this future".
     */
    public func flatMap<NewResponse>(
        _ transform: @escaping (Response) -> Future<NewResponse>
        ) -> Future<NewResponse> {
        
        return Future<NewResponse> { callback in
            self.run {
                transform($0).run(callback)
            }
        }
    }
    
    /**
     Run both the receiver and the other Future, and once both are finished, combines the 2 responses into a tuple.
     */
    public func zipped<OtherResponse>(
        _ other: Future<OtherResponse>
        ) -> Future<(Response, OtherResponse)> {
        
        return zip(self, other)
    }
    
    /**
     Run both the receiver and the other Future, and once both are finished, allows you to combine the 2 responses into a final response type.
     */
    public func zippedWith<OtherResponse, FinalResponse>(
        _ other: Future<OtherResponse>,
        combine: @escaping (Response, OtherResponse) -> FinalResponse
        ) -> Future<FinalResponse> {
        
        return zipWith(self, other, combine: combine)
    }
    
    /**
     Allows you to observe the response of the future, without modifying it.
     */
    public func observe(
        _ callback: @escaping (Response) -> Void
        ) -> Future {
        
        return self.map {
            callback($0)
            return $0
        }
    }
}

extension Future {
    
    public static func async(
        _ future: Future,
        delay: TimeInterval = 0,
        on queue: DispatchQueue,
        blocksQueue: Bool = false,
        completesOn completionQueue: DispatchQueue = .main
        ) -> Future {
        
        return Future { cb in
            queue.asyncAfter(deadline: .now() + delay) {
                let grp: DispatchGroup? = blocksQueue ? DispatchGroup() : nil
                grp?.enter()
                
                future.run { value in
                    grp?.leave()
                    completionQueue.async {
                        cb(value)
                    }
                }
                grp?.wait()
            }
        }
    }
    
    public func async(
        delay: TimeInterval = 0,
        on queue: DispatchQueue,
        blocksQueue: Bool = false,
        completesOn completionQueue: DispatchQueue = .main
        ) -> Future {
        
        return Future.async(
            self,
            delay: delay,
            on: queue,
            blocksQueue: blocksQueue,
            completesOn: completionQueue
        )
    }
    
    public func asyncOnMain() -> Future {
        return self.async(on: .main, completesOn: .main)
    }
}

/**
 Performs the array of Futures in series, one after the other.
 */
public func batch<Response>(
    _ futures: [Future<Response>]
    ) -> Future<[Response]> {
    
    return futures.reduce(Future<[Response]>(value: []), { accumFuture, nextFuture in
        accumFuture.flatMap { accumResponses in
            nextFuture.map { accumResponses + [$0] }
        }
    })
}

public func zip<A, B>(
    _ a: Future<A>,
    _ b: Future<B>
    ) -> Future<(A, B)> {
    
    return zipWith(a, b) { ($0, $1) }
}

/// Performs Future<A>, then Future<B>, and then combines their responses.
public func zipWith<A, B, FinalResponse>(
    _ a: Future<A>,
    _ b: Future<B>,
    combine: @escaping (A, B) -> FinalResponse
    ) -> Future<FinalResponse> {
    
    return Future<FinalResponse> { callback in
        a.run { aVal in
            b.run { bVal in
                callback(combine(aVal, bVal))
            }
        }
    }
}

/// Performs Future<A>, then Future<B>, then Future<C>, and then combines their responses.
public func zip3<A, B, C>(
    _ a: Future<A>,
    _ b: Future<B>,
    _ c: Future<C>
    ) -> Future<(A, B, C)> {
    
    return zip3With(a, b, c) { ($0, $1, $2) }
}

public func zip3With<A, B, C, FinalResponse>(
    _ a: Future<A>,
    _ b: Future<B>,
    _ c: Future<C>,
    combine: @escaping (A, B, C) -> FinalResponse
    ) -> Future<FinalResponse> {
    
    return Future<FinalResponse> { callback in
        a.run { aVal in
            b.run { bVal in
                c.run { cVal in
                    callback(combine(aVal, bVal, cVal))
                }
            }
        }
    }
}

public func parallel<A, B>(
    _ a: Future<A>,
    _ b: Future<B>,
    completesOn completionQueue: DispatchQueue = .main
    ) -> Future<(A, B)> {
    
    return parallelWith(a, b, completesOn: completionQueue) { ($0, $1) }
}

/// Performs Future<A> & Future<B> in parallel on global dispatch queues, and then combines their responses on the specified completionQueue.
public func parallelWith<A, B, FinalResponse>(
    _ fA: Future<A>,
    _ fB: Future<B>,
    completesOn completionQueue: DispatchQueue = .main,
    combine: @escaping (A, B) -> FinalResponse
    ) -> Future<FinalResponse> {
    
    return Future<FinalResponse> { callback in
        
        let maybeCompleted: (A?, B?) -> Void = {
            guard let a = $0, let b = $1 else { return }
            callback(combine(a, b))
        }
        
        var a: A? = nil
        var b: B? = nil
        
        fA.async(on: .global(), completesOn: completionQueue).run {
            a = $0
            maybeCompleted(a, b)
        }
        
        fB.async(on: .global(), completesOn: completionQueue).run {
            b = $0
            maybeCompleted(a, b)
        }
    }
}
