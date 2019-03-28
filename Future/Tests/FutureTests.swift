//
//  FutureTests.swift
//  FutureTests
//
//  Created by Laurie Hufford on 27/03/2019.
//  Copyright © 2019 ShopGun. All rights reserved.
//

import XCTest
@testable import Future_iOS

class FutureTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        
        
        struct User: Codable {
            var id: String
            var name: String
        }
        struct Food: Codable {
            var type: String
            var tastiness: Int
        }
        
        let loadFileUser: FutureResult<User> = Bundle.main
            .loadData(forResource: "User.json")
            .flatMapResult(User.decodeJSON(from:))
        
        let loadStringFood: FutureResult<Food> = Future<String>
            .init(value: #"{ "type": "curry", "tastiness": 1000 }"#)
            .map({ $0.data(using: .utf8)! })
            .flatMap(Food.decodeJSON(from:))
        
        let loadNetworkUser: FutureResult<User> = URLSession.shared
            .dataTaskResult(with: URLRequest(url: URL(string: "https://foo.bar")!))
            .mapResult({ $0.data })
            .flatMapResult(User.decodeJSON(from:))
        
        let combinedFuture = zipResult3With(loadStringFood, loadFileUser, loadNetworkUser) { (food: $0, user: $1, networkUser: $2) }
            .mapResult({ "\($0.user.name) likes \($0.food.type) x\($0.food.tastiness)... networkUser: '\($0.networkUser.name)'"})
        
        combinedFuture.run { result in
            print(result)
        }
        
        
        let futures: [Future<Int>] = (0..<10).map { intVal in
            Future<Int>(work: {
                print("Work", intVal)
                return intVal
            })
        }
        
        let batchedFuture = Future.batch(
            futures.map({
                $0.async(delay: Double.random(in: 0..<2), on: .global())
            })
            )
            .map { Array($0.reversed()) }
            .map { $0.map { String($0) } }
        
        let finish = self.expectation(description: "It finishes")
        
        batchedFuture.run({
            print("result", $0)
            finish.fulfill()
            })
        
        self.wait(for: [finish], timeout: 20)
        
        print("Done")
        
    }

}
