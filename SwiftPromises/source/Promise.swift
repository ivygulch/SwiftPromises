//
//  Promise.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

public enum PromiseClosureResult<T> {
    case Error(ErrorType)
    case Value(T?)
    case Pending(Promise<T>)
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
public class Promise<T> : NSObject {

    // MARK: - Interface

    public class func valueAsPromise(value: T?) -> Promise<T> {
        return Promise(value)
    }

    public class func valueAsPromise(value: ErrorType) -> Promise<T> {
        return Promise(value)
    }

    public class func all(promises:[Promise<T>]) -> Promise<[Promise<T>]> {
        let result:Promise<[Promise<T>]> = Promise<[Promise<T>]>()
        var completedPromiseCount = 0
        let synchronizer = Synchronizer()

        for promise in promises {
            promise.then(
                {
                    value in
                    synchronizer.synchronize({
                        completedPromiseCount += 1
                    })
                    if (completedPromiseCount == promises.count) {
                        result.fulfill(promises)
                    }
                    return .Value(value)
                }, reject: {
                    error in
                    result.reject(error)
                    return .Error(error)
                }
            )
        }

        return result
    }

    /**
    * Initializes a new pending promise
    *
    * - returns: A pending promise with no chained promises
    */
    public override init() {
        state = .Pending([])
    }

    /**
     * Initializes a new promise with either a value (which may be nil).
     *
     * The state is set to .Fulfilled which by definition is then immutable.
     *
     * This can be useful when an async user code process needs to return a promise, but already
     * has the result (such as with a completed network request, database query, etc.)
     *
     * - returns: A fulfilled promise with no chained promises
     */
    public init(_ value:T?) {
        state = .Fulfilled(value)
    }

    /**
     * Initializes a new promise with an error
     *
     * The state is set to .Rejected which by definition is then immutable.
     *
     * This can be useful when an async user code process needs to return a promise, but already
     * has an error result (such as with a completed network request, database query, etc.)
     *
     * - returns: A rejected promise with no chained promises
     */
    public init(_ error:ErrorType) {
        state = .Rejected(error)
    }

    /**
    * Read-only property that is true if the promise is still pending
    */
    public var isPending: Bool {
        get {
            var result = false
            stateSynchronizer.synchronize {
                switch (self.state) {
                case .Pending( _):
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
                case .Fulfilled( _):
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
                case .Rejected( _):
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
    public var value: T? {
        var result:T?
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
    public var error: ErrorType? {
        var result:ErrorType?
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
    * - parameter the: fulfilled value to use for the promise
    */
    public func fulfill(value: T?) {
        var promiseActionsToFulfill:[PromiseAction<T>] = []
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Pending(let promiseActions):
                self.state = .Fulfilled(value)
                promiseActionsToFulfill = promiseActions
            default:
                print("WARN: cannot fulfill promise, state already set to \(self.state)")
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
    * - parameter the: rejection error to use for the promise
    */
    public func reject(error: ErrorType) {
        var promiseActionsToReject:[PromiseAction<T>] = []
        stateSynchronizer.synchronize {
            switch (self.state) {
            case .Pending(let promiseActions):
                self.state = .Rejected(error)
                promiseActionsToReject = promiseActions
            default:
                print("WARN: cannot reject promise, state already set to \(self.state)")
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
    * - parameter fulfill: closure to call when the promise is fulfilled
    *   It can return:
    *       an ErrorType: it will cause any dependent promises to be rejected with this error
    *       a Promise: it will be chained to this instance
    *       any other value including nil: it will cause any dependent promises to be fulfilled with this value
    *
    * - parameter optional: rejection closure to call when the promise is rejected
    *
    * - returns: a new instance of a promise to which application code can add dependent promises (e.g. chaining)
    */
    public func then(fulfill: ((T?) -> PromiseClosureResult<T>), reject: ((ErrorType) -> PromiseClosureResult<T>)?) -> Promise<T> {
        let result:Promise<T> = Promise()
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
    public func then(fulfill: ((T?) -> PromiseClosureResult<T>)) -> Promise<T> {
        return then(fulfill, reject: nil)
    }

    // MARK: - implementation

    private var state: PromiseState<T> = .Pending([])
    private let stateSynchronizer = Synchronizer()

}

private class PromiseAction<T> {
    private let promise: Promise<T>
    private let fulfillClosure: ((T?) -> PromiseClosureResult<T>)
    private let rejectClosure: ((ErrorType) -> PromiseClosureResult<T>)?

    init(_ promise: Promise<T>, _ fulfillClosure: ((T?) -> PromiseClosureResult<T>), _ rejectClosure: ((ErrorType) -> PromiseClosureResult<T>)?) {
        self.promise = promise
        self.fulfillClosure = fulfillClosure
        self.rejectClosure = rejectClosure
    }
    

    func fulfill(value: T?) {
        let result = fulfillClosure(value)
        processClosureResult(result)
    }

    func reject(error: ErrorType) {
        var rejectResult:PromiseClosureResult<T> = .Error(error)
        if let rejectClosure = rejectClosure {
            rejectResult = rejectClosure(error)
        }
        processClosureResult(rejectResult)
    }

    func processClosureResult(promiseClosureResult: PromiseClosureResult<T>) {
        switch promiseClosureResult {
        case .Error(let error):
            self.promise.reject(error)
        case .Value(let value):
            self.promise.fulfill(value)
        case .Pending(let pendingPromise):
            pendingPromise.then(
                {
                    result in
                    self.promise.fulfill(result)
                    return .Value(result)
                },
                reject:
                {
                    error in
                    self.promise.reject(error)
                    return .Error(error)
                }
            )
        }
    }


}

// MARK: private helper definitions

private enum PromiseState<T> {
    case Pending([PromiseAction<T>])
    case Fulfilled(T?)
    case Rejected(ErrorType)
}
