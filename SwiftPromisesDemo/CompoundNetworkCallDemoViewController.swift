//
//  CompoundNetworkCallDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit
import SwiftPromises

class CompoundNetworkCallDemoViewController: BaseDemoViewController {

    @IBOutlet var url1TextField:UITextField?
    @IBOutlet var url2aTextField:UITextField?
    @IBOutlet var url2bTextField:UITextField?
    @IBOutlet var url3TextField:UITextField?
    @IBOutlet var delay2aStepper:UIStepper?
    @IBOutlet var delay2bStepper:UIStepper?
    @IBOutlet var delay2aLabel:UILabel?
    @IBOutlet var delay2bLabel:UILabel?
    @IBOutlet var url1StatusImageView:UIImageView?
    @IBOutlet var url2aStatusImageView:UIImageView?
    @IBOutlet var url2bStatusImageView:UIImageView?
    @IBOutlet var url3StatusImageView:UIImageView?
    @IBOutlet var finalStatusImageView:UIImageView?
    @IBOutlet var stopOnErrorSwitch:UISwitch?

    override func viewWillAppear(animated: Bool) {
        url1TextField!.text = "http://cnn.com"
        url2aTextField!.text = "http://apple.com"
        url2bTextField!.text = "http://dilbert.com"
        url3TextField!.text = "http://nytimes.com"

        super.viewWillAppear(animated)
    }

    override func clearStatus() {
        url1StatusImageView!.setStatus(nil)
        url2aStatusImageView!.setStatus(nil)
        url2bStatusImageView!.setStatus(nil)
        url3StatusImageView!.setStatus(nil)
        finalStatusImageView!.setStatus(nil)
    }

    override func readyToStart() -> Bool {
        return true
    }

    override func updateUI() {
        super.updateUI()

        delay2aLabel!.text =  "Delay2a: \(delay2aStepper!.value)"
        delay2bLabel!.text =  "Delay2b: \(delay2bStepper!.value)"
    }
    
    override func start() {
        clearStatus()
        clearLog()

        startActivityIndicator()

        loadURL1StepPromise().then(
            { [weak self] value in
                let result:Promise<NSData> = Promise()
                self?.log("loading promise2a and promise2b")
                var promises:[Promise<NSData>] = []
                if let strongSelf = self {
                    promises.append(strongSelf.loadURL2aStepPromise())
                    promises.append(strongSelf.loadURL2bStepPromise())
                }
                Promise.all(promises).then(
                    {
                        value in
                        result.fulfill(nil)
                        return .Value(value)
                    },
                    reject: {
                        error in
                        result.reject(error)
                        return .Error(error)
                    }
                )
                return .Pending(result)
        } ).then(
            { [weak self] value in
                return .Pending(self!.loadURL3StepPromise())
        }).then(
            { [weak self] value in
                self?.log("final success")
                self?.finalStatusImageView!.setStatus(true)
                self?.stopActivityIndicator()
                return .Value(value)
            }, reject: { [weak self] error in
                self?.log("final error: \(error)")
                self?.finalStatusImageView!.setStatus(false)
                self?.stopActivityIndicator()
                return .Error(error)
        })

    }

    func loadURL1StepPromise() -> Promise<NSData> {
        return loadURLStepPromise(url1TextField!.text, statusImageView:url1StatusImageView!, delay:0.0)
    }

    func loadURL2aStepPromise() -> Promise<NSData> {
        return loadURLStepPromise(url2aTextField!.text, statusImageView:url2aStatusImageView!, delay:delay2aStepper!.value)
    }

    func loadURL2bStepPromise() -> Promise<NSData> {
        return loadURLStepPromise(url2bTextField!.text, statusImageView:url2bStatusImageView!, delay:delay2bStepper!.value)
    }

    func loadURL3StepPromise() -> Promise<NSData> {
        return loadURLStepPromise(url3TextField!.text, statusImageView:url3StatusImageView!, delay:0.0)
    }

    func loadURLStepPromise(urlString:String?, statusImageView:UIImageView?, delay:NSTimeInterval) -> Promise<NSData> {
        let url:NSURL? = (urlString == nil) ? nil : NSURL(string:urlString!)
        return loadURLPromise(url, delay:delay).then(
            { [weak self] value in
                statusImageView?.setStatus(true)
                self?.log("loaded \(value?.length) bytes from URL \(url)")
                return .Value(value)
            }, reject: { [weak self] error in
                statusImageView?.setStatus(false)
                var stopOnError = true
                if let stopOnErrorSwitch = self?.stopOnErrorSwitch {
                    stopOnError = stopOnErrorSwitch.on
                }
                if stopOnError {
                    self?.log("Stopping on error while loading URL \(url): \(error)")
                    return .Error(error)
                } else {
                    self?.log("Ignore error while loading URL \(url): \(error)")
                    return .Value(nil) // don't stop the chain
                }
            }
        )
    }

    @IBAction func delayStepperAction(stepper:UIStepper) {
        updateUI()
    }

}
