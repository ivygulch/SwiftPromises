//
//  SimpleNetworkCallDemoViewController.swift
//  SwiftPromises
//
//  Created by Douglas Sjoquist on 3/1/15.
//  Copyright (c) 2015 Ivy Gulch LLC. All rights reserved.
//

import UIKit

class SimpleNetworkCallDemoViewController: BaseDemoViewController {

    @IBOutlet var urlTextField:UITextField?
    @IBOutlet var countTextField:UITextField?
    @IBOutlet var urlStatusImageView:UIImageView?
    @IBOutlet var countStatusImageView:UIImageView?
    @IBOutlet var finalStatusImageView:UIImageView?

    override func viewWillAppear(animated: Bool) {
        urlTextField!.text = "http://cnn.com"

        super.viewWillAppear(animated)
    }

    override func readyToStart() -> Bool {
        return (urlTextField!.value != nil) && (countTextField!.value != nil)
    }

    override func start() {
        clearStatus()
        clearLog()

        startActivityIndicator()
        loadHTMLFromURLPromise().then(
            { [weak self] (value) -> AnyObject? in
                return self?.countTextPromise(self?.countTextField!.value, htmlText:value as? String)
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
            }
        )

    }

    func loadHTMLFromURLPromise() -> Promise {
        let promise = Promise()
        let url = NSURL(string:urlTextField!.text)!
        loadURLPromise(url).then(
            { [weak self] (value) -> AnyObject? in
                self?.urlStatusImageView!.setStatus(true)
                var html:String? = nil
                if let data = value as? NSData {
                    if let dataStr = NSString(data:data, encoding: NSUTF8StringEncoding) {
                        html = dataStr
                    }
                }
                self?.log("loaded html len=(\(html?.length) from \(url)")
                promise.fulfill(html)
                return value
            }, reject: { [weak self] (error) -> AnyObject? in
                self?.urlStatusImageView!.setStatus(false)
                self?.log("error loading \(url): \(error.localizedDescription)")
                promise.reject(error)
                return error
            }
        )

        return promise
    }

    func countTextPromise(textToCount:String?, htmlText:String?) -> Promise {
        if let count = countText(textToCount, insideText:htmlText) {
            log("found \(count) occurences of '\(textToCount!)' in html")
            countStatusImageView!.setStatus(true)
            return Promise(count)
        } else {
            log("could not find '\(textToCount!)' in html")
            countStatusImageView!.setStatus(false)
            return Promise(NSError(domain:"Invalid text", code:-1, userInfo:nil))
        }
    }

    func countText(textToCount:String?, insideText:String?) -> Int? {
        var result:Int? = nil
        if let textToCount = textToCount {
            if let insideText = insideText {
                result = 0
                let len = textToCount.length
                var idx = insideText.indexOf(textToCount, startIndex: 0)
                while (idx >= 0) {
                    result! += 1
                    idx = insideText.indexOf(textToCount, startIndex: idx+len)
                }
            }
        }
        return result
    }

}
