//
//  ExampleTests.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Testing
@testable import AlamofireSessionRenewer
import Alamofire

struct ExampleTests {
    @Test
    func oneSuccessedRequest() async throws {
        let sut = makeSUT()
        
        var retryCount = 0
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { success, _ in
            await success(TestConstants.authorizedCredential)
            retryCount += 1
        }
        let response = await sut.sessionManager.request(with: MockURLRequestInfo())
        
        let httpResponse = try #require(response.response)
        #expect(httpResponse.statusCode == TestConstants.authenticationSuccessCode)
        #expect(retryCount == TestConstants.retryCount)
    }
    
    @Test
    func oneFailedRequest() async throws {
        let sut = makeSUT()
        
        var retryCount = 0
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { success, _ in
            await success(TestConstants.unauthorizedCredential)
            retryCount += 1
        }
        let response = await sut.sessionManager.request(with: MockURLRequestInfo())
        
        let httpResponse = try #require(response.response)
        #expect(response.error != nil)
        #expect(httpResponse.statusCode == TestConstants.authenticationFailureCode)
        #expect(retryCount == TestConstants.retryCount)
    }
    
    @Test
    func twoUnauthorizedRequests() async throws {
        let sut = makeSUT()
        
        let testFirstUrlRequestInfo = MockURLRequestInfo(urlString: "http://test.com/authorization/first")
        let testSecondUrlRequestInfo = MockURLRequestInfo(urlString: "http://test.com/authorization/second")
        var retryCount = 0
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { success, _ in
            await success(TestConstants.authorizedCredential)
            retryCount += 1
        }
        async let firstRequest = sut.sessionManager.request(with: testFirstUrlRequestInfo)
        async let secondRequest = sut.sessionManager.request(with: testSecondUrlRequestInfo)
        
        let firstResponse = try await #require(firstRequest.response)
        let secondResponse = try await #require(secondRequest.response)
        #expect(firstResponse.statusCode == TestConstants.authenticationSuccessCode)
        #expect(secondResponse.statusCode == TestConstants.authenticationSuccessCode)
        #expect(retryCount == TestConstants.retryCount)
    }
    
    @Test
    func retryCount() async throws {
        let testMaxRetryCount = 5
        let sut = makeSUT(maxRetryCount: testMaxRetryCount)
        
        var retryCount = 0
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { success, _ in
            await success(TestConstants.unauthorizedCredential)
            retryCount += 1
        }
        
        let response = await sut.sessionManager.request(with: MockURLRequestInfo())

        let httpResponse = try #require(response.response)
        #expect(response.error != nil)
        #expect(httpResponse.statusCode == TestConstants.authenticationFailureCode)
        #expect(retryCount == testMaxRetryCount)
    }
    
    @Test
    func manyUnauthorizedRequests() async throws {
        let sut = makeSUT()
        
        var retryCount = 0
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { success, _ in
            retryCount += 1
            try? await Task.sleep(nanoseconds: 300_000_000)
            await success(TestConstants.authorizedCredential)
        }
        
        let responses = await withTaskGroup(of: DataResponse<Data?, AFError>.self) {
            [sessionManager = sut.sessionManager] group in

            for index in 1...10 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(index * 100_000_000))
                    let requestInfo = MockURLRequestInfo(
                        urlString: "http://test.com/authorization/\(index)",
                        duration: 100
                    )
                    return await sessionManager.request(with: requestInfo)
                }
            }
            
            var resultList = [DataResponse<Data?, AFError>]()
            for await result in group {
                resultList.append(result)
            }
            return resultList
        }
        
        for response in responses {
            let httpResponse = try #require(response.response)
            #expect(httpResponse.statusCode == TestConstants.authenticationSuccessCode)
        }
        #expect(retryCount == TestConstants.retryCount)
    }

    @Test
    func errorDomain() async throws {
        let sut = makeSUT(errorDomain: "com.test.errorDomain")
        
        var retryCount = 0
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { success, _ in
            await success(TestConstants.authorizedCredential)
            retryCount += 1
        }
        let response = await sut.sessionManager.request(with: MockURLRequestInfo())
        
        let httpResponse = try #require(response.response)
        #expect(httpResponse.statusCode == TestConstants.authenticationFailureCode)
        #expect(retryCount == 0)
    }
    
    @Test
    func failureRenewWithCleanCred() async {
        let sut = makeSUT()
        
        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { _, failure in
            await failure(true)
        }
        _ = await sut.sessionManager.request(with: MockURLRequestInfo())
        let currentCredential = await sut.requestsHandler.credential

        #expect(currentCredential == nil)
    }

    @Test
    func failureRenewWithoutCleanCred() async {
        let sut = makeSUT()

        await sut.requestsHandler.setCredential(TestConstants.unauthorizedCredential)
        await sut.requestsHandler.setRenewCredentialHandler { _, failure in
            await failure(false)
        }
        _ = await sut.sessionManager.request(with: MockURLRequestInfo())
        let currentCredential = await sut.requestsHandler.credential
        
        #expect(currentCredential != nil)
    }
}

extension ExampleTests {
    private struct SUT {
        let requestsHandler: AlamofireSessionRenewer
        let sessionManager: Session
    }

    private func makeSUT(
        maxRetryCount: Int = TestConstants.retryCount,
        errorDomain: String = TestConstants.errorDomain
    ) -> SUT {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let requestsHandler = AlamofireSessionRenewer(
            authenticationErrorCode: TestConstants.authenticationFailureCode,
            credentialHeaderField: TestConstants.credentialHeaderField,
            maxRetryCount: maxRetryCount,
            errorDomain: errorDomain
        )
        let sessionManager = Session(
            configuration: sessionConfiguration,
            interceptor: requestsHandler
        )
        return SUT(
            requestsHandler: requestsHandler,
            sessionManager: sessionManager
        )
    }
}
