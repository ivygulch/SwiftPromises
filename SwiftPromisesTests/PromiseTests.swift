//
//  PromiseTests.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation
import XCTest
import SwiftPromises

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
        let promise:Promise<AnyObject> = Promise()
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
        XCTAssertEqual("test", promise.value)
        XCTAssertNil(promise.error)
    }

    func testImmediatelyRejectedPromise() {
        let error = NSError(domain: "test", code: -1, userInfo: nil)
        let promise:Promise<String> = Promise(error)
        XCTAssertFalse(promise.isPending)
        XCTAssertFalse(promise.isFulfilled)
        XCTAssertTrue(promise.isRejected)
        XCTAssertEqual(error, promise.error! as NSError)
        XCTAssertNil(promise.value)
    }

    func testSimpleThen() {
        let promise:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")
        promise.then(
            { value in
                expectation.fulfill()
                return .Value(nil)
            }, reject: { error in
                expectation.fulfill()
                XCTFail("Should not call reject: \(error)")
                return .Error(error)
        })
        promise.fulfill("test")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleThenNoReject() {
        let promise:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")
        promise.then(
            { value in
                expectation.fulfill()
                return .Value(nil)
            }
        )
        promise.fulfill("test")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleReject() {
        let promise:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")
        promise.then(
            { value in
                expectation.fulfill()
                XCTFail("Should not call then: \(value)")
                return .Value(nil)
            }, reject: { error in
                expectation.fulfill()
                return .Error(error)
        })
        promise.reject(NSError(domain: "test", code: -1, userInfo: nil))
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleChainedThen() {
        let promise1:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedValue = "test"
        let promise2 = promise1.then(
            { value in
                expectation1.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .Value(value)
            }, reject: { error in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error)")
                return .Error(error)
        })
        let promise3 = promise2.then(
            { value in
                expectation2.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .Value(value)
            }, reject: { error in
                expectation2.fulfill()
                XCTFail("Should not call reject promise2: \(error)")
                return .Error(error)
        })
        promise3.then(
            { value in
                expectation3.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .Value(value)
            }, reject: { error in
                expectation3.fulfill()
                XCTFail("Should not call reject promise3: \(error)")
                return .Error(error)
        })
        promise1.fulfill(expectedValue)
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testThenReturnsDelayedPromise() {
        let promise1:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation3 = expectationWithDescription("expectation3")
        let promise3:Promise<AnyObject> = Promise()
        promise1.then(
            { value1 in
                expectation1.fulfill()

                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout/5.0 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    promise3.fulfill("test3")
                }
                promise3.then(
                    { value3 in
                        expectation3.fulfill()
                        return .Value(nil)
                    }, reject: { error3 in
                        expectation3.fulfill()
                        XCTFail("Should not call reject promise3: \(error3)")
                        return .Error(error3)
                })
                return .Pending(promise3)
            }, reject: { error1 in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return .Error(error1)
        })

        promise1.fulfill("test1")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testSimpleChainedReject() {
        let promise1:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { value in
                expectation1.fulfill()
                XCTFail("Should not call then promise1: \(value)")
                return .Value(value)
            }, reject: { error in
                XCTAssertEqual(expectedError, error as NSError)
                expectation1.fulfill()
                return .Error(error)
        })
        let promise3 = promise2.then(
            { value in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value)")
                return .Value(value)
            }, reject: { error in
                XCTAssertEqual(expectedError, error as NSError)
                expectation2.fulfill()
                return .Error(error)
        })
        promise3.then(
            { value in
                expectation3.fulfill()
                XCTFail("Should not call then promise3: \(value)")
                return .Value(value)
            }, reject: { error in
                XCTAssertEqual(expectedError, error as NSError)
                expectation3.fulfill()
                return .Error(error)
        })
        promise1.reject(expectedError)
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testChainedRejectAfterInitialThen() {
        let promise1:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { value1 in
                expectation1.fulfill()

                let promise3:Promise<AnyObject> = Promise()
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(timeout/5.0 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    promise3.reject(expectedError)
                }
                promise3.then(
                    { value3 in
                        expectation3.fulfill()
                        XCTFail("Should not call then promise3: \(value3)")
                        return .Value(value3)
                    }, reject: { error3 in
                        expectation3.fulfill()
                        return .Error(error3)
                })
                return .Pending(promise3)
            }, reject: { error1  in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return .Error(error1)
        })
        promise2.then(
            { value2 in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value2)")
                return .Value(value2)
            }, reject: { error2 in
                XCTAssertEqual(expectedError, error2 as NSError)
                expectation2.fulfill()
                return .Error(error2)
        })

        promise1.fulfill("test1")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testChainedThenReturningError() {
        let promise1:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { value1 in
                expectation1.fulfill()
                return .Error(expectedError)
            }, reject: { error1 in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return .Error(error1)
        })
        promise2.then(
            { value2 in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value2)")
                return .Value(value2)
            }, reject: { error2 in
                XCTAssertEqual(expectedError, error2 as NSError)
                expectation2.fulfill()
                return .Error(error2)
        })

        promise1.fulfill("test1")
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testMixedResults() {
        // return error from promise1.fulfill, then subsequently a valid value from promise2.reject
        let promise1:Promise<AnyObject> = Promise()
        let timeout:NSTimeInterval = 5.0
        let expectation1 = expectationWithDescription("expectation1")
        let expectation2 = expectationWithDescription("expectation2")
        let expectation3 = expectationWithDescription("expectation3")
        let expectedValue = "test"
        let promise2 = promise1.then(
            { value in
                expectation1.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .Error(NSError(domain:"promise1error", code:-1, userInfo:nil))
            }, reject: { error in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error)")
                return .Error(error)
        })
        let promise3 = promise2.then(
            { value in
                expectation2.fulfill()
                XCTFail("Should have called reject promise2")
                return .Value(value)
            }, reject: { error in
                expectation2.fulfill()
                XCTAssertEqual("promise1error", (error as NSError).domain)
                return .Value("validResultFromPromise2")
        })
        promise3.then(
            { value in
                expectation3.fulfill()
                if let actualValue = value as? String {
                    XCTAssertEqual("validResultFromPromise2", actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .Value(value)
            }, reject: { error in
                expectation3.fulfill()
                XCTFail("Should not call reject promise3: \(error)")
                return .Error(error)
        })
        promise1.fulfill(expectedValue)
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    // MARK: - Promise.all tests

    func testAllFulfilledAfterCallToAll() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise<AnyObject>] = []
        for _ in 0..<5 {
            expectedPromises.append(Promise())
        }
        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { value in
                if let actualPromises = value {
                    XCTAssertEqual(expectedPromises.count, actualPromises.count)
                    for index in 0..<actualPromises.count {
                        let actualPromise = actualPromises[index]
                        XCTAssertEqual("test\(index)", actualPromise.value as? String)
                    }
                } else {
                    XCTFail("should return list of fulfilled promises")
                }
                expectation.fulfill()
                return .Value(value)
            }, reject: { error in
                XCTFail("should not fail")
                expectation.fulfill()
                return .Error(error)
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

        var expectedPromises:[Promise<String>] = []
        for index in 0..<5 {
            expectedPromises.append(Promise("test\(index)"))
        }
        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { value in
                if let actualPromises = value {
                    XCTAssertEqual(expectedPromises.count, actualPromises.count)
                    for index in 0..<actualPromises.count {
                        let actualPromise = actualPromises[index]
                        XCTAssertEqual("test\(index)", actualPromise.value)
                    }
                } else {
                    XCTFail("should return list of fulfilled promises")
                }
                expectation.fulfill()
                return .Value(value)
            }, reject: { error in
                XCTFail("should not fail")
                expectation.fulfill()
                return .Error(error)
        })

        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

    func testAllWithRejectionAfterCallToAll() {
        let timeout:NSTimeInterval = 5.0
        let expectation = expectationWithDescription("expectation")

        var expectedPromises:[Promise<AnyObject>] = []
        let indexToReject=1
        for _ in 0..<5 {
            expectedPromises.append(Promise())
        }

        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { value in
                XCTFail("should have failed")
                expectation.fulfill()
                return .Value(value)
            }, reject: { error in
                XCTAssertEqual("error\(indexToReject)", (error as NSError).domain)
                expectation.fulfill()
                return .Error(error)
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

        var expectedPromises:[Promise<AnyObject>] = []
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
            { value in
                XCTFail("should have failed")
                expectation.fulfill()
                return .Value(value)
            }, reject: { error in
                XCTAssertEqual("error\(indexToReject)", (error as NSError).domain)
                expectation.fulfill()
                return .Error(error)
        })
        
        waitForExpectationsWithTimeout(timeout, handler: nil)
    }

}
