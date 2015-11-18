//
//  Synchronizer.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

public class Synchronizer : NSObject {
    private let queue:dispatch_queue_t

    public override init() {
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