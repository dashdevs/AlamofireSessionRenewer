//
//  SafeQueue.swift
//  AlamofireSessionRenewer
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Alamofire

public struct SafeQueue {
    public let lock = NSLock()
    public var pendingRequests: [RequestRetryCompletion] = []
    
    mutating func add(requestRetryCompletion: @escaping RequestRetryCompletion) -> Int {
        lock.lock()
        defer { lock.unlock() }
        pendingRequests.append(requestRetryCompletion)
        return pendingRequests.count
    }
    
    mutating func fullfill(with retrying: Bool) {
        lock.lock()
        defer { lock.unlock() }
        pendingRequests.forEach { $0(retrying, 0) }
        pendingRequests.removeAll()
    }
}
