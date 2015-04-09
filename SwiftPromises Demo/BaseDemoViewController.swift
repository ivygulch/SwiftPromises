//
//  BaseDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit
import SwiftPromises

extension String {
    var length: Int {
        get {
            return count(self)
        }
    }

    func indexOf(target: String, startIndex: Int) -> Int {
        var startRange = advance(self.startIndex, startIndex)

        var range = self.rangeOfString(target, options: NSStringCompareOptions.LiteralSearch, range: Range<String.Index>(start: startRange, end: self.endIndex))

        if let range = range {
            return distance(self.startIndex, range.startIndex)
        } else {
            return -1
        }
    }

}

extension UITextField {
    var value:String? {
        get {
            return count(text) > 0 ? text : nil
        }
    }
}

extension UIImageView {
    func setStatus(success:Bool?) {
        dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
            if let success = success {
                self?.image = UIImage(named:success ? "Knob Valid Green" : "Knob Cancel")
            } else {
                self?.image = UIImage(named:"Knob Grey")
            }
        })
    }
}


class BaseDemoViewController: UIViewController {

    @IBOutlet var startButton:UIButton?
    @IBOutlet var logTextView:UITextView?
    var loadingView:UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleTextFieldDidChange:", name: UITextFieldTextDidChangeNotification, object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        clearStatus()
        updateUI()
    }

    func clearStatus() {
    }

    func handleTextFieldDidChange(textField: UITextField) {
        updateUI()
    }

    func updateUI() {
        startButton!.enabled = readyToStart()
    }

    func start() {
    }

    func readyToStart() -> Bool {
        return false
    }

    @IBAction func startAction(sender:UIButton) {
        start()
    }

    func clearLog() {
        logTextView!.text = nil
    }

    func log(s:String) {
        println("LOG: \(s)")
        var scrollToLoc:Int = 0
        var text = logTextView!.text
        if text.length > 0 {
            scrollToLoc = text.length + 1
            text = text + "\n" + s
        } else {
            text = s
        }
        dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
            self?.logTextView!.text = text
            self?.logTextView!.scrollRangeToVisible(NSMakeRange(scrollToLoc,1))
        })
    }

    func loadURLPromise(url:NSURL?, delay:NSTimeInterval=0.0) -> Promise {
        let promise = Promise()

        if let url = url {
            var session = NSURLSession.sharedSession().dataTaskWithURL(url,
                completionHandler : {[weak self] (data, response, error) -> Void in
                    if let error = error {
                        promise.reject(error)
                    } else {
                        promise.fulfill(data)
                    }
            })
            if delay > 0.0 {
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
                log("delay \(delay) seconds before loading \(url)")
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    self.log("start loading \(url)")
                    session.resume()
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.log("start loading \(url)")
                    session.resume()
                }
            }
        } else {
            promise.reject(NSError(domain:"No URL specified", code:-1, userInfo:nil))
        }

        return promise
    }
    
    func startActivityIndicator() {
        let loadingView = UIView(frame:self.view.bounds)
        loadingView.backgroundColor = UIColor(white:0.0, alpha:0.25)
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
        activityIndicator.startAnimating()
        activityIndicator.center = loadingView.center
        loadingView.addSubview(activityIndicator)
        dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
            if let view = self?.view {
                view.addSubview(loadingView)
                self?.loadingView = loadingView
            }
        })
    }

    func stopActivityIndicator() {
        dispatch_async(dispatch_get_main_queue(), { [weak self] () -> Void in
            self?.loadingView?.removeFromSuperview()
            self?.loadingView = nil
        })
    }

}
