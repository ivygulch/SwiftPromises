//
//  PromiseTests.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation
import XCTest

/// like XCTAssertEqual, but handles optional unwrapping
func XCTAssertEqualOptional<T:Equatable>(expression1: @autoclosure () -> T?, expression2: @autoclosure () -> T?, _ message: String? = nil, file: String = __FILE__, line: UInt = __LINE__) {
    if let exp1 = expression1() {
        if let exp2 = expression2() {
            XCTAssertEqual(exp1, exp2, (message != nil) ? message! : "", file: file, line: line)
        } else {
            XCTFail((message != nil) ? message! : "exp1 != nil, exp2 == nil", file: file, line: line)
        }
    } else if let exp2 = expression2() {
        XCTFail((message != nil) ? message! : "exp1 == nil, exp2 != nil", file: file, line: line)
    }
}

class PromiseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testPendingPromise() {
        let promise = Promise()
        XCTAssertTrue(promise.isPending)
        XCTAssertFalse(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
        XCTAssertNil(promise.value)
        XCTAssertNil(promise.error)
    }

    func testImmediatelyFulfilledPromise() {
        let promise = Promise("test")
        XCTAssertFalse(promise.isPending)
        XCTAssertTrue(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
        XCTAssertEqualOptional("test", promise.value as? String)
        XCTAssertNil(promise.error)
    }

    func testImmediatelyRejectedPromise() {
        let error = NSError(domain: "test", code: -1, userInfo: nil)
        let promise = Promise(error)
        XCTAssertFalse(promise.isPending)
        XCTAssertFalse(promise.isFulfilled)
        XCTAssertTrue(promise.isRejected)
        XCTAssertEqualOptional(error, promise.error)
        XCTAssertNil(promise.value)
    }

    func testSimpleThen() {
        let promise = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")
        promise.then(
            { (value) -> AnyObject? in
                expectation.fulfill()
                return nil
            }, reject: { (error) -> NSError in
                expectation.fulfill()
                XCTFail("Should not call reject: \(error)")
                return error
        })
        promise.fulfill("test")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleThenNoReject() {
        let promise = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")
        promise.then(
            { (value) -> AnyObject? in
                expectation.fulfill()
                return nil
            }
        )
        promise.fulfill("test")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleReject() {
        let promise = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")
        promise.then(
            { (value) -> AnyObject? in
                expectation.fulfill()
                XCTFail("Should not call then: \(value)")
                return nil
            }, reject: { (error) -> NSError in
                expectation.fulfill()
                return error
        })
        promise.reject(NSError(domain: "test", code: -1, userInfo: nil))
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleChainedThen() {
        let promise1 = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedValue = "test"
        let promise2 = promise1.then(
            { (value) -> AnyObject? in
                expectation1.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return value
            }, reject: { (error) -> NSError in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error)")
                return error
        })
        let promise3 = promise2.then(
            { (value) -> AnyObject? in
                expectation2.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return value
            }, reject: { (error) -> NSError in
                expectation2.fulfill()
                XCTFail("Should not call reject promise2: \(error)")
                return error
        })
        promise3.then(
            { (value) -> AnyObject? in
                expectation3.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return value
            }, reject: { (error) -> NSError in
                expectation3.fulfill()
                XCTFail("Should not call reject promise3: \(error)")
                return error
        })
        promise1.fulfill(expectedValue)
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testThenReturnsDelayedPromise() {
        let promise1 = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation3 = expectationWithDescription("expectation3")
        let promise3 = Promise()
        let promise2 = promise1.then(
            { (value1) -> AnyObject? in
                expectation1.fulfill()

                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout/5.0 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    promise3.fulfill("test3")
                }
                promise3.then(
                    { (value3) -> AnyObject? in
                        expectation3.fulfill()
                        return nil
                    }, reject: { (error3) -> NSError in
                        expectation3.fulfill()
                        XCTFail("Should not call reject promise3: \(error3)")
                        return error3
                })
                return promise3
            }, reject: { (error1) -> NSError in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return error1
        })

        promise1.fulfill("test1")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleChainedReject() {
        let promise1 = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { (value) -> AnyObject? in
                expectation1.fulfill()
                XCTFail("Should not call then promise1: \(value)")
                return value
            }, reject: { (error) -> NSError in
                XCTAssertEqual(expectedError, error)
                expectation1.fulfill()
                return error
        })
        let promise3 = promise2.then(
            { (value) -> AnyObject? in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value)")
                return value
            }, reject: { (error) -> NSError in
                XCTAssertEqual(expectedError, error)
                expectation2.fulfill()
                return error
        })
        promise3.then(
            { (value) -> AnyObject? in
                expectation3.fulfill()
                XCTFail("Should not call then promise3: \(value)")
                return value
            }, reject: { (error) -> NSError in
                XCTAssertEqual(expectedError, error)
                expectation3.fulfill()
                return error
        })
        promise1.reject(expectedError)
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testChainedRejectAfterInitialThen() {
        let promise1 = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedValue = "test"
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { (value1) -> AnyObject? in
                expectation1.fulfill()

                let promise3 = Promise()
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout/5.0 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    promise3.reject(expectedError)
                }
                promise3.then(
                    { (value3) -> AnyObject? in
                        expectation3.fulfill()
                        XCTFail("Should not call then promise3: \(value3)")
                        return value3
                    }, reject: { (error3) -> NSError in
                        expectation3.fulfill()
                        return error3
                })
                return promise3
            }, reject: { (error1) -> NSError in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return error1
        })
        promise2.then(
            { (value2) -> AnyObject? in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value2)")
                return value2
            }, reject: { (error2) -> NSError in
                XCTAssertEqual(expectedError, error2)
                expectation2.fulfill()
                return error2
        })

        promise1.fulfill("test1")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testChainedThenReturningError() {
        let promise1 = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectedValue = "test"
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { (value1) -> AnyObject? in
                expectation1.fulfill()
                return expectedError
            }, reject: { (error1) -> NSError in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return error1
        })
        promise2.then(
            { (value2) -> AnyObject? in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value2)")
                return value2
            }, reject: { (error2) -> NSError in
                XCTAssertEqual(expectedError, error2)
                expectation2.fulfill()
                return error2
        })

        promise1.fulfill("test1")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    // MARK: - Promise.all tests

    func testAllFulfilledAfterCallToAll() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise] = []
        for index in 0..<5 {
            expectedPromises.append(Promise())
        }
        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { (value) -> AnyObject? in
                if let actualPromises = value as? [Promise] {
                    XCTAssertEqual(expectedPromises.count, actualPromises.count)
                    for index in 0..<actualPromises.count {
                        let actualPromise = actualPromises[index]
                        XCTAssertEqualOptional("test\(index)", actualPromise.value as? String)
                    }
                } else {
                    XCTFail("should return list of fulfilled promises")
                }
                expectation.fulfill()
                return value
            }, reject: { (error) -> NSError in
                XCTFail("should not fail")
                expectation.fulfill()
                return error
        })

        for index in 0..<expectedPromises.count {
            let expectedPromise = expectedPromises[index]
            expectedPromise.fulfill("test\(index)")
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testAllFulfilledBeforeCallToAll() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise] = []
        for index in 0..<5 {
            expectedPromises.append(Promise("test\(index)"))
        }
        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { (value) -> AnyObject? in
                if let actualPromises = value as? [Promise] {
                    XCTAssertEqual(expectedPromises.count, actualPromises.count)
                    for index in 0..<actualPromises.count {
                        let actualPromise = actualPromises[index]
                        XCTAssertEqualOptional("test\(index)", actualPromise.value as? String)
                    }
                } else {
                    XCTFail("should return list of fulfilled promises")
                }
                expectation.fulfill()
                return value
            }, reject: { (error) -> NSError in
                XCTFail("should not fail")
                expectation.fulfill()
                return error
        })

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testAllWithRejectionAfterCallToAll() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise] = []
        let indexToReject=1
        for index in 0..<5 {
            expectedPromises.append(Promise())
        }

        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { (value) -> AnyObject? in
                XCTFail("should have failed")
                expectation.fulfill()
                return value
            }, reject: { (error) -> NSError in
                XCTAssertEqual("error\(indexToReject)", error.domain)
                expectation.fulfill()
                return error
        })

        for index in 0..<expectedPromises.count {
            let expectedPromise = expectedPromises[index]
            if (index == indexToReject) {
                expectedPromise.reject(NSError(domain:"error\(index)", code:-1, userInfo:nil))
            } else {
                expectedPromise.fulfill("test\(index)")
            }
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testAllWithRejectionBeforeCallToAll() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise] = []
        let indexToReject=1
        for index in 0..<5 {
            if (index == indexToReject) {
                expectedPromises.append(Promise(NSError(domain:"error\(index)", code:-1, userInfo:nil)))
            } else {
                expectedPromises.append(Promise("test\(index)"))
            }
        }

        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { (value) -> AnyObject? in
                XCTFail("should have failed")
                expectation.fulfill()
                return value
            }, reject: { (error) -> NSError in
                XCTAssertEqual("error\(indexToReject)", error.domain)
                expectation.fulfill()
                return error
        })
        
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }
    
    // MARK: - Promise.any tests

    func testAnyFulfilledAfterCallToAny() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise] = []
        let indexToFufill = 1
        for index in 0..<5 {
            expectedPromises.append(Promise())
        }
        let promiseAll = Promise.any(expectedPromises)
        promiseAll.then(
            { (value) -> AnyObject? in
                XCTAssertEqualOptional("test\(indexToFufill)", value as? String)
                expectation.fulfill()
                return value
            }, reject: { (error) -> NSError in
                XCTFail("should not fail")
                expectation.fulfill()
                return error
        })

        expectedPromises[indexToFufill].fulfill("test\(indexToFufill)")
        for index in 0..<expectedPromises.count {
            if (index != indexToFufill) {
                let expectedPromise = expectedPromises[index]
                expectedPromise.fulfill("test\(index)")
            }
        }

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

}
