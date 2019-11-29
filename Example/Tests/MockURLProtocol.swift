//
//  MockURLProtocol.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Foundation

class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let handle: (URLRequest) -> Void = { [weak self] request in
            guard let strongSelf = self else { return }
            let response: HTTPURLResponse
            
            if request.value(forHTTPHeaderField: MockCredentialHeaderField) == MockAuthorizedCredential {
                response = HTTPURLResponse(url: request.url!, statusCode: MockAuthenticationSuccessCode, httpVersion: nil, headerFields: request.allHTTPHeaderFields)!
            } else {
                response = HTTPURLResponse(url: request.url!, statusCode: MockAuthenticationFailureCode, httpVersion: nil, headerFields: request.allHTTPHeaderFields)!
            }
            
            strongSelf.client?.urlProtocol(strongSelf, didReceive: response, cacheStoragePolicy: .notAllowed)
            strongSelf.client?.urlProtocolDidFinishLoading(strongSelf)
        }
        
        if let durationString = request.value(forHTTPHeaderField: MockDurationKey), let duration = Int(durationString) {
            let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(duration)
            DispatchQueue.global().asyncAfter(deadline: deadline) { [weak self] in
                guard let strongSelf = self else { return }
                handle(strongSelf.request)
            }
        } else {
            handle(request)
        }
    }
    
    override func stopLoading() { }
}
