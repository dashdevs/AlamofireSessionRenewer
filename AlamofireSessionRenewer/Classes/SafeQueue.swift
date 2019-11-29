//
//  SafeQueue.swift
//  AlamofireSessionRenewer
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Alamofire

/// This is special data structure  for storing queue of pending for authorisation requests
public struct SafeQueue {
    public let lock = NSLock()
    public var pendingRequests: [RequestRetryCompletion] = []
    
    /// Method enqueues another request
    /// - Parameter requestRetryCompletion: closure which will be called after request completion
    mutating func add(requestRetryCompletion: @escaping RequestRetryCompletion) -> Int {
        lock.lock()
        defer { lock.unlock() }
        pendingRequests.append(requestRetryCompletion)
        return pendingRequests.count
    }
    
    /// Method completes all pending requests in queue
    /// - Parameter retrying: flag indicating whether request needs to be retried
    mutating func fullfill(with retrying: Bool) {
        lock.lock()
        defer { lock.unlock() }
        pendingRequests.forEach { $0(retrying, 0) }
        pendingRequests.removeAll()
    }
}
