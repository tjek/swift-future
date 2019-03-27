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
    let run: (@escaping Callback) -> Void
    
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
    
    public func map<NewResponse>(
        _ transform: @escaping (Response) -> NewResponse
        ) -> Future<NewResponse> {
        
        return Future<NewResponse> { callback in
            self.run {
                callback(transform($0))
            }
        }
    }
    
    public func flatMap<NewResponse>(
        _ transform: @escaping (Response) -> Future<NewResponse>
        ) -> Future<NewResponse> {
        
        return Future<NewResponse> { callback in
            self.run {
                transform($0).run(callback)
            }
        }
    }
    
    public func zip<OtherResponse>(
        _ other: Future<OtherResponse>
        ) -> Future<(Response, OtherResponse)> {
        
        return Future<(Response, OtherResponse)> { callback in
            let group = DispatchGroup()
            var response: Response!
            var otherResponse: OtherResponse!
            group.enter()
            self.run { response = $0; group.leave() }
            group.enter()
            other.run { otherResponse = $0; group.leave() }
            
            group.notify(queue: .global(), execute: {
                callback((response, otherResponse))
            })
        }
    }
    
    public func zipWith<OtherResponse, FinalResponse>(
        _ other: Future<OtherResponse>,
        _ combine: @escaping (Response, OtherResponse) -> FinalResponse
        ) -> Future<FinalResponse> {
        
        return self.zip(other).map(combine)
    }
    
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
    
    static func batch(_ futures: [Future<Response>], completesOn completionQueue: DispatchQueue = .main) -> Future<[Response]> {
        
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
            
            group.notify(queue: .global()) {
                let finalResponses = responses.map({ $0! })
                
                completionQueue.async {
                    cb(finalResponses)
                }
            }
        }
    }
}
