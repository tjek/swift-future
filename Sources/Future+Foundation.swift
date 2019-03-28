//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import Foundation

enum FutureFoundationError: Error {
    case unavailableBundleResource(name: String, extension: String?)
    case urlSessionUnknownError(request: URLRequest, response: URLResponse?)
}

// MARK: - Decoding

extension JSONDecoder {
    public func decode<T: Decodable>(from data: Data) -> FutureResult<T> {
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
    public func decode<T: Decodable>(from data: Data) -> FutureResult<T> {
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
    
    public func decodedFromJSON<T: Decodable>() -> FutureResult<T> {
        return JSONDecoder().decode(from: self)
    }
    
    public func decodedFromPropertyList<T: Decodable>() -> FutureResult<T> {
        return PropertyListDecoder().decode(from: self)
    }
}

extension Decodable {
    public static func decodeJSON(from data: Data) -> FutureResult<Self> {
        return data.decodedFromJSON()
    }
    
    public static func decodePropertyList(from data: Data) -> FutureResult<Self> {
        return data.decodedFromPropertyList()
    }
}

// MARK: - Encoding

extension JSONEncoder {
    public func encode<T: Encodable>(_ value: T) -> FutureResult<Data> {
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
    public func encode<T: Encodable>(_ value: T) -> FutureResult<Data> {
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
    
    public func encodedToJSON() -> FutureResult<Data> {
        return JSONEncoder().encode(self)
    }
    
    public static func encodeToJSON(_ value: Self) -> FutureResult<Data> {
        return value.encodedToJSON()
    }
    
    public func encodedToPropertyList() -> FutureResult<Data> {
        return PropertyListEncoder().encode(self)
    }
    
    public static func encodeToPropertyList(_ value: Self) -> FutureResult<Data> {
        return value.encodedToPropertyList()
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
    
    public func dataTask(with request: URLRequest) -> Future<(Data?, URLResponse?, Error?)> {
        return Future<(Data?, URLResponse?, Error?)> { completion in
            let task = self.dataTask(with: request) {
                completion(($0, $1, $2))
            }
            task.resume()
        }
    }
    
    public func dataTaskResult(with request: URLRequest) -> FutureResult<(data: Data, response: URLResponse)> {
        return dataTask(with: request).map({
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
