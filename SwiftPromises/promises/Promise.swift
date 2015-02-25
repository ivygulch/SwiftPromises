//
//  Promise.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

typealias kPromiseFulfillClosure = (AnyObject?) -> AnyObject?
typealias kPromiseRejectClosure = (NSError) -> NSError

class PromiseAction {
    private let internalFulfillClosure: kPromiseFulfillClosure!
    private let internalRejectClosure: kPromiseRejectClosure!

    init(_ promise: Promise, _ fulfillClosure: kPromiseFulfillClosure, rejectClosure: kPromiseRejectClosure?) {
        internalFulfillClosure = {(value: AnyObject?) -> AnyObject? in
            let fulfillResult: (AnyObject?) = fulfillClosure(value)
            if let promiseResult = fulfillResult as? Promise {
                promiseResult.then({ (value) -> AnyObject? in
                    promise.fulfill(value)
                    return value
                    }, reject: { (error) -> NSError in
                        promise.reject(error)
                        return error
                })
            } else if let errorResult = fulfillResult as? NSError {
                promise.reject(errorResult)
            } else {
                promise.fulfill(fulfillResult)
            }
            return fulfillResult
        }
        internalRejectClosure = {(error: NSError) -> NSError in
            let rejectResult = (rejectClosure == nil) ? error : rejectClosure!(error)
            promise.reject(rejectResult)
            return rejectResult
        }
    }

    func fulfill(value: AnyObject?) {
        internalFulfillClosure(value)
    }

    func reject(error: NSError) {
        internalRejectClosure(error)
    }

}

private enum PromiseState {
    case Pending([PromiseAction])
    case Fulfilled(AnyObject?)
    case Rejected(NSError)
}


class Promise {
    private var state: PromiseState

    init() {
        state = .Pending([])
    }

    init(_ error:NSError) {
        state = .Rejected(error)
    }


    init(_ value:AnyObject?) {
        state = .Fulfilled(value)
    }

    func isPending() -> Bool {
        switch (state) {
        case .Pending(let promiseActions):
            return true
        default:
            return false
        }
    }

    func isFulfilled() -> Bool {
        switch (state) {
        case .Fulfilled(let value):
            return true
        default:
            return false
        }
    }

    func isRejected() -> Bool {
        switch (state) {
        case .Rejected(let error):
            return true
        default:
            return false
        }
    }

    func value() -> AnyObject? {
        switch (state) {
        case .Fulfilled(let value):
            return value
        default:
            return nil
        }
    }

    func error() -> NSError? {
        switch (state) {
        case .Rejected(let error):
            return error
        default:
            return nil
        }
    }

    func fulfill(value: AnyObject?) {
        switch (state) {
        case .Pending(let promiseActions):
            state = .Fulfilled(value)
            for promiseAction in promiseActions {
                promiseAction.fulfill(value)
            }
        default:
            println("WARN: cannot fulfill promise, state already set to \(state)")
        }
    }

    func reject(error: NSError) {
        switch (state) {
        case .Pending(let promiseActions):
            state = .Rejected(error)
            for promiseAction in promiseActions {
                promiseAction.reject(error)
            }
        default:
            println("WARN: cannot reject promise, state already set to \(state)")
        }
    }

    func then(fulfill: kPromiseFulfillClosure, reject: kPromiseRejectClosure? = nil) -> Promise {
        let result = Promise()
        let promiseAction = PromiseAction(result, fulfill, reject)
        switch (state) {
        case .Pending(var promiseActions):
            promiseActions.append(promiseAction)
            state = .Pending(promiseActions)
        case .Fulfilled(let value):
            promiseAction.fulfill(value)
        case .Rejected(let error):
            promiseAction.reject(error)
        }
        return result
    }
}
