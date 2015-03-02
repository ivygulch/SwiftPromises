//
//  CompoundNetworkCallDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit

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
            { [weak self] (value) -> AnyObject? in
                self?.log("loading promise2a and promise2b")
                var promises:[Promise] = []
                if let strongSelf = self {
                    promises.append(strongSelf.loadURL2aStepPromise())
                    promises.append(strongSelf.loadURL2bStepPromise())
                }
                return Promise.all(promises)
        } ).then(
            { [weak self] (value) -> AnyObject? in
                return self?.loadURL3StepPromise()
        }).then(
            { [weak self] (value) -> AnyObject? in
                self?.log("final success")
                self?.finalStatusImageView!.setStatus(true)
                self?.stopActivityIndicator()
                return value
            }, reject: { [weak self] (error) -> AnyObject? in
                self?.log("final error: \(error.localizedDescription)")
                self?.finalStatusImageView!.setStatus(false)
                self?.stopActivityIndicator()
                return error
        })

    }

    func loadURL1StepPromise() -> Promise {
        return loadURLStepPromise(url1TextField!.text, statusImageView:url1StatusImageView!, delay:0.0)
    }

    func loadURL2aStepPromise() -> Promise {
        return loadURLStepPromise(url2aTextField!.text, statusImageView:url2aStatusImageView!, delay:delay2aStepper!.value)
    }

    func loadURL2bStepPromise() -> Promise {
        return loadURLStepPromise(url2bTextField!.text, statusImageView:url2bStatusImageView!, delay:delay2bStepper!.value)
    }

    func loadURL3StepPromise() -> Promise {
        return loadURLStepPromise(url3TextField!.text, statusImageView:url3StatusImageView!, delay:0.0)
    }

    func loadURLStepPromise(urlString:String?, statusImageView:UIImageView?, delay:NSTimeInterval) -> Promise {
        var url:NSURL? = (urlString == nil) ? nil : NSURL(string:urlString!)
        return loadURLPromise(url, delay:delay).then(
            { [weak self] (value) -> AnyObject? in
                statusImageView?.setStatus(true)
                var data:NSData? = value as? NSData
                self?.log("loaded \(data?.length) bytes from URL \(url)")
                return value
            }, reject: { [weak self] (error) -> AnyObject? in
                statusImageView?.setStatus(false)
                var stopOnError = true
                if let stopOnErrorSwitch = self?.stopOnErrorSwitch? {
                    stopOnError = stopOnErrorSwitch.on
                }
                if stopOnError {
                    self?.log("Stopping on error while loading URL \(url): \(error.localizedDescription)")
                    return error
                } else {
                    self?.log("Ignore error while loading URL \(url): \(error.localizedDescription)")
                    return nil // don't stop the chain
                }
            }
        )
    }

    @IBAction func delayStepperAction(stepper:UIStepper) {
        updateUI()
    }

}
