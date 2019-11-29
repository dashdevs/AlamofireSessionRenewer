//
//  MockURLProtocol.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Foundation

class MockURLProtocol: URLProtocol {
    private(set) var activeTask: URLSessionTask?
    
    private lazy var session: URLSession = {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.ephemeral
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        activeTask = session.dataTask(with: request.urlRequest!)
        activeTask?.cancel()
    }
    
    override func stopLoading() {
        activeTask?.cancel()
    }
}

extension MockURLProtocol: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let handle: (URLSessionTask) -> Void = { [weak self] task in
            guard let strongSelf = self else { return }
            let response: HTTPURLResponse
            
            if task.originalRequest?.value(forHTTPHeaderField: MockCredentialHeaderField) == MockAuthorizedCredential {
                response = HTTPURLResponse(url: task.currentRequest!.url!, statusCode: MockAuthenticationSuccessCode, httpVersion: nil, headerFields: nil)!
            } else {
                response = HTTPURLResponse(url: task.currentRequest!.url!, statusCode: MockAuthenticationFailureCode, httpVersion: nil, headerFields: nil)!
            }
            
            strongSelf.client?.urlProtocol(strongSelf, didReceive: response, cacheStoragePolicy: .notAllowed)
            strongSelf.client?.urlProtocolDidFinishLoading(strongSelf)
        }
        
        if let durationString = task.originalRequest?.value(forHTTPHeaderField: MockDurationKey), let duration = Int(durationString) {
            let deadline = DispatchTime.now().advanced(by: DispatchTimeInterval.seconds(duration))
            DispatchQueue.global().asyncAfter(deadline: deadline) {
                handle(task)
            }
        } else {
            handle(task)
        }
    }
}
