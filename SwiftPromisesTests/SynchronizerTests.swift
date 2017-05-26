//
//  SynchronizerTests.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 2/26/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import Foundation
import XCTest
import SwiftPromises

class SynchronizerTests: XCTestCase {

    func testLock () {
        var locked = false
        let numBlocks = 10
        let sleepSeconds = 1
        let timeout:TimeInterval = Double(numBlocks * sleepSeconds * 2)

        let synchronizer = Synchronizer()

        for count in 1...numBlocks {
            let expectation = self.expectation(description: "expectation\(count)")
            print("before dispatch \(count)")
            DispatchQueue.global(qos: .default).async {
                synchronizer.synchronize {
                    print("begin block \(count)")
                    XCTAssertFalse(locked, "should start with locked=false")
                    locked = true
                    sleep(UInt32(sleepSeconds))
                    locked = false
                    expectation.fulfill()
                    print("end block \(count)")
                }
            }
            print("after dispatch \(count)")
        }

        waitForExpectations(timeout: timeout, handler: nil)
    }
    
}
