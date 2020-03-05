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
    var sessionManager: SessionManager?
    var requestsHandler: MockRequestsHandler?
    
    override func setUp() {
        super.setUp()
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        sessionManager = SessionManager(configuration: sessionConfiguration)
        requestsHandler = MockRequestsHandler(authenticationErrorCode: MockAuthenticationFailureCode, credentialHeaderField: MockCredentialHeaderField, maxRetryCount: MockMaxRetryCount, errorDomain: errorDomain)
        sessionManager?.retrier = requestsHandler
        sessionManager?.adapter = requestsHandler
    }
    
    override func tearDown() {
        super.tearDown()
        sessionManager = nil
        requestsHandler = nil
    }
    
    func testOneSuccessedRequest() {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        var retryCount = 0
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            success(MockAuthorizedCredential)
            retryCount += 1
        }
        
        let expectation = XCTestExpectation()
        
        sessionManager?.request(with: testUrlRequestInfo).response { response in
            XCTAssertNotNil(response.response)
            XCTAssert(response.response!.statusCode == MockAuthenticationSuccessCode)
            XCTAssert(retryCount == 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testOneFailedRequest() {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        var retryCount = 0
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            success(MockUnauthorizedCredential)
            retryCount += 1
        }
        
        let expectation = XCTestExpectation()
        
        sessionManager?.request(with: testUrlRequestInfo).response { response in
            XCTAssertNotNil(response.error)
            XCTAssert((response.error as NSError?)!.code == MockAuthenticationFailureCode)
            XCTAssert(retryCount == 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testTwoUnauthorizedRequests() {
        let testFirstUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization/first")!, duration: 100)
        let testSecondUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization/second")!, duration: 300)
        var retryCount = 0
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            success(MockAuthorizedCredential)
            retryCount += 1
        }
        
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 2
        
        sessionManager?.request(with: testFirstUrlRequestInfo).response { response in
            XCTAssertNotNil(response.response)
            XCTAssert(response.response!.statusCode == MockAuthenticationSuccessCode)
            XCTAssert(retryCount == 1)
            expectation.fulfill()
        }
        
        sessionManager?.request(with: testSecondUrlRequestInfo).response { response in
            XCTAssertNotNil(response.response)
            XCTAssert(response.response!.statusCode == MockAuthenticationSuccessCode)
            XCTAssert(retryCount == 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testRetryCount() {
        requestsHandler = MockRequestsHandler(authenticationErrorCode: MockAuthenticationFailureCode, credentialHeaderField: MockCredentialHeaderField, maxRetryCount: 5, errorDomain: errorDomain)
        sessionManager?.retrier = requestsHandler
        sessionManager?.adapter = requestsHandler
        
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 0)
        var retryCount = 0
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            success(MockUnauthorizedCredential)
            retryCount += 1
        }
        
        let expectation = XCTestExpectation()
        
        sessionManager?.request(with: testUrlRequestInfo).response { response in
            XCTAssertNotNil(response.error)
            XCTAssert((response.error as NSError?)!.code == MockAuthenticationFailureCode)
            XCTAssert(retryCount == 5)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testManyUnauthorizedRequests() {
        var retryCount = 0
        
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            retryCount += 1
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
                success(MockAuthorizedCredential)
            }
        }
        
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 10
        expectation.assertForOverFulfill = true
        
        (1...10).forEach { index in
            let deadline = DispatchTime.now() + DispatchTimeInterval.milliseconds(index * 100)
            DispatchQueue.global().asyncAfter(deadline: deadline) { [weak self] in
                let requestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization/\(index)")!, duration: 100)
                self?.sessionManager?.request(with: requestInfo).response { response in
                    XCTAssertNotNil(response.response)
                    XCTAssert(response.response!.statusCode == MockAuthenticationSuccessCode)
                    XCTAssert(retryCount == 1)
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 30)
    }
    
    func testErrorDomain() {
        requestsHandler = MockRequestsHandler(authenticationErrorCode: MockAuthenticationFailureCode, credentialHeaderField: MockCredentialHeaderField, maxRetryCount: 5, errorDomain: "com.test.errorDomain")
        sessionManager?.retrier = requestsHandler
        sessionManager?.adapter = requestsHandler
        
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        var retryCount = 0
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            success(MockAuthorizedCredential)
            retryCount += 1
        }
        
        let expectation = XCTestExpectation()
        
        sessionManager?.request(with: testUrlRequestInfo).response { response in
            XCTAssertNotNil(response.response)
            XCTAssert(response.response!.statusCode == MockAuthenticationFailureCode)
            XCTAssert(retryCount == 0)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
    func testFailureRenewWithCleanCred() {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            failure(true)
        }
        
        let expectation = XCTestExpectation()
        
        sessionManager?.request(with: testUrlRequestInfo).response { [weak self] response in
            XCTAssertNil(self?.requestsHandler?.credential)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
    
    func testFailureRenewWithoutCleanCred() {
        let testUrlRequestInfo = MockURLRequestInfo(url: URL(string: "http://test.com/authorization")!, duration: 1)
        requestsHandler?.credential = MockUnauthorizedCredential
        requestsHandler?.renewCredential = { success, failure in
            failure(false)
        }
        
        let expectation = XCTestExpectation()
        
        sessionManager?.request(with: testUrlRequestInfo).response { [weak self] response in
            XCTAssertNotNil(self?.requestsHandler?.credential)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30)
    }
}
