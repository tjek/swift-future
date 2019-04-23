//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

public enum MeasureTimeScale {
    case seconds
    case milliseconds
    case microseconds
    case nanoseconds
    
    public var scaleFactor: Double {
        switch self {
        case .seconds:
            return 1
        case .milliseconds:
            return 1_000
        case .microseconds:
            return 1_000_000
        case .nanoseconds:
            return 1_000_000_000
        }
    }
    public var shortName: String {
        
        switch self {
        case .seconds:
            return "s"
        case .milliseconds:
            return "ms"
        case .microseconds:
            return "μs"
        case .nanoseconds:
            return "ns"
        }
    }
}

extension Future {
    
    /// After the future is run, it calls the `durationCallback` on the main queue, passing how long it took to execute the current future.
    public func measure(_ durationCallback: @escaping (TimeInterval) -> Void) -> Future {
        return Future { callback in
            
            let start = CFAbsoluteTimeGetCurrent()
            
            self.run {
                let end = CFAbsoluteTimeGetCurrent()
                
                DispatchQueue.main.async {
                    durationCallback((end - start))
                }
                
                callback($0)
            }
        }
    }
    
    /// After the future is run, prints the duration prefixed with the `label`, in the specified `timeScale`
    public func measure(print label: @escaping @autoclosure () -> String, timeScale: MeasureTimeScale = .seconds, decimalPlaces: Int? = 3) -> Future {
        return self.measure { duration in
            var roundedDuration = duration * timeScale.scaleFactor
            
            if let places = decimalPlaces {
                let scalingFactor = pow(10, Double(places))
                roundedDuration = round(roundedDuration * scalingFactor) / scalingFactor
            }
            
            let durationStr = "\(roundedDuration)".replacingOccurrences(of: "e|E", with: " × 10^", options: .regularExpression, range: nil)
            // "Rebuilding: 0.015s
            var str = label()
            str += ": \(durationStr)\(timeScale.shortName)"
            
            print(str)
        }
    }
    
    public static func measure(_ future: Future, durationCallback: @escaping (TimeInterval) -> Void) -> Future {
        return future.measure(durationCallback)
    }
    
    public static func measure(print label: @escaping @autoclosure () -> String, timeScale: MeasureTimeScale = .seconds, decimalPlaces: Int? = 3, _ future: Future) -> Future {
        return future.measure(print: label(), timeScale: timeScale, decimalPlaces: decimalPlaces)
    }
}
