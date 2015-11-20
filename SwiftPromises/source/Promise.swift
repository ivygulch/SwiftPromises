//
//  Promise.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

// MARK: - Promise

/**
A Swift version of the Promise pattern popular in the javascript world

"A promise represents the eventual result of an asynchronous operation.
The primary way of interacting with a promise is through its then method,
which registers callbacks to receive either a promise’s eventual value or
the reason why the promise cannot be fulfilled."  (https://promisesaplus.com)

"The point of promises is to give us back functional composition and error
bubbling in the async world. They do this by saying that your functions
should return a promise, which can do one of two things:

*  Become fulfilled by a value
*  Become rejected with an error" (https://gist.github.com/domenic/3889970)

*/
public class Promise<T> : NSObject {

    // MARK: - Interface

    /**
    This initializer needs to check for Promise<T> or ErrorType values to handle the
    case where T is Any and those then become valid argument values.

    - Returns: an immutable, fulfilled promise using the supplied value
    */
    public static func valueAsPromise(value: T?) -> Promise<T> {
        if let existingPromise = value as? Promise<T> {
            return existingPromise
        } else if let error = value as? ErrorType {
            return Promise(error)
        } else {
            return Promise(value)
        }
    }

    /**
     This initializer checks for Promise values that are not type T which requires
     special handling. Since Swift cannot currently require R to be assignment
     compatible with T, the only choice is to reject the promise if an incompatible
     value is returned from the original promise.

     This initializer is necessary because if T is Any, then Promise<R> where R is not T,
     will be passed through as a normal value in the primary initializer.  This specialized
     initializer forces it through this path.

     - Returns: convenience method wrapping a promise of a different subtype than T
     */
    public static func valueAsPromise<R>(existingPromise: Promise<R>) -> Promise<T> {
        let result:Promise<T> = Promise()
        existingPromise.then(
            {
                value in
                if let t = value as? T {
                    result.fulfill(t)
                } else {
                    let errorMessage = "original promise was fulfilled with \(value), but it could not be converted to \(T.self) so fulfilling dependent promise with nil"
                    let error = PromiseError.MismatchPromiseValueTypes(errorMessage)
                    result.reject(error)
                }
                return .Value(value)
            },
            reject:
            {
                error in
                result.reject(error)
                return .Error(error)
            }
        )
        return result
    }

    /**
     This initializer frees the client code from needing to check if the value being
     passed in is a promise already or not.

     This version is necessary for those cases where T is NOT Any, so the
     first initializer would not be used by the compiler.

     - Returns: an immutable, fulfilled promise using an existing promise
     */
    public static func valueAsPromise(value: Promise<T>) -> Promise<T> {
        return value
    }

    /**
     - Returns: an immutable, rejected promise using the supplied error
     */
    public class func valueAsPromise(value: ErrorType) -> Promise<T> {
        return Promise(value)
    }

    /**
     - Parameter promises: list of generic promises that act as dependencies

     - Returns: a dependent promise that is fulfilled when all the supplied promises
     are fulfilled or rejected when one or more are rejected
     */
    public class func all(promises:[Promise]) -> Promise<[Promise]> {
        let result:Promise<[Promise]> = Promise<[Promise]>()
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
     Creates a new pending promise with no chained promises
     */
    public override init() {
        state = .Pending([])
    }

    /**
     Creates a new immutable fulfilled promise with an optional type-safe value and no chained promises

     This can be useful when an async user code process needs to return a promise, but already
     has the result (such as with a completed network request, database query, etc.)
     */
    public init(_ value:T?) {
        state = .Fulfilled(value)
    }

    /**
     Creates a new immutable rejected promise with an error and no chained promises

     This can be useful when an async user code process needs to return a promise, but already
     has an error result (such as with a completed network request, database query, etc.)
     */
    public init(_ error:ErrorType) {
        state = .Rejected(error)
    }

    /**
     Read-only property that is true if the promise is still pending
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
     Read-only property that is true if the promise has been fulfilled
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
     Read-only property that is true if the promise has been rejected
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
     Read-only property that is the fulfilled value if the promise has been fulfilled, nil otherwise
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
     Read-only property that is the rejection error if the promise has been rejected, nil otherwise
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
     If the promise is pending, then change its state to fulfilled using the supplied value
     and notify any chained promises that it has been fulfilled.  If the promise is in any other
     state, no changes are made and any chained promises are ignored.

     - Parameter value: optional fulfilled value to use for the promise
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
     If the promise is pending, then change its state to rejected using the supplied error
     and notify any chained promises that it has been rejected.  If the promise is in any other
     state, no changes are made and any chained promises are ignored.

     - Parameter error: rejection error to use for the promise
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
     This method lets your code add dependent results to an existing promise.

     'fulfill' and 'reject' closures may be added to a promise at any time. If the promise is
     eventually fulfilled, the fulfill closure will be called one time, and the reject closure
     will never be called. If the promise is eventually rejected, the reject closure will be
     called one time, and the fulfill closure will never be called.  If the promise remains in
     a pending state, neither closure will ever be called.

     This method may be called as many times as needed, and the appropriate closures will be
     called in the order they were added via the then method.

     If the promise is pending, then they will be added to the list of closures to be processed
     once the promise is fulfilled or rejected in the future.

     If the promise is already fulfilled, then the fulfill closure will be called immediately

     If the promise is already rejected, then if the reject closure exists, it will be called immediately

     - Parameter fulfill: closure to call when the promise is fulfilled that returns an instance of PromiseClosureResult

     - Parameter reject: optional rejection closure to call when the promise is rejected that returns an instance of PromiseClosureResult

     If the reject closure does not exist, it will simply pass the .Error(errorType) value down the promise chain

     If it does exist, it returns an instance of PromiseClosureResult, just as the fulfill closure does.

     (Note that this means that either closure can redirect dependent promises in the chain, which can
     allow a reject closure to to recover by supplying a valid value so subsequent promises can continue)

     - Returns: a new instance of a promise to which application code can add dependent promises (e.g. chaining)
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

    /**
     A convenience method with a nil reject closure.
     Since Objective-C does not recognize default parameters, this provides a work-around.
     */
    public func then(fulfill: ((T?) -> PromiseClosureResult<T>)) -> Promise<T> {
        return then(fulfill, reject: nil)
    }

    // MARK: - private values

    private var state: PromiseState<T> = .Pending([])
    private let stateSynchronizer = Synchronizer()

}

// MARK: -

// MARK: Public error types

/**
Custom errors generated from within the SwiftPromise framework
*/
public enum PromiseError: ErrorType {
    case MismatchPromiseValueTypes(String)
}

// MARK: Public helper enum PromiseClosureResult

/**
PromiseClosureResult is returned by promise fulfill and reject closures so they can return
a type-safe value, an error, or a promise to be used in the promise chain.  This allows
either type of closure to pass along a similar value (e.g. type-safe value -> type-safe value)
or redirect the dependent, chained promises into an alternative path by returning a type-safe
value from a reject closure.

<ul>
<li>.Value - it will cause any dependent promises to be fulfilled with the associated type-safe value</li>
<li>.Error - it will cause any dependent promises to be rejected with the associated error value</li>
<li>.Pending - it will chain this instance's resolution to the associated promise's resolution</li>
</ul>
*/
public enum PromiseClosureResult<T> {
    /**
     Associated value is required and is the error that will trigger
     the reject closure for a promise
     */
    case Error(ErrorType)
    /**
     Associated value is optional and is the type-safe result that will trigger
     the fulfill closure for a promise
     */
    case Value(T?)
    /**
     Associated value is required and is a type-safe promise that the owning promise will be dependent
     on for a result before the owning promise can be fulfilled or rejected
     */
    case Pending(Promise<T>)
}

// MARK: -
// MARK: Private helper enum PromiseState

private enum PromiseState<T> {
    case Pending([PromiseAction<T>])
    case Fulfilled(T?)
    case Rejected(ErrorType)
}

// MARK: Private helper class PromiseAction

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