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

/// That actor is responsible for authentication credentials renewing process
public actor AlamofireSessionRenewer: RequestInterceptor {
    
    // MARK: Properties
    
    /// Error code indicating request is missing authentication info. Defaults to HTTP code 401
    private let authenticationErrorCode: Int
    
    /// Authentication information request header field name
    private let credentialHeaderField: String
    
    /// Number of times to retry credentials renewing process upper limit
    private let maxRetryCount: Int?
    
    /// Error domain indicating request we should retry
    private let errorDomain: String
    
    /// Authentication information unit
    public var credential: String?
    
    /// An array which stores closures to retry requests after updating credentials
    private var pendingRequests: [(RetryResult) -> Void] = []
    
    /// Flag to track if credential renewal is currently in progress. Prevents recursive refresh attempts
    private var isRenewing: Bool = false
    
    /// Paths that should be excluded from session renewal interception
    public var excludedPaths: Set<String>
    
    /// Closure which is called when authentication credentials renewing process finishes
    private let renewCredential: (@escaping SuccessRenewHandler, @escaping FailureRenewHandler) async -> Void
    
    /// Handler for successful credential renewal.
    private lazy var successRenewHandler: SuccessRenewHandler = { [weak self] credential in
        guard let self else {
            return
        }
        await self.setCredential(credential)
        await self.setIsRenewing(false)
        await self.fulfillPendingRequests(with: .retry)
    }
    
    /// Handler for failed credential renewal.
    private lazy var failureRenewHandler: FailureRenewHandler = { [weak self] needsToClearCredential in
        guard let self else {
            return
        }
        await self.setIsRenewing(false)
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
    ///   - excludedPaths: Set of paths that should be excluded from session renewal interception.
    ///   - renewCredential: The closure that handles the credential renewal process.
    public init(
        authenticationErrorCode: Int = 401,
        credentialHeaderField: String = "Authorization",
        maxRetryCount: Int? = nil,
        errorDomain: String,
        excludedPaths: Set<String> = [],
        renewCredential: @escaping (@escaping SuccessRenewHandler, @escaping FailureRenewHandler) async -> Void
    ) {
        self.authenticationErrorCode = authenticationErrorCode
        self.credentialHeaderField = credentialHeaderField
        self.maxRetryCount = maxRetryCount
        self.errorDomain = errorDomain
        self.excludedPaths = excludedPaths
        self.renewCredential = renewCredential
    }
    
    // MARK: Methods
    
    /// Adds a request to the pending requests queue for retrying after credential renewal.
    /// - Parameter requestRetryCompletion: The completion handler to be called with the retry result.
    private func addToQueue(requestRetryCompletion: @escaping (RetryResult) -> Void) async {
        pendingRequests.append(requestRetryCompletion)
        
        if pendingRequests.count == 1 && !isRenewing {
            isRenewing = true
            await renewCredential(successRenewHandler, failureRenewHandler)
        }
    }
    
    /// Method completes all pending requests in queue
    /// - Parameter result: flag indicating whether requests need to be retried or not
    private func fulfillPendingRequests(with result: RetryResult) {
        pendingRequests.forEach { $0(result) }
        pendingRequests.removeAll()
    }
    
    /// Sets the renewing flag
    /// - Parameter value: The new value for the renewing flag
    private func setIsRenewing(_ value: Bool) {
        isRenewing = value
    }
    
    /// Checks if the given path should be excluded from session renewal interception
    /// - Parameter path: The request path to check
    /// - Returns: True if the path should be excluded, false otherwise
    private func shouldExcludePath(_ path: String) -> Bool {
        guard !excludedPaths.isEmpty else {
            return false
        }
        
        if excludedPaths.contains(path) {
            return true
        }
        
        for excludedPath in excludedPaths {
            if matchesPattern(path: path, pattern: excludedPath) {
                return true
            }
        }
        
        return false
    }
    
    /// Checks if a path matches a pattern with wildcard support
    /// - Parameters:
    ///   - path: The path to check
    ///   - pattern: The pattern to match against (supports * wildcard)
    /// - Returns: True if the path matches the pattern, false otherwise
    private func matchesPattern(path: String, pattern: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: ".", with: "\\.")
        
        guard let regex = try? NSRegularExpression(pattern: "^\(regexPattern)$", options: []) else {
            return false
        }
        
        let range = NSRange(location: 0, length: path.utf16.count)
        return regex.firstMatch(in: path, options: [], range: range) != nil
    }
}

// MARK: - Public methods

extension AlamofireSessionRenewer {
    /// Sets the current authentication credential.
    /// - Parameter credential: The new credential string.
    public func setCredential(_ credential: String?) {
        self.credential = credential
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
    
    /// Updates the set of excluded paths
    /// - Parameter paths: Set of paths to exclude from session renewal interception
    public func setExcludedPaths(_ paths: Set<String>) {
        self.excludedPaths = paths
    }
    
    /// Adds paths to the excluded paths set
    /// - Parameter paths: Paths to add to the exclusion list
    public func addExcludedPaths(_ paths: Set<String>) {
        self.excludedPaths.formUnion(paths)
    }
    
    /// Removes paths from the excluded paths set
    /// - Parameter paths: Paths to remove from the exclusion list
    public func removeExcludedPaths(_ paths: Set<String>) {
        self.excludedPaths.subtract(paths)
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
                let existingHeader = updatedRequest.value(forHTTPHeaderField: credentialHeaderField)
                if existingHeader == nil {
                    updatedRequest.setValue(credential, forHTTPHeaderField: credentialHeaderField)
                }
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
            if let requestPath = request.request?.url?.path,
               await shouldExcludePath(requestPath) {
                return completion(.doNotRetry)
            }
            
            if await isRenewing {
                await addToQueue(requestRetryCompletion: completion)
                return
            }
            
            guard await !isCredentialEmpty() else {
                return completion(.doNotRetry)
            }
            
            var isAuthError = false
            
            if let afError = error.asAFError {
                if let responseCode = afError.responseCode, responseCode == authenticationErrorCode {
                    isAuthError = true
                }
                else if case .responseValidationFailed(let reason) = afError {
                    if case .unacceptableStatusCode(let code) = reason {
                        if code == authenticationErrorCode {
                            isAuthError = true
                        }
                    }
                }
                else if let underlyingError = afError.underlyingError as? NSError,
                         underlyingError.domain == errorDomain,
                         underlyingError.code == authenticationErrorCode {
                    isAuthError = true
                }
            }
            
            guard isAuthError else {
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
