//
//  TimeoutNetworkCallDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit
import SwiftPromises

class TimeoutNetworkCallDemoViewController: BaseDemoViewController {

    @IBOutlet var timeoutStepper:UIStepper?
    @IBOutlet var timeoutLabel:UILabel?
    @IBOutlet var urlTextField:UITextField?
    @IBOutlet var urlStatusImageView:UIImageView?
    @IBOutlet var finalStatusImageView:UIImageView?

    var timeoutTimer:NSTimer?

    override func viewWillAppear(animated: Bool) {
        urlTextField!.text = "http://cnn.com"

        super.viewWillAppear(animated)
    }

    override func readyToStart() -> Bool {
        return (urlTextField!.value != nil)
    }

    override func updateUI() {
        super.updateUI()

        timeoutLabel!.text =  "Timeout: \(timeoutStepper!.value)"
    }

    func startTimer(promise:Promise<NSData>) {
        timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutStepper!.value, target:self, selector:"handleTimeoutTimer:", userInfo:promise, repeats:false)
    }

    func stopTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    func handleTimeoutTimer(timer:NSTimer) {
        let promise = timer.userInfo as! Promise<NSData>
        promise.reject(NSError(domain:"Timeout before completion", code:-1, userInfo:nil))
    }

    override func start() {
        clearStatus()
        clearLog()

        startActivityIndicator()
        if let text = urlTextField?.text, url = NSURL(string:text) {
            let urlPromise = loadURLPromise(url)
            startTimer(urlPromise)

            urlPromise.then(
                { [weak self] value in
                    self?.log("final success")
                    self?.finalStatusImageView!.setStatus(true)
                    self?.stopActivityIndicator()
                    self?.stopTimer()
                    return .Value(value)
                }, reject: { [weak self] error in
                    self?.log("final error: \(error)")
                    self?.finalStatusImageView!.setStatus(false)
                    self?.stopActivityIndicator()
                    self?.stopTimer()
                    return .Error(error)
                }
            )
        }
    }

    @IBAction func timeoutStepperAction(stepper:UIStepper) {
        updateUI()
    }

}
