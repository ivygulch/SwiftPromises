//
//  Promise.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

public typealias kPromiseFulfillClosure = (AnyObject?) -> AnyObject?
public typealias kPromiseRejectClosure = (NSError) -> AnyObject?

private enum PromiseState {
    case Pending([PromiseAction])
    case Fulfilled(AnyObject?)
    case Rejected(NSError)
}

/**
* A Swift version of the Promise pattern popular in the javascript world
*
* "A promise represents the eventual result of an asynchronous operation.
* The primary way of interacting with a promise is through its then method, 
* which registers callbacks to receive either a promise’s eventual value or 
* the reason why the promise cannot be fulfilled."  (https://promisesaplus.com) 
*
* "The point of promises is to give us back functional composition and error
* bubbling in the async world. They do this by saying that your functions 
* should return a promise, which can do one of two things:
*  - Become fulfilled by a value
*  - Become rejected with an error" (https://gist.github.com/domenic/3889970)
*
*/
@objc public class Promise {

    // MARK: - Interface

    // needed for objc usage since we do not inherit from NSObject
    public class func newInstance() -> Promise {
        return Promise()
    }

    public class func valueAsPromise(value: AnyObject?) -> Promise {
        if let result = value as? Promise {
            return result
        } else {
            return Promise(value)
        }
    }

    public class func all(promises:[Promise]) -> Promise {
        let result = Promise()
        var completedPromiseCount = 0
        let synchronizer = Synchronizer()

        for promise in promises {
            promise.then(
                { (value) -> AnyObject? in
                    synchronizer.synchronize({
                        completedPromiseCount += 1
                    })
                    if (completedPromiseCount == promises.count) {
                        result.fulfill(promises)
                    }
                    return value
                }, reject: { (error) -> NSError in
                    result.reject(error)
                    return error
                }
            )
        }

        return result
    }

    /**
    * Initializes a new pending promise
    *
    * :returns: A pending promise with no chained promises
    */
    init() {
        state = .Pending([])
    }

    /**
    * Initializes a new promise with either an error or a value (which may be nil).
    *
    * If the argument is an error, then the state is set to .Rejected otherwise it is set to .Fulfilled
    * In either case, the promise state (by definition) is then immutable.
    *
    * This can be useful when an async user code process needs to return a promise, but already
    * has the result (such as with a completed network request, database query, etc.)
    *
    * :returns: A rejected or fulfilled promise with no chained promises
    */
    init(_ value:AnyObject?) {
        if let error = value as? NSError {
            state = .Rejected(error)
        } else {
            state = .Fulfilled(value)
        }
    }

    /**
    * Read-only property that is true if the promise is still pending
    */
    public var isPending: Bool {
        get {
            var result = false
            stateSynchronizer.synchronize {
                switch (self.state) {
                case .Pending(let promiseActions):
                    result = true
                default:
                    result = false
                }
            }
            return result
        }
    }

    /**
    * Read-only property that is true if the promise has been fulfilled
    */
    public var isFulfilled: Bool {
        get {
            var result = false
            stateSynchronizer.synchronize {
                switch (self.state) {
                case .Fulfilled(let value):
                    result = true
                default:
                    result = false
                }
            }
            return result
        }
    }

    /**
    * Read-only property that is true if the promise has been rejected
    */
    public var isRejected: Bool {
        get {
            var result = false
            stateSynchronizer.synchronize {
                switch (self.state) {
                case .Rejected(let error):
                    result = true
                default:
                    result = false
                }
            }
            return result
        }
    }

    /**
    * Read-only property that is the fulfilled value if the promise has been fulfilled, nil otherwise
    */
    public var value: AnyObject? {
        var result:AnyObject? = nil
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Fulfilled(let value):
                result = value
            default:
                result = nil
            }
        }
        return result
    }

    /**
    * Read-only property that is the rejection error if the promise has been rejected, nil otherwise
    */
    public var error: NSError? {
        var result:NSError? = nil
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Rejected(let error):
                result = error
            default:
                result = nil
            }
        }
        return result
    }

    /**
    * If the promise is pending, then change its state to fulfilled using the supplied value
    * and notify any chained promises that it has been fulfilled.  If the promise is in any other
    * state, no changes are made and any chained promises are ignored.
    *
    * :param: the fulfilled value to use for the promise
    */
    public func fulfill(value: AnyObject?) {
        var promiseActionsToFulfill:[PromiseAction] = []
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Pending(let promiseActions):
                self.state = .Fulfilled(value)
                promiseActionsToFulfill = promiseActions
            default:
                println("WARN: cannot fulfill promise, state already set to \(self.state)")
            }
        }
        for promiseAction in promiseActionsToFulfill {
            promiseAction.fulfill(value)
        }
    }

    /**
    * If the promise is pending, then change its state to rejected using the supplied error
    * and notify any chained promises that it has been rejected.  If the promise is in any other
    * state, no changes are made and any chained promises are ignored.
    *
    * :param: the rejection error to use for the promise
    */
    public func reject(error: NSError) {
        var promiseActionsToReject:[PromiseAction] = []
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Pending(let promiseActions):
                self.state = .Rejected(error)
                promiseActionsToReject = promiseActions
            default:
                println("WARN: cannot reject promise, state already set to \(self.state)")
            }
        }
        for promiseAction in promiseActionsToReject {
            promiseAction.reject(error)
        }
    }

    /**
    * 'fulfill' and 'reject' closures may be added to a promise at any time. If the promise is
    * eventually fulfilled, the fulfill closure will be called one time, and the reject closure
    * will never be called. If the promise is eventually rejected, the reject closure will be
    * called one time, and the fulfill closure will never be called.  If the promise remains in
    * a pending state, neither closure will ever be called.
    *
    * This method may be called as many times as needed, and the appropriate closures will be
    * called in the order they were added via the then method.
    *
    * If the promise is pending, then they will be added to the list of closures to be processed
    * once  the promise is fulfilled or rejected in the future.
    *
    * If the promise is already fulfilled, then the fulfill closure will be called immediately
    *
    * If the promise is already rejected, then if the reject closure exists, it will be called immediately
    *
    * :param: fulfill closure to call when the promise is fulfilled
    *   It can return:
    *       an NSError: it will cause any dependent promises to be rejected with this error
    *       a Promise: it will be chained to this instance
    *       any other value including nil: it will cause any dependent promises to be fulfilled with this value
    *
    * :param: optional rejection closure to call when the promise is rejected
    *
    * :returns: a new instance of a promise to which application code can add dependent promises (e.g. chaining)
    */
    public func then(fulfill: kPromiseFulfillClosure, reject: kPromiseRejectClosure?) -> Promise {
        let result = Promise()
        let promiseAction = PromiseAction(result, fulfill, reject)
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Pending(var promiseActions):
                promiseActions.append(promiseAction)
                self.state = .Pending(promiseActions)
            case .Fulfilled(let value):
                promiseAction.fulfill(value)
            case .Rejected(let error):
                promiseAction.reject(error)
            }
        }
        return result
    }

    // Need separate method definition since Objective-C does not recognizer default parameters
    public func then(fulfill: kPromiseFulfillClosure) -> Promise {
        return then(fulfill, nil)
    }

    // MARK: - implementation

    private var state: PromiseState = .Pending([])
    private let stateSynchronizer = Synchronizer()

}

private class PromiseAction {
    private let promise: Promise
    private let fulfillClosure: kPromiseFulfillClosure
    private let rejectClosure: kPromiseRejectClosure?

    init(_ promise: Promise, _ fulfillClosure: kPromiseFulfillClosure, rejectClosure: kPromiseRejectClosure?) {
        self.promise = promise
        self.fulfillClosure = fulfillClosure
        self.rejectClosure = rejectClosure
    }

    func fulfill(value: AnyObject?) {
        let result: (AnyObject?) = fulfillClosure(value)
        processValue(result)
    }

    func reject(error: NSError) {
        let result: (AnyObject?) = (rejectClosure == nil) ? error : rejectClosure!(error)
        processValue(result)
    }

    func processValue(value: AnyObject?) {
        if let promiseResult = value as? Promise {
            promiseResult.then(
                { (value) -> AnyObject? in
                    self.promise.fulfill(value)
                    return value
                }, reject: { (error) -> NSError in
                    self.promise.reject(error)
                    return error
                }
            )
        } else if let errorResult = value as? NSError {
            promise.reject(errorResult)
        } else {
            promise.fulfill(value)
        }
    }


}
