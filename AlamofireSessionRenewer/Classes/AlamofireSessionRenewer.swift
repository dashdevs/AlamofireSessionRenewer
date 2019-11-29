//
//  AlamofireSessionRenewer.swift
//  AlamofireSessionRenewer
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Alamofire

public typealias SuccessRenewHandler = (String) -> Void
public typealias FailureRenewHandler = () -> Void

open class AlamofireSessionRenewer: RequestRetrier {
    public let authenticationErrorCode: Int
    public let credentialHeaderField: String
    public let maxRetryCount: UInt?
    
    open var credential: String?
    open var queue = SafeQueue()
    open var renewCredential: ((@escaping SuccessRenewHandler, @escaping FailureRenewHandler) -> Void)?
    
    private lazy var successRenewHandler: SuccessRenewHandler = { [weak self] credential in
        self?.credential = credential
        self?.queue.fullfill(with: true)
    }
    
    private lazy var failureRenewHandler: FailureRenewHandler = { [weak self] in
        self?.credential = nil
        self?.queue.fullfill(with: false)
    }
    
    public init(authenticationErrorCode: Int = 401, credentialHeaderField: String = "Authorization", maxRetryCount: UInt? = nil) {
        self.authenticationErrorCode = authenticationErrorCode
        self.credentialHeaderField = credentialHeaderField
        self.maxRetryCount = maxRetryCount
    }
    
    public func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        if (error as NSError).code == authenticationErrorCode {
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
    
    private func addToQueue(requestRetryCompletion: @escaping RequestRetryCompletion) {
        if queue.add(requestRetryCompletion: requestRetryCompletion) == 1 {
            renewCredential?(successRenewHandler, failureRenewHandler)
        }
    }
    
    open func isCredentialEqual(to request: Request) -> Bool {
        if let currentCred = credential, let receivedCred = request.task?.originalRequest?.value(forHTTPHeaderField: credentialHeaderField) {
            return currentCred == receivedCred
        } else {
            return false
        }
    }
}
