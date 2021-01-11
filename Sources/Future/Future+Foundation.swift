///
///  Copyright (c) 2019 Tjek. All rights reserved.
///

import Foundation

enum FutureFoundationError: Error {
    case unavailableBundleResource(name: String, extension: String?)
    case urlSessionUnknownError(request: URLRequest, response: URLResponse?)
}

// MARK: - Decoding

extension JSONDecoder {
    public func decodeFuture<T: Decodable>(from data: Data) -> FutureResult<T> {
        return FutureResult<T> { completion in
            completion(
                Result(catching: {
                    try self.decode(T.self, from: data)
                })
            )
        }
    }
}

extension PropertyListDecoder {
    public func decodeFuture<T: Decodable>(from data: Data) -> FutureResult<T> {
        return FutureResult<T> { completion in
            completion(
                Result(catching: {
                    try self.decode(T.self, from: data)
                })
            )
        }
    }
}

extension Data {
    
    public func decodedFutureFromJSON<T: Decodable>() -> FutureResult<T> {
        return JSONDecoder().decodeFuture(from: self)
    }
    
    public func decodedFutureFromPropertyList<T: Decodable>() -> FutureResult<T> {
        return PropertyListDecoder().decodeFuture(from: self)
    }
}

extension Decodable {
    public static func decodeFutureJSON(from data: Data) -> FutureResult<Self> {
        return data.decodedFutureFromJSON()
    }
    
    public static func decodeFuturePropertyList(from data: Data) -> FutureResult<Self> {
        return data.decodedFutureFromPropertyList()
    }
}

// MARK: - Encoding

extension JSONEncoder {
    public func encodeFuture<T: Encodable>(_ value: T) -> FutureResult<Data> {
        return FutureResult<Data> { completion in
            completion(
                Result(catching: {
                    try self.encode(value)
                })
            )
        }
    }
}

extension PropertyListEncoder {
    public func encodeFuture<T: Encodable>(_ value: T) -> FutureResult<Data> {
        return FutureResult<Data> { completion in
            completion(
                Result(catching: {
                    try self.encode(value)
                })
            )
        }
    }
}

extension Encodable {
    
    public func encodedFutureToJSON() -> FutureResult<Data> {
        return JSONEncoder().encodeFuture(self)
    }
    
    public static func encodeFutureToJSON(_ value: Self) -> FutureResult<Data> {
        return value.encodedFutureToJSON()
    }
    
    public func encodedFutureToPropertyList() -> FutureResult<Data> {
        return PropertyListEncoder().encodeFuture(self)
    }
    
    public static func encodeToPropertyList(_ value: Self) -> FutureResult<Data> {
        return value.encodedFutureToPropertyList()
    }
}

// MARK: - Bundle Resource Loading

extension Bundle {
    public func loadData(forResource name: String, withExtension ext: String? = nil) -> FutureResult<Data> {
        return FutureResult<Data> { completion in
            completion(Result {
                guard let fileURL = self.url(forResource: name, withExtension: ext) else {
                    throw FutureFoundationError.unavailableBundleResource(name: name, extension: ext)
                }
                
                return try Data(contentsOf: fileURL)
            })
        }
    }
}

// MARK: - URLSession

extension URLSession {
    
    public func dataTaskFuture(with request: URLRequest) -> Future<(Data?, URLResponse?, Error?)> {
        return Future<(Data?, URLResponse?, Error?)> { completion in
            let task = self.dataTask(with: request) {
                completion(($0, $1, $2))
            }
            task.resume()
        }
    }
    
    public func dataTaskFutureResult(with request: URLRequest) -> FutureResult<(data: Data, response: URLResponse)> {
        return dataTaskFuture(with: request).map({
            switch ($0.0, $0.1, $0.2) {
            case let (data?, response?, _):
                return .success((data, response))
            case let (_, _, error?):
                return .failure(error)
            case let (_, response, nil):
                return .failure(FutureFoundationError.urlSessionUnknownError(request: request, response: response))
            }
        })
    }
}
