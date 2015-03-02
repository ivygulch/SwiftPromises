//
//  TimeoutNetworkCallDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit

class TimeoutNetworkCallDemoViewController: BaseDemoViewController {

    @IBOutlet var timeoutStepper:UIStepper?
    @IBOutlet var timeoutLabel:UILabel?
    @IBOutlet var urlTextField:UITextField?
    @IBOutlet var urlStatusImageView:UIImageView?
    @IBOutlet var finalStatusImageView:UIImageView?

    var timeoutTimer:NSTimer?

    override func readyToStart() -> Bool {
        return (urlTextField!.value != nil)
    }

    override func updateUI() {
        super.updateUI()

        timeoutLabel!.text =  "Timeout: \(timeoutStepper!.value)"
    }

    func startTimer(promise:Promise) {
        timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutStepper!.value, target:self, selector:"handleTimeoutTimer:", userInfo:promise, repeats:false)
    }

    func stopTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    func handleTimeoutTimer(timer:NSTimer) {
        let promise = timer.userInfo as Promise
        promise.reject(NSError(domain:"Timeout before completion", code:-1, userInfo:nil))
    }

    override func start() {
        clearStatus()
        clearLog()

        startActivityIndicator()
        let url = NSURL(string:urlTextField!.text)!
        let urlPromise = loadURLPromise(url)
        startTimer(urlPromise)

        urlPromise.then(
            { [weak self] (value) -> AnyObject? in
                self?.log("final success: \(value)")
                self?.finalStatusImageView!.setStatus(true)
                self?.stopActivityIndicator()
                self?.stopTimer()
                return value
            }, reject: { [weak self] (error) -> AnyObject? in
                self?.log("final error: \(error.localizedDescription)")
                self?.finalStatusImageView!.setStatus(false)
                self?.stopActivityIndicator()
                self?.stopTimer()
                return error
            }
        )

    }

    @IBAction func timeoutStepperAction(stepper:UIStepper) {
        updateUI()
    }

}
