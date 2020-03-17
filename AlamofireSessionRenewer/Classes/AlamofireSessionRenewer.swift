//
//  AlamofireSessionRenewer.swift
//  AlamofireSessionRenewer
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Alamofire

public typealias SuccessRenewHandler = (String) -> Void
public typealias FailureRenewHandler = (Bool) -> Void

/// This class is responsible for authentication credentials renewing process
open class AlamofireSessionRenewer: RequestRetrier {
    
    /// Error code indicating request is missing authentication info. Defaults to HTTP code 401
    public let authenticationErrorCode: Int
    
    /// Authentication information request header field name
    public let credentialHeaderField: String
    
    /// Number of times to retry credentials renewing process upper limit
    public let maxRetryCount: UInt?
    
    /// Authentication information unit
    open var credential: String?
    
    /// Queue which stores requests to retry
    open var queue = SafeQueue()
    
    /// Error domain indicating request we should retry
    open var errorDomain: String
    
    /// Closure which is called when authentication credentials renewing process finishes
    open var renewCredential: ((@escaping SuccessRenewHandler, @escaping FailureRenewHandler) -> Void)?
    
    private lazy var successRenewHandler: SuccessRenewHandler = { [weak self] credential in
        self?.credential = credential
        self?.queue.fullfill(with: true)
    }
    
    private lazy var failureRenewHandler: FailureRenewHandler = { [weak self] needsToClearCredential in
        if needsToClearCredential { self?.credential = nil }
        self?.queue.fullfill(with: false)
    }
    
    private func addToQueue(requestRetryCompletion: @escaping RequestRetryCompletion) {
        if queue.add(requestRetryCompletion: requestRetryCompletion) == 1 {
            renewCredential?(successRenewHandler, failureRenewHandler)
        }
    }
    
    public init(authenticationErrorCode: Int = 401, credentialHeaderField: String = "Authorization", maxRetryCount: UInt? = nil, errorDomain: String) {
        self.authenticationErrorCode = authenticationErrorCode
        self.credentialHeaderField = credentialHeaderField
        self.maxRetryCount = maxRetryCount
        self.errorDomain = errorDomain
    }
        
    /// Method checks whether request contains authentication credentials or not
    /// - Parameter request: request to check credentials containment
    open func isCredentialEqual(to request: Request) -> Bool {
        if let currentCred = credential, let receivedCred = request.task?.originalRequest?.value(forHTTPHeaderField: credentialHeaderField) {
            return currentCred == receivedCred
        } else {
            return false
        }
    }
    
    open func isCredentialEmpty() -> Bool {
        return credential == nil
    }
    
    // MARK: - RequestRetrier protocol implementation
    
    open func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        if !isCredentialEmpty(), (error as NSError).domain == errorDomain, (error as NSError).code == authenticationErrorCode {
            if let maxRetryCount = maxRetryCount, maxRetryCount <= request.retryCount {
                completion(false, 0)
                return
            }
            
            if isCredentialEqual(to: request) {
                addToQueue(requestRetryCompletion: completion)
            } else {
                completion(true, 0)
            }
        } else {
            completion(false, 0)
        }
    }
}
