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
        let promise:Promise<String> = Promise()
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
        let promise:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")
        promise.then(
            { value in
                expectation.fulfill()
                return .value(nil)
            }, reject: { error in
                expectation.fulfill()
                XCTFail("Should not call reject: \(error)")
                return .error(error)
        })
        promise.fulfill("test")
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testSimpleThenNoReject() {
        let promise:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")
        _ = promise.then(
            { value in
                expectation.fulfill()
                return .value(nil)
            }
        )
        promise.fulfill("test")
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testSimpleReject() {
        let promise:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")
        promise.then(
            { value in
                expectation.fulfill()
                XCTFail("Should not call then: \(value)")
                return .value(nil)
            }, reject: { error in
                expectation.fulfill()
                return .error(error)
        })
        promise.reject(NSError(domain: "test", code: -1, userInfo: nil))
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testSimpleChainedThen() {
        let promise1:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation1 = expectation(description: "expectation1")
        let expectation2 = expectation(description: "expectation2")
        let expectation3 = expectation(description: "expectation3")
        let expectedValue = "test"
        let promise2 = promise1.then(
            { value in
                expectation1.fulfill()
                if let actualValue = value {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .value(value)
            }, reject: { error in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error)")
                return .error(error)
        })
        let promise3 = promise2.then(
            { value in
                expectation2.fulfill()
                if let actualValue = value {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .value(value)
            }, reject: { error in
                expectation2.fulfill()
                XCTFail("Should not call reject promise2: \(error)")
                return .error(error)
        })
        promise3.then(
            { value in
                expectation3.fulfill()
                if let actualValue = value {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .value(value)
            }, reject: { error in
                expectation3.fulfill()
                XCTFail("Should not call reject promise3: \(error)")
                return .error(error)
        })
        promise1.fulfill(expectedValue)
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testThenReturnsDelayedPromise() {
        let promise1:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation1 = expectation(description: "expectation1")
        let expectation3 = expectation(description: "expectation3")
        let promise3:Promise<String> = Promise()
        promise1.then(
            { value1 in
                expectation1.fulfill()

                let delayTime = DispatchTime.now() + Double(Int64(timeout/5.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: delayTime) {
                    promise3.fulfill("test3")
                }
                promise3.then(
                    { value3 in
                        expectation3.fulfill()
                        return .value(nil)
                    }, reject: { error3 in
                        expectation3.fulfill()
                        XCTFail("Should not call reject promise3: \(error3)")
                        return .error(error3)
                })
                return .pending(promise3)
            }, reject: { error1 in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return .error(error1)
        })

        promise1.fulfill("test1")
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testSimpleChainedReject() {
        let promise1:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation1 = expectation(description: "expectation1")
        let expectation2 = expectation(description: "expectation2")
        let expectation3 = expectation(description: "expectation3")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { value in
                expectation1.fulfill()
                XCTFail("Should not call then promise1: \(value)")
                return .value(value)
            }, reject: { error in
                XCTAssertEqual(expectedError, error as NSError)
                expectation1.fulfill()
                return .error(error)
        })
        let promise3 = promise2.then(
            { value in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value)")
                return .value(value)
            }, reject: { error in
                XCTAssertEqual(expectedError, error as NSError)
                expectation2.fulfill()
                return .error(error)
        })
        promise3.then(
            { value in
                expectation3.fulfill()
                XCTFail("Should not call then promise3: \(value)")
                return .value(value)
            }, reject: { error in
                XCTAssertEqual(expectedError, error as NSError)
                expectation3.fulfill()
                return .error(error)
        })
        promise1.reject(expectedError)
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testChainedRejectAfterInitialThen() {
        let promise1:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation1 = expectation(description: "expectation1")
        let expectation2 = expectation(description: "expectation2")
        let expectation3 = expectation(description: "expectation3")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { value1 in
                expectation1.fulfill()

                let promise3:Promise<String> = Promise()
                let delayTime = DispatchTime.now() + Double(Int64(timeout/5.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: delayTime) {
                    promise3.reject(expectedError)
                }
                promise3.then(
                    { value3 in
                        expectation3.fulfill()
                        XCTFail("Should not call then promise3: \(value3)")
                        return .value(value3)
                    }, reject: { error3 in
                        expectation3.fulfill()
                        return .error(error3)
                })
                return .pending(promise3)
            }, reject: { error1  in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return .error(error1)
        })
        promise2.then(
            { value2 in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value2)")
                return .value(value2)
            }, reject: { error2 in
                XCTAssertEqual(expectedError, error2 as NSError)
                expectation2.fulfill()
                return .error(error2)
        })

        promise1.fulfill("test1")
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testChainedThenReturningError() {
        let promise1:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation1 = expectation(description: "expectation1")
        let expectation2 = expectation(description: "expectation2")
        let expectedError = NSError(domain:"test", code:-1, userInfo:nil)
        let promise2 = promise1.then(
            { value1 in
                expectation1.fulfill()
                return .error(expectedError)
            }, reject: { error1 in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error1)")
                return .error(error1)
        })
        promise2.then(
            { value2 in
                expectation2.fulfill()
                XCTFail("Should not call then promise2: \(value2)")
                return .value(value2)
            }, reject: { error2 in
                XCTAssertEqual(expectedError, error2 as NSError)
                expectation2.fulfill()
                return .error(error2)
        })

        promise1.fulfill("test1")
        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testMixedResults() {
        // return error from promise1.fulfill, then subsequently a valid value from promise2.reject
        let promise1:Promise<String> = Promise()
        let timeout:TimeInterval = 5.0
        let expectation1 = expectation(description: "expectation1")
        let expectation2 = expectation(description: "expectation2")
        let expectation3 = expectation(description: "expectation3")
        let expectedValue = "test"
        let promise2 = promise1.then(
            { value in
                expectation1.fulfill()
                if let actualValue = value {
                    XCTAssertEqual(expectedValue, actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .error(NSError(domain:"promise1error", code:-1, userInfo:nil))
            }, reject: { error in
                expectation1.fulfill()
                XCTFail("Should not call reject promise1: \(error)")
                return .error(error)
        })
        let promise3 = promise2.then(
            { value in
                expectation2.fulfill()
                XCTFail("Should have called reject promise2")
                return .value(value)
            }, reject: { error in
                expectation2.fulfill()
                XCTAssertEqual("promise1error", (error as NSError).domain)
                return .value("validResultFromPromise2")
        })
        promise3.then(
            { value in
                expectation3.fulfill()
                if let actualValue = value {
                    XCTAssertEqual("validResultFromPromise2", actualValue)
                } else {
                    XCTFail("Expected a String? for the value")
                }
                return .value(value)
            }, reject: { error in
                expectation3.fulfill()
                XCTFail("Should not call reject promise3: \(error)")
                return .error(error)
        })
        promise1.fulfill(expectedValue)
        waitForExpectations(timeout: timeout, handler: nil)
    }

    // MARK: - valueAsPromise tests

    func testTypeSafeValueAsPromiseWithValue() {
        let value = "value"
        let promise:Promise<String> = Promise.valueAsPromise(value)
        XCTAssertEqual(value, promise.value)
        XCTAssertFalse(promise.isPending)
        XCTAssertTrue(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
    }

    func testTypeSafeValueAsPromiseWithError() {
        let error = NSError(domain: "test", code: -1, userInfo: nil)
        let promise:Promise<String> = Promise.valueAsPromise(error)
        XCTAssertEqual(error, promise.error as? NSError)
        XCTAssertFalse(promise.isPending)
        XCTAssertFalse(promise.isFulfilled)
        XCTAssertTrue(promise.isRejected)
    }

    func testTypeSafeValueAsPromiseWithSameTypePromise() {
        let value = "value"
        let existingPromise:Promise<String> = Promise()
        existingPromise.fulfill(value)

        let promise:Promise<String> = Promise.valueAsPromise(existingPromise)
        XCTAssertEqual(value, promise.value)
        XCTAssertFalse(promise.isPending)
        XCTAssertTrue(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
    }

    func testAnyObjectValueAsPromiseWithValue() {
        let value: String? = "value"
        let promise:Promise<String> = Promise.valueAsPromise(value)
        XCTAssertEqual(value, promise.value)
        XCTAssertFalse(promise.isPending)
        XCTAssertTrue(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
    }

    func testAnyObjectValueAsPromiseWithError() {
        let error = NSError(domain: "test", code: -1, userInfo: nil)
        let promise:Promise<String> = Promise.valueAsPromise(error)
        XCTAssertEqual(error, promise.error as? NSError)
        XCTAssertFalse(promise.isPending)
        XCTAssertFalse(promise.isFulfilled)
        XCTAssertTrue(promise.isRejected)
    }

    func testAnyObjectValueAsPromiseWithSameTypePromise() {
        let value: String? = "value"
        let existingPromise:Promise<String> = Promise()
        existingPromise.fulfill(value)

        let promise:Promise<String> = Promise.valueAsPromise(existingPromise)
        XCTAssertEqual(value, promise.value)
        XCTAssertFalse(promise.isPending)
        XCTAssertTrue(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
    }

    func testAnyObjectValueAsPromiseWithCompatibleDifferentTypePromise() {
        let value: Int? = 12345
        let existingPromise:Promise<Int> = Promise()
        existingPromise.fulfill(value)

        let promise:Promise<Int> = Promise.valueAsPromise(existingPromise)
        XCTAssertEqual(value, promise.value)
        XCTAssertFalse(promise.isPending)
        XCTAssertTrue(promise.isFulfilled)
        XCTAssertFalse(promise.isRejected)
    }

    func testAnyObjectValueAsPromiseWithIncompatibleDifferentTypePromise() {
        let value: Int? = 12345
        let existingPromise:Promise<Int> = Promise()
        existingPromise.fulfill(value)

        let promise:Promise<String> = Promise.valueAsPromise(existingPromise)
        XCTAssertTrue(promise.error is PromiseError)
        XCTAssertFalse(promise.isPending)
        XCTAssertFalse(promise.isFulfilled)
        XCTAssertTrue(promise.isRejected)
    }

    // MARK: - Promise.all tests

    func testAllFulfilledAfterCallToAll() {
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")

        var expectedPromises:[Promise<String>] = []
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
                        XCTAssertEqual("test\(index)", actualPromise.value)
                    }
                } else {
                    XCTFail("should return list of fulfilled promises")
                }
                expectation.fulfill()
                return .value(value)
            }, reject: { error in
                XCTFail("should not fail")
                expectation.fulfill()
                return .error(error)
        })

        for index in 0..<expectedPromises.count {
            let expectedPromise = expectedPromises[index]
            expectedPromise.fulfill("test\(index)")
        }

        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testAllFulfilledBeforeCallToAll() {
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")

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
                return .value(value)
            }, reject: { error in
                XCTFail("should not fail")
                expectation.fulfill()
                return .error(error)
        })

        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testAllWithRejectionAfterCallToAll() {
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")

        var expectedPromises:[Promise<String>] = []
        let indexToReject=1
        for _ in 0..<5 {
            expectedPromises.append(Promise())
        }

        let promiseAll = Promise.all(expectedPromises)
        promiseAll.then(
            { value in
                XCTFail("should have failed")
                expectation.fulfill()
                return .value(value)
            }, reject: { error in
                XCTAssertEqual("error\(indexToReject)", (error as NSError).domain)
                expectation.fulfill()
                return .error(error)
        })

        for index in 0..<expectedPromises.count {
            let expectedPromise = expectedPromises[index]
            if (index == indexToReject) {
                expectedPromise.reject(NSError(domain:"error\(index)", code:-1, userInfo:nil))
            } else {
                expectedPromise.fulfill("test\(index)")
            }
        }

        waitForExpectations(timeout: timeout, handler: nil)
    }

    func testAllWithRejectionBeforeCallToAll() {
        let timeout:TimeInterval = 5.0
        let expectation = self.expectation(description: "expectation")

        var expectedPromises:[Promise<String>] = []
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
                return .value(value)
            }, reject: { error in
                XCTAssertEqual("error\(indexToReject)", (error as NSError).domain)
                expectation.fulfill()
                return .error(error)
        })
        
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
}
