//
//  Synchronizer.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

@objc public class Synchronizer {
    private let queue:dispatch_queue_t

    // needed for objc usage since we do not inherit from NSObject
    public class func newInstance() -> Promise {
        return Promise()
    }

    public init() {
        let uuid = NSUUID().UUIDString
        self.queue = dispatch_queue_create("Sync.\(uuid)",nil)
    }

    public init(queueName:String) {
        self.queue = dispatch_queue_create(queueName,nil)
    }

    public init(queue:dispatch_queue_t) {
        self.queue = queue
    }

    public func synchronize(closure:()->Void) {
        dispatch_sync(queue, {
            closure()
        })
    }

}