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
open class Synchronizer : NSObject {
    private let queue:DispatchQueue

    /**
     Creates a new synchronizer that uses a newly created, custom queue with a random name
     */
    public override init() {
        let uuid = UUID().uuidString
        self.queue = DispatchQueue(label: "Sync.\(uuid)",attributes: [])
    }

    /**
     Creates a new synchronizer that uses a newly created, custom queue with a given name
     */
    public init(queueName:String) {
        self.queue = DispatchQueue(label: queueName,attributes: [])
    }

    /**
     Creates a new synchronizer that uses an existing dispatch queue
     */
    public init(queue:DispatchQueue) {
        self.queue = queue
    }

    /**
     - Parameter closure: the closure to be synchronized
     */
    public func synchronize(_ closure:()->Void) {
        queue.sync(execute: {
            closure()
        })
    }
    
}
