//
//  FutureTests.swift
//  FutureTests
//
//  Created by Laurie Hufford on 27/03/2019.
//  Copyright © 2019 ShopGun. All rights reserved.
//

import XCTest
@testable import Future

fileprivate enum TestError: String, Error {
    case foo
    case bar
    case bosh
}

fileprivate enum OtherTestError: String, Error {
    case baz
}

class FutureResultTests: XCTestCase {
    
    func testMap() {
        
        var resA: Result<Int, Never> = .success(0)
        Future<Result<Int, Never>>(value: .success(5))
            .mapResult({
                XCTAssertEqual($0, 5)
                return $0*2
            })
            .run({
                resA = $0
            })
        XCTAssert(resA == Result<Int, Never>.success(10))
        
        var resB: Result<Int, TestError> = .success(0)
        Future<Result<Int, TestError>>(value: .failure(.foo))
            .mapResultError({
                XCTAssert($0 == TestError.foo)
                return .bar
            })
            .run({
                resB = $0
            })
        XCTAssert(resB == Result<Int, TestError>.failure(.bar))
    }

    func testFlatMap() {
        
        var resA: Result<String, OtherTestError> = .success("")
        Future<Result<Int, TestError>>(value: .success(5))
            .observeResultSuccess({
                XCTAssertEqual($0, 5)
            })
            .observeResultError({ _ in
                XCTAssertTrue(false)
            })
            .flatMapResult({
                XCTAssertEqual($0, 5)
                return Future<Result<String, TestError>>(value: .success("\($0)"))
            })
            .flatMapResultError({ _ in
                XCTAssertTrue(false)
                return Future<Result<String, OtherTestError>>(value: .failure(.baz))
            })
            .observeResultSuccess({
                XCTAssertEqual($0, "5")
            })
            .run({
                resA = $0
            })
        XCTAssert(resA == Result<String, OtherTestError>.success("5"))
        
        
        var resB: Result<String, OtherTestError> = .success("")
        Future<Result<Int, TestError>>(value: .failure(.foo))
            .observeResultSuccess({ _ in
                XCTAssertTrue(false)
            })
            .observeResultError({
                XCTAssertEqual($0, .foo)
            })
            .flatMapResult({
                // if it's an error, this mustnt be called
                XCTAssertTrue(false)
                return Future<Result<String, TestError>>(value: .success("\($0)"))
            })
            .flatMapResultError({
                XCTAssertEqual($0, .foo)
                return Future<Result<String, OtherTestError>>(value: .failure(.baz))
            })
            .observeResultError({
                XCTAssertEqual($0, .baz)
            })
            .run({
                resB = $0
            })
        XCTAssert(resB == Result<String, OtherTestError>.failure(.baz))
    }
    
    func testZip() {
        
        var resA: Result<(Int, String), TestError> = .success((0, ""))
        Future<Result<Int, TestError>>(value: .success(2))
            .zippedResult(Future<Result<String, TestError>>(value: .success("foo")))
            .run { resA = $0 }
        
        XCTAssert((try? resA.get())?.0 == 2)
        XCTAssert((try? resA.get())?.1 == "foo")
        
        // check if 1st future's error is acknowledged
        var resB: Result<(Int, String), TestError> = .success((0, ""))
        Future<Result<Int, TestError>>(value: .failure(.foo))
            .zippedResult(Future<Result<String, TestError>>(value: .success("foo")))
            .run { resB = $0 }
        XCTAssert(resB.error == .foo)
        
        // check if 2nd future's error is acknowledged
        var resC: Result<(Int, String), TestError> = .success((0, ""))
        Future<Result<Int, TestError>>(value: .success(2))
            .zippedResult(Future<Result<String, TestError>>(value: .failure(.bar)))
            .run { resC = $0 }
        XCTAssert(resC.error == .bar)

        // check if 1st future's error is prioritized over 2nd future's error
        var resD: Result<(Int, String), TestError> = .success((0, ""))
        Future<Result<Int, TestError>>(value: .failure(.foo))
            .zippedResult(Future<Result<String, TestError>>(value: .failure(.bar)))
            .run { resD = $0 }
        XCTAssert(resD.error == .foo)
        
        
        var resE: Result<(Int, String, Int), TestError> = .success((0, "", 0))
        zipResult3(
            Future<Result<Int, TestError>>(value: .success(2)),
            Future<Result<String, TestError>>(value: .success("foo")),
            Future<Result<Int, TestError>>(value: .success(4))
            ).run { resE = $0 }
        XCTAssertEqual((try? resE.get())?.0, 2)
        XCTAssertEqual((try? resE.get())?.1, "foo")
        XCTAssertEqual((try? resE.get())?.2, 4)
        
        var resF: Result<(Int, String, Int), TestError> = .success((0, "", 0))
        zipResult3(
            Future<Result<Int, TestError>>(value: .success(2)),
            Future<Result<String, TestError>>(value: .success("foo")),
            Future<Result<Int, TestError>>(value: .failure(.foo))
            ).run { resF = $0 }
        XCTAssert(resF.error == .foo)
        
        var resG: Result<(Int, String, Int), TestError> = .success((0, "", 0))
        zipResult3(
            Future<Result<Int, TestError>>(value: .success(2)),
            Future<Result<String, TestError>>(value: .failure(.bar)),
            Future<Result<Int, TestError>>(value: .success(4))
            ).run { resG = $0 }
        XCTAssert(resG.error == .bar)
        
        var resH: Result<(Int, String, Int), TestError> = .success((0, "", 0))
        zipResult3(
            Future<Result<Int, TestError>>(value: .failure(.bosh)),
            Future<Result<String, TestError>>(value: .success("foo")),
            Future<Result<Int, TestError>>(value: .success(4))
            ).run { resH = $0 }
        XCTAssert(resH.error == .bosh)
        
        var resI: Result<(Int, String, Int), TestError> = .success((0, "", 0))
        zipResult3(
            Future<Result<Int, TestError>>(value: .failure(.foo)),
            Future<Result<String, TestError>>(value: .failure(.bosh)),
            Future<Result<Int, TestError>>(value: .failure(.bar))
            ).run { resI = $0 }
        XCTAssert(resI.error == .foo)
        
        // test zippedWithResult
        var resJ: Result<String, TestError> = .success("")
        Future<Result<Int, TestError>>(value: .success(4))
            .zippedWithResult(Future<Result<String, TestError>>(value: .success("bar"))) {
                "\($0) - \($1)"
            }
            .run { resJ = $0 }
        XCTAssert(resJ.value == "4 - bar")
    }
    
//    func testFoo() {
//        
//        struct User: Codable {
//            var id: String
//            var name: String
//        }
//        struct Food: Codable {
//            var type: String
//            var tastiness: Int
//        }
//        
//        let loadFileUser: FutureResult<User> = Future
//            .init(work: {
//                .success(User(id: "foo", name: "bar"))
//            })
//        
//        let loadStringFood: FutureResult<Food> = Future<String>
//            .init(value: #"{ "type": "curry", "tastiness": 1000 }"#)
//            .map({ $0.data(using: .utf8)! })
//            .flatMap(Food.decodeJSON(from:))
//        
//        let loadNetworkUser: FutureResult<User> = URLSession.shared
//            .dataTaskResult(with: URLRequest(url: URL(string: "https://foo.bar")!))
//            .mapResult({ $0.data })
//            .flatMapResult(User.decodeJSON(from:))
//        
//        let combinedFuture = zipResult3With(
//            loadStringFood,
//            loadFileUser,
//            loadNetworkUser
//        ) { (food: $0, user: $1, networkUser: $2) }
//            .mapResult({
//                "\($0.user.name) likes \($0.food.type) x\($0.food.tastiness)... networkUser: '\($0.networkUser.name)'"
//            })
//        
//        //
//        //combinedFuture.run { result in
//        //    print(result)
//        //}
//        
//        Future.batchResult([ loadNetworkUser, loadFileUser ]).run { result in
////            print(result)
//        }
//
//    }
}

extension Result {
    fileprivate var value: Success? {
        if case let .success(value) = self {
            return value
        } else {
            return nil
        }
    }
    fileprivate var error: Failure? {
        if case let .failure(error) = self {
            return error
        } else {
            return nil
        }
    }
}
