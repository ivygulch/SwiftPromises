# SwiftPromises

## Purpose

SwiftPromises is a lightweight implementation of the Promise pattern popularlized by various Javascript frameworks.

## Code Example

A simple example that chains two types of promises together to retrieve data from a website 
then create a string representation of the html.

<pre><code>

let loadURLPromise:Promise<NSData> = Promise()

let session = NSURLSession.sharedSession().dataTaskWithURL(url,
    completionHandler : {(data, response, error) -> Void in
        if let error = error {
            loadURLPromise.reject(error)
        } else {
            loadURLPromise.fulfill(data)
        }
    })
session.resume()

loadURLPromise.then(
    {
        data in
        // do something with data then pass the value down the chain,
        // or alternatively redirect the chain by returning a .Error or .Pending result
        return .Value(data)
    },
    reject:
    {
        error in
        // do something with error then pass the error down the chain, 
        // or alternatively redirect the chain by returning a .Value or .Pending result
        return .Error(error)
    })

</code></pre>


## API Reference

[docs/index.html](See API Documentation.)

## Contributors

Initial version developed for WalmartLabs by Doug Sjoquist, Andy Finnel, Steve Riggins. 

## License

[LICENSE](MIT License)

