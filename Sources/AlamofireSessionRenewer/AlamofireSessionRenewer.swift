//
//  AlamofireSessionRenewer.swift
//  AlamofireSessionRenewer
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Foundation
import Alamofire

public typealias SuccessRenewHandler = (String) async -> Void
public typealias FailureRenewHandler = (Bool) async -> Void
public typealias RenewCredentialHandler = ((SuccessRenewHandler, FailureRenewHandler) async -> Void)

/// That actor is responsible for authentication credentials renewing process
final public actor AlamofireSessionRenewer: RequestInterceptor {
    
    // MARK: Properties
    
    /// Error code indicating request is missing authentication info. Defaults to HTTP code 401
    private let authenticationErrorCode: Int
    
    /// Authentication information request header field name
    private let credentialHeaderField: String
    
    /// Number of times to retry credentials renewing process upper limit
    private let maxRetryCount: UInt?
    
    /// Error domain indicating request we should retry
    private let errorDomain: String
    
    /// Authentication information unit
    public var credential: String?
    
    /// An array which stores closures to retry requests after updating credentials
    private var pendingRequests: [(RetryResult) -> Void] = []
    
    /// Closure which is called when authentication credentials renewing process finishes
    private var renewCredential: RenewCredentialHandler?
    
    /// Handler for successful credential renewal.
    private lazy var successRenewHandler: SuccessRenewHandler = { [weak self] credential in
        guard let self else { return }
        await self.setCredential(credential)
        await self.fulfillPendingRequests(with: .retry)
    }
    
    /// Handler for failed credential renewal.
    private lazy var failureRenewHandler: FailureRenewHandler = { [weak self] needsToClearCredential in
        guard let self else { return }
        if needsToClearCredential {
            await self.setCredential(nil)
        }
        await self.fulfillPendingRequests(with: .doNotRetry)
    }
    
    // MARK: Init
    
    /// Initializes an instance of AlamofireSessionRenewer.
    /// - Parameters:
    ///   - authenticationErrorCode: The error code indicating an authentication issue (default is 401).
    ///   - credentialHeaderField: The HTTP header field name for credentials (default is "Authorization").
    ///   - maxRetryCount: The maximum number of retry attempts allowed.
    ///   - errorDomain: The error domain that identifies retriable requests.
    public init(
        authenticationErrorCode: Int = 401,
        credentialHeaderField: String = "Authorization",
        maxRetryCount: UInt? = nil,
        errorDomain: String
    ) {
        self.authenticationErrorCode = authenticationErrorCode
        self.credentialHeaderField = credentialHeaderField
        self.maxRetryCount = maxRetryCount
        self.errorDomain = errorDomain
    }
    
    // MARK: Methods
    
    /// Adds a request to the pending requests queue for retrying after credential renewal.
    /// - Parameter requestRetryCompletion: The completion handler to be called with the retry result.
    private func addToQueue(requestRetryCompletion: @escaping (RetryResult) -> Void) async {
        pendingRequests.append(requestRetryCompletion)
        
        if pendingRequests.count == 1 {
            await renewCredential?(successRenewHandler, failureRenewHandler)
        }
    }
    
    /// Method completes all pending requests in queue
    /// - Parameter result: flag indicating whether requests need to be retried or not
    private func fulfillPendingRequests(with result: RetryResult) {
        pendingRequests.forEach { $0(result) }
        pendingRequests.removeAll()
    }
}

// MARK: - Public methods

extension AlamofireSessionRenewer {
    /// Sets the current authentication credential.
    /// - Parameter credential: The new credential string.
    public func setCredential(_ credential: String?) {
        self.credential = credential
    }
    
    /// Sets the handler to be used for credential renewal.
    /// - Parameter handler: The closure that handles the credential renewal.
    public func setRenewCredentialHandler(_ handler: @escaping RenewCredentialHandler) async {
        self.renewCredential = handler
    }
    
    /// Checks if the current credential is empty.
    /// - Returns: True if no credential is set, false otherwise.
    public func isCredentialEmpty() -> Bool {
        credential == nil
    }
    
    /// Method checks whether request contains authentication credentials or not
    /// - Parameter request: request to check credentials containment
    public func isCredentialEqual(to request: Request) -> Bool {
        if
            let credential,
            let receivedCredential = request.task?.originalRequest?.value(forHTTPHeaderField: credentialHeaderField)
        {
            credential == receivedCredential
        } else {
            false
        }
    }
    
    // MARK: - RequestAdapter
    
    nonisolated public func adapt(
        _ urlRequest: URLRequest,
        for session: Session,
        completion: @escaping (Result<URLRequest, Error>) -> Void
    ) {
        Task {
            var updatedRequest = urlRequest
            if let credential = await credential {
                updatedRequest.setValue(credential, forHTTPHeaderField: credentialHeaderField)
            }
            completion(.success(updatedRequest))
        }
    }
    
    // MARK: - RequestRetrier
    
    nonisolated public func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        Task {
            guard
                await !isCredentialEmpty(),
                let underlyingError = error.asAFError?.underlyingError as? NSError,
                underlyingError.domain == errorDomain,
                underlyingError.code == authenticationErrorCode
            else {
                return completion(.doNotRetry)
            }
            if let maxRetryCount, maxRetryCount <= request.retryCount {
                return completion(.doNotRetryWithError(error))
            }
            if await isCredentialEqual(to: request) {
                await addToQueue(requestRetryCompletion: completion)
            } else {
                completion(.retry)
            }
        }
    }
}
