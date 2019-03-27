//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

extension Result {
    
    public func getSuccess() -> Success? {
        return try? get()
    }

    public func getFailure() -> Error? {
        guard case .failure(let e) = self else {
            return nil
        }
        return e
    }
}

extension Result {
    
    public func zip<OtherSuccess>(_ other: Result<OtherSuccess, Failure>) -> Result<(Success, OtherSuccess), Failure> {
        switch (self, other) {
        case let (.success(a), .success(b)):
            return .success((a, b))
        case let (.failure(error), _),
             let (_, .failure(error)):
            return .failure(error)
        }
    }
    
    public func zipWith<OtherSuccess, FinalSuccess>(_ other: Result<OtherSuccess, Failure>, _ combine: @escaping (Success, OtherSuccess) -> FinalSuccess) -> Result<FinalSuccess, Failure> {
        return self.zip(other).map(combine)
    }
}
