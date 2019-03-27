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
