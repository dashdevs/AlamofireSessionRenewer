//
//  SessionManager+RequestMock.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

@testable import AlamofireSessionRenewer
import Alamofire

extension Session {
    func request(with requestInfo: MockURLRequestInfo) async -> DataResponse<Data?, AFError> {
        let headers: HTTPHeaders = [
            MockDurationKey: String(requestInfo.duration)
        ]
        return await withCheckedContinuation { continuation in
            request(requestInfo.url, headers: headers)
                .validate(MockResponseValidator)
                .response { response in
                    continuation.resume(returning: response)
                }
        }
    }
}
