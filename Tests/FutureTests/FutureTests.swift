//
//  FutureTests.swift
//  FutureTests
//
//  Created by Laurie Hufford on 27/03/2019.
//  Copyright © 2019 ShopGun. All rights reserved.
//

import XCTest
@testable import Future

class FutureTests: XCTestCase {
    
    func testInit() {
        
        var resA: Int = 0
        Future<Int>(value: 1).run { resA = $0 }
        XCTAssertEqual(resA, 1)
        
        var resB: String = ""
        Future<String>(value: "foobar").run { resB = $0 }
        XCTAssertEqual(resB, "foobar")
        
        var resC: Int = 0
        Future<Int>(work: { (2 + 2) }).run { resC = $0 }
        XCTAssertEqual(resC, 4)
    }
    
    func testFunctional() {
        
        var resA: String = ""
        Future<Int>(value: 2)
            .observe({
                XCTAssertEqual($0, 2)
            })
            .flatMap({ intVal in
                Future(work: { intVal * 2 })
            })
            .observe({
                XCTAssertEqual($0, 4)
            })
            .map(String.init)
            .run { resA = $0 }
        XCTAssertEqual(resA, "4")
        
        
        var resB: (Int, String) = (0, "")
        Future<Int>(value: 2)
            .zipped(Future<String>(value: "foo"))
            .run { resB = $0 }
        XCTAssertEqual(resB.0, 2)
        XCTAssertEqual(resB.1, "foo")
        
        
        var resC: String = ""
        Future<Int>(value: 2)
            .zippedWith(Future<String>(value: "foo")) {
                "\($0) - \($1)"
            }
            .run { resC = $0 }
        XCTAssertEqual(resC, "2 - foo")
        
        var resD: (Int, String, Int) = (0, "", 0)
        zip3(
            Future<Int>(value: 2),
            Future<String>(value: "foo"),
            Future<Int>(value: 4)
            ).run { resD = $0 }
        XCTAssertEqual(resD.0, 2)
        XCTAssertEqual(resD.1, "foo")
        XCTAssertEqual(resD.2, 4)
        
        var resE: String = ""
        zip3With(
            Future<Int>(value: 2),
            Future<String>(value: "foo"),
            Future<Int>(value: 4)) {
                "\($0) - \($1) - \($2)"
            }
            .run { resE = $0 }
        XCTAssertEqual(resE, "2 - foo - 4")
    }
    
    func testBatch() {

        let futures = (0..<10).map(Future<Int>.init(value:))
        
        var resA: [Int] = []
        batch(futures)
            .run { resA = $0 }
        
        XCTAssertEqual(resA, Array(0..<10))
    }

    func testAsync() {
        
        let start = Date.timeIntervalSinceReferenceDate
        
        let workQ = DispatchQueue(label: "WorkQueue")
        let completionQ = DispatchQueue(label: "CompletionQueue")
        
        let expectIsAsync = self.expectation(description: "Is Async")
        var res: Int = 2
        Future<Int>(work: {
            // is working on the correct queue
            XCTAssertEqual(DispatchQueue.currentLabel, workQ.label)
            
            return res * 2
        })
            .async(delay: 1, on: workQ, completesOn: completionQ)
            .run {
                let end = Date.timeIntervalSinceReferenceDate
                res = $0
                
                // work has been done
                XCTAssertEqual(res, 4)
                // it was delayed
                XCTAssert(end - start > 1)
                // is completing on the correct queue
                XCTAssertEqual(DispatchQueue.currentLabel, completionQ.label)
                
                expectIsAsync.fulfill()
        }
        
        // it is async
        XCTAssertEqual(res, 2)
        
        self.wait(for: [expectIsAsync], timeout: 5)
    }
    
    func testAsyncOnMain() {
        
        let expectIsAsync = self.expectation(description: "Is Async")
        var res: Int = 2
        Future<Int>(work: {
            // is working on the correct queue
            XCTAssertEqual(DispatchQueue.currentLabel, DispatchQueue.main.label)
            
            return res * 2
        })
            .asyncOnMain()
            .run {
                res = $0
                
                XCTAssertEqual(res, 4)
                
                // is completing on the correct queue
                XCTAssertEqual(DispatchQueue.currentLabel, DispatchQueue.main.label)
                
                expectIsAsync.fulfill()
        }
        
        // it is async
        XCTAssertEqual(res, 2)
        self.wait(for: [expectIsAsync], timeout: 5)
    }
    
    func testAsyncBlockingQueue() {
        
        let start = Date.timeIntervalSinceReferenceDate
        
        let workQ = DispatchQueue(label: "WorkQueue")
        let completionQ = DispatchQueue(label: "CompletionQueue")
        
        let expectIsAsync = self.expectation(description: "Is Async")
        var res: Int = 2
        Future<Int>(run: { cb in
            // is working on the correct queue
            XCTAssertEqual(DispatchQueue.currentLabel, workQ.label)
            
            // wait a second before completing the work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                XCTAssertEqual(res, 2)
                res *= 2
                cb(res)
            }
        })
            .async(delay: 0, on: workQ, blocksQueue: true, completesOn: completionQ)
            .run { returnedRes in
                let end = Date.timeIntervalSinceReferenceDate
                
                // Note: this callback occurs _after_ the queue is unblocked
                // so returnedRes may not equal res (as the other work may have already occurred.
                
                // work has been done
                XCTAssertEqual(returnedRes, 4)
                // it was delayed
                XCTAssert(end - start > 1)
                // is completing on the correct queue
                XCTAssertEqual(DispatchQueue.currentLabel, completionQ.label)
        }
        
        // start some other work on the same queue.
        Future<Int>(work: {
            // is working on the correct queue
            XCTAssertEqual(DispatchQueue.currentLabel, workQ.label)

            // the previously defined future has been run first
            XCTAssertEqual(res, 4)
            
            return res + 1
        })
            .async(delay: 0, on: workQ, blocksQueue: true, completesOn: completionQ)
            .run {
                let end = Date.timeIntervalSinceReferenceDate
                res = $0
                
                // work has been done (after the previous work)
                XCTAssertEqual(res, 5)
                // it was delayed (waiting for prev work to finish)
                XCTAssert(end - start > 1)
                // is completing on the correct queue
                XCTAssertEqual(DispatchQueue.currentLabel, completionQ.label)
                
                expectIsAsync.fulfill()
        }
        
        // it is async - the res hasnt been changed yet
        XCTAssertEqual(res, 2)
        
        self.wait(for: [expectIsAsync], timeout: 5)
        
        XCTAssertEqual(res, 5)
    }
    
    func testParallel() {
        let sharedQ = DispatchQueue(label: "SharedQueue")
        let completionQ = DispatchQueue(label: "CompletionQueue")

        let futureA = Future<Int>(value: 5).async(on: sharedQ)
        let futureB = Future<Int>(run: { cb in
            XCTAssertEqual(DispatchQueue.currentLabel, sharedQ.label)
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                cb(3)
            }
        }).async(on: sharedQ)
        
        let futureC = parallelWith(futureA, futureB, completesOn: completionQ) { "= \($0 * $1)" }
        
        let expectIsAsync = self.expectation(description: "Is Async")
        var res: String = "foo"
        futureC.run {
            res = $0
            XCTAssertEqual(DispatchQueue.currentLabel, completionQ.label)
            XCTAssertEqual(res, "= 15")
            expectIsAsync.fulfill()
        }
        
        // it is async
        XCTAssertEqual(res, "foo")
        self.wait(for: [expectIsAsync], timeout: 5)
    }
}

extension DispatchQueue {
    // HERE BE DRAGONS! Not in production!
    fileprivate static var currentLabel: String {
        return String(validatingUTF8: __dispatch_queue_get_label(nil))!
    }
}
