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
     The completion callback is performed on the `completionQueue`, which is `.main` by default. default.
     */
    public func zipped<OtherResponse>(
        _ other: Future<OtherResponse>
        ) -> Future<(Response, OtherResponse)> {
        
        return zip(self, other)
    }
    
    /**
     Run both the receiver and the other Future, and once both are finished, allows you to combine the 2 responses into a final response type.
     The completion callback is performed on the `completionQueue`, which is `.main` by default.
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
        completesOn completionQueue: DispatchQueue = .main
        ) -> Future {
        
        return Future { cb in
            queue.asyncAfter(deadline: .now() + delay) {
                future.run { value in
                    completionQueue.async {
                        cb(value)
                    }
                }
            }
        }
    }
    
    public func async(
        delay: TimeInterval = 0,
        on queue: DispatchQueue,
        completesOn completionQueue: DispatchQueue = .main
        ) -> Future {
        
        return Future.async(
            self,
            delay: delay,
            on: queue,
            completesOn: completionQueue
        )
    }
    
    public func asyncOnMain() -> Future {
        return self.async(on: .main, completesOn: .main)
    }
}

extension Future {
    
    public static func batch(
        _ futures: [Future<Response>]
        ) -> Future<[Response]> {
        
        return Future<[Response]> { cb in
            
            let group = DispatchGroup()
            var responses: [Response?] = Array(repeating: nil, count: futures.count)
            
            for (idx, future) in futures.enumerated() {
                group.enter()
                
                future.run { response in
                    responses[idx] = response
                    group.leave()
                }
            }
            
            group.wait()
            cb(responses.map({ $0! }))
        }
    }
}

public func zip<A, B>(
    _ a: Future<A>,
    _ b: Future<B>
    ) -> Future<(A, B)> {
    
    return zipWith(a, b) { ($0, $1) }
}

/// Note: This will block the queue that it is called on, until all futures are finished. If the futures async onto the same queue that this is run on, it will deadlock.
public func zipWith<A, B, FinalResponse>(
    _ a: Future<A>,
    _ b: Future<B>,
    combine: @escaping (A, B) -> FinalResponse
    ) -> Future<FinalResponse> {
    
    return Future<FinalResponse> { callback in
        let group = DispatchGroup()
        var aRes: A!
        var bRes: B!
        
        group.enter()
        a.run { aRes = $0; group.leave() }
        group.enter()
        b.run { bRes = $0; group.leave() }
        
        group.wait()
        callback(combine(aRes, bRes))
    }
}

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
        let group = DispatchGroup()
        var aRes: A!
        var bRes: B!
        var cRes: C!
        
        group.enter()
        a.run { aRes = $0; group.leave() }
        group.enter()
        b.run { bRes = $0; group.leave() }
        group.enter()
        c.run { cRes = $0; group.leave() }
        
        group.wait()
        callback(combine(aRes, bRes, cRes))
    }
}
