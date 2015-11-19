//
//  Synchronizer.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/25/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation

/**
A simple helper class that uses dispatch_sync to emulate Objective-C's @synchronize behavior
in swift classes.
 
Example usage:

```swift
let synchronizer = Synchronizer()

func functionAToBeSynchronized() {
    synchronizer.synchronize {
        // this is the code to be synchronized
    }
}

func functionBToBeSynchronized() {
    synchronizer.synchronize {
        // this is the code to be synchronized
    }
}
```
*/
public class Synchronizer : NSObject {
    private let queue:dispatch_queue_t

    /**
     Creates a new synchronizer that uses a newly created, custom queue with a random name
     */
    public override init() {
        let uuid = NSUUID().UUIDString
        self.queue = dispatch_queue_create("Sync.\(uuid)",nil)
    }

    /**
     Creates a new synchronizer that uses a newly created, custom queue with a given name
     */
    public init(queueName:String) {
        self.queue = dispatch_queue_create(queueName,nil)
    }

    /**
     Creates a new synchronizer that uses an existing dispatch queue
     */
    public init(queue:dispatch_queue_t) {
        self.queue = queue
    }

    /**
     - Parameter closure: the closure to be synchronized
     */
    public func synchronize(closure:()->Void) {
        dispatch_sync(queue, {
            closure()
        })
    }
    
}