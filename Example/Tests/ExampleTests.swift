//
//  ExampleTests.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import XCTest
@testable import AlamofireSessionRenewer
import Alamofire

class ExampleTests: XCTestCase {
    var sessionManager: Session?
    var requestsHandler: AlamofireSessionRenewer?
    var sessionConfiguration = URLSessionConfiguration.default
    
    override func setUp() {
        super.setUp()
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        requestsHandler = AlamofireSessionRenewer(authenticationErrorCode: MockAuthenticationFailureCode, credentialHeaderField: MockCredentialHeaderField, maxRetryCount: MockMaxRetryCount, errorDomain: errorDomain)
        sessionManager = Session(configuration: sessionConfiguration, interceptor: requestsHandler)
    }
    
    override func tearDown() {
        super.tearDown()
        sessionManager = nil
        requestsHandler = nil
    }
    
    func testOneSuccessedRequest() async {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        var retryCount = 0
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { success, failure in
            await success(MockAuthorizedCredential)
            retryCount += 1
        }
        
        let response = await sessionManager?.request(with: testUrlRequestInfo)
        
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, MockAuthenticationSuccessCode)
        XCTAssertEqual(retryCount, 1)
    }
    
    func testOneFailedRequest() async {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        var retryCount = 0
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { success, failure in
            await success(MockUnauthorizedCredential)
            retryCount += 1
        }
        
        let response = await sessionManager?.request(with: testUrlRequestInfo)
        
        let error = response?.error?.asAFError?.underlyingError as NSError?
        XCTAssertNotNil(error)
        XCTAssertEqual(response?.response?.statusCode, MockAuthenticationFailureCode)
        XCTAssertEqual(retryCount, 1)
    }
    
    func testTwoUnauthorizedRequests() async {
        let testFirstUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization/first")!, duration: 100)
        let testSecondUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization/second")!, duration: 300)
        var retryCount = 0
        
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { success, _ in
            await success(MockAuthorizedCredential)
            retryCount += 1
        }
        
        let firstResponse = await sessionManager?.request(with: testFirstUrlRequestInfo)
        XCTAssertNotNil(firstResponse?.response)
        XCTAssertEqual(firstResponse?.response?.statusCode, MockAuthenticationSuccessCode)
        XCTAssertEqual(retryCount, 1)
        
        let secondResponse = await sessionManager?.request(with: testSecondUrlRequestInfo)
        XCTAssertNotNil(secondResponse?.response)
        XCTAssertEqual(secondResponse?.response?.statusCode, MockAuthenticationSuccessCode)
        XCTAssertEqual(retryCount, 1)
    }
    
    func testRetryCount() async {
        requestsHandler = AlamofireSessionRenewer(authenticationErrorCode: MockAuthenticationFailureCode, credentialHeaderField: MockCredentialHeaderField, maxRetryCount: 5, errorDomain: errorDomain)
        let session = Session(configuration: sessionConfiguration, interceptor: requestsHandler)
        
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 0)
        var retryCount = 0
        
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { success, _ in
            await success(MockUnauthorizedCredential)
            retryCount += 1
        }
        
        let response = await session.request(with: testUrlRequestInfo)
        
        let error = response.error?.asAFError?.underlyingError as NSError?
        XCTAssertNotNil(error)
        XCTAssertEqual(response.response?.statusCode, MockAuthenticationFailureCode)
        XCTAssertEqual(retryCount, 5)
    }
    
    func testManyUnauthorizedRequests() async {
        var retryCount = 0
        
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { success, _ in
            retryCount += 1
            try? await Task.sleep(nanoseconds: 300_000_000)
            await success(MockAuthorizedCredential)
        }
        
        let responses = await withTaskGroup(of: (Int, DataResponse<Data?, AFError>?).self) { group in
            for index in 1...10 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(index * 100_000_000))
                    let requestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization/\(index)")!, duration: 100)
                    let response = await self.sessionManager?.request(with: requestInfo)
                    return (index, response)
                }
            }
            
            var resultList = [(Int, DataResponse<Data?, AFError>?)]()
            for await result in group {
                resultList.append(result)
            }
            return resultList
        }
        
        for (index, response) in responses {
            XCTAssertNotNil(response?.response, "Response for request \(index) is nil")
            XCTAssertEqual(response?.response?.statusCode, MockAuthenticationSuccessCode, "Status code for request \(index) is not 200")
        }
        
        XCTAssertEqual(retryCount, 1, "Retry count should be 1")
    }
    
    func testErrorDomain() async {
        requestsHandler = AlamofireSessionRenewer(authenticationErrorCode: MockAuthenticationFailureCode, credentialHeaderField: MockCredentialHeaderField, maxRetryCount: 5, errorDomain: "com.test.errorDomain")
        let session = Session(configuration: sessionConfiguration, interceptor: requestsHandler)
        
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        var retryCount = 0
        
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { success, _ in
            await success(MockAuthorizedCredential)
            retryCount += 1
        }
        
        let response = await session.request(with: testUrlRequestInfo)
        
        XCTAssertNotNil(response.response)
        XCTAssertEqual(response.response?.statusCode, MockAuthenticationFailureCode)
        XCTAssertEqual(retryCount, 0, "Retry count should be 0 as the error domain does not match")
    }
    
    func testFailureRenewWithCleanCred() async {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { _, failure in
            await failure(true)
        }
        
        let response = await sessionManager?.request(with: testUrlRequestInfo)
        
        let currentCredential = await requestsHandler?.getCredential()
        XCTAssertNil(currentCredential)
        XCTAssertNotNil(response)
    }
    
    func testFailureRenewWithoutCleanCred() async {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        
        await requestsHandler?.setCredential(MockUnauthorizedCredential)
        await requestsHandler?.setRenewCredentialHandler { _, failure in
            await failure(false)
        }
        
        let response = await sessionManager?.request(with: testUrlRequestInfo)
        
        let currentCredential = await requestsHandler?.getCredential()
        XCTAssertNotNil(currentCredential)
        XCTAssertNotNil(response)
    }
}
