///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

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
    
    public func fireAndForget() {
        self.run({ _ in })
    }
    
    public static func build(future: @escaping () -> Future) -> Future {
        return Future(run: { cb in
            future().run(cb)
        })
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
     - parameter queue: The queue on which to perform the observe `callback`. If not specified, `callback`will be run on the current queue.
     - parameter callback: The callback to perform, passing the response of the receiver.
     */
    public func observe(
        on queue: DispatchQueue? = nil,
        _ callback: @escaping (Response) -> Void
        ) -> Future {
        
        return self.map { val in
            if let q = queue {
                q.async { callback(val) }
            } else {
                callback(val)
            }
            return val
        }
    }
}

extension Future {
    /// Returns a new Future whose completion handler is called on the specified queue.
    public func receiving(
        on queue: DispatchQueue
    ) -> Future {
        return Future { cb in
            self.run { value in
                queue.async {
                    cb(value)
                }
            }
        }
    }
    
    /// Returns a new Future whose work is performed on the specified queue.
    /// Use `delay` to postpone the running of the future.
    /// Use `blocksQueue` to make the queue block until the Future finishes.
    public func performing(
        on queue: DispatchQueue,
        delay: TimeInterval = 0,
        blocksQueue: Bool = false
    ) -> Future {
        return Future { cb in
            queue.asyncAfter(deadline: .now() + delay) {
                let grp: DispatchGroup? = blocksQueue ? DispatchGroup() : nil
                grp?.enter()
                
                self.run { value in
                    grp?.leave()
                    cb(value)
                }
                grp?.wait()
            }
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
        return future
            .performing(on: queue, delay: delay, blocksQueue: blocksQueue)
            .receiving(on: completionQueue)
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

// MARK: -

extension Future {

    /**
     Returns a new future, whose `run` function is a debounced version of the receiving future's `run` function.
     
     This means that if you repeatedly call `run` on the returned future, it will only perform the future's 'work' after you stop calling run for `delay` seconds.
     
     - Parameter delay: A `TimeInterval` specifying the number of seconds that needs to pass without run being called before it is actually executed.
     - Parameter queue: The queue to perform the `run` on. Defaults to the main queue.

     - Returns: A new Future that will only perform the work in `run` if `delay` time passes between invocations.
     */
    public func debounced(delay: TimeInterval, on queue: DispatchQueue = .main) -> Future {
        var currentWorkItem: DispatchWorkItem?
        
        return Future { cb in
            currentWorkItem?.cancel()
            currentWorkItem = DispatchWorkItem {
                self.run(cb)
            }
            queue.asyncAfter(deadline: .now() + delay, execute: currentWorkItem!)
        }
    }
    
    /**
     Returns a new future, whose `run` function is a throttled version of the receiving future's `run` function.
     
     This means that if you repeatedly call `run` on the returned Future, it will only perform the future's 'work' at most once every `delay` seconds.
     
     - Parameter delay: A `TimeInterval` specifying the number of seconds that needs to pass between each execution of `run`.
     - Parameter queue: The queue to perform the `run` on. Defaults to the main queue.

     - Returns: A new Future that will only perform the work in `run` once every `delay` seconds, regardless of how often it is called.
     */
    public func throttled(delay: TimeInterval, on queue: DispatchQueue = .main) -> Future {
        var currentWorkItem: DispatchWorkItem?
        
        return Future { cb in
            guard currentWorkItem == nil else { return }
            
            currentWorkItem = DispatchWorkItem {
                self.run(cb)
                currentWorkItem = nil
            }
            queue.asyncAfter(deadline: .now() + delay, execute: currentWorkItem!)
        }
    }
    
    public func retry(
        times maxRetryCount: Int,
        while shouldRetry: @escaping (Response) -> Bool
    ) -> Future {
        return self
            .flatMap({ val in
                if maxRetryCount > 0, shouldRetry(val) {
                    return self.retry(times: maxRetryCount - 1, while: shouldRetry)
                } else {
                    return Future(value: val)
                }
            })
    }
}

// MARK: -

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

public func parallel3<A, B, C>(
    _ a: Future<A>,
    _ b: Future<B>,
    _ c: Future<C>,
    completesOn completionQueue: DispatchQueue = .main
    ) -> Future<(A, B, C)> {
    
    return parallel3With(a, b, c, completesOn: completionQueue) { ($0, $1, $2) }
}

/// Performs Future<A>, Future<B>, & Future<C> in parallel on global dispatch queues, and then combines their responses on the specified completionQueue.
public func parallel3With<A, B, C, FinalResponse>(
    _ fA: Future<A>,
    _ fB: Future<B>,
    _ fC: Future<C>,
    completesOn completionQueue: DispatchQueue = .main,
    combine: @escaping (A, B, C) -> FinalResponse
    ) -> Future<FinalResponse> {
    
    return Future<FinalResponse> { callback in
        
        let maybeCompleted: (A?, B?, C?) -> Void = {
            guard let a = $0, let b = $1, let c = $2 else { return }
            callback(combine(a, b, c))
        }
        
        var a: A? = nil
        var b: B? = nil
        var c: C? = nil
        
        fA.async(on: .global(), completesOn: completionQueue).run {
            a = $0
            maybeCompleted(a, b, c)
        }
        
        fB.async(on: .global(), completesOn: completionQueue).run {
            b = $0
            maybeCompleted(a, b, c)
        }
        
        fC.async(on: .global(), completesOn: completionQueue).run {
            c = $0
            maybeCompleted(a, b, c)
        }
    }
}
