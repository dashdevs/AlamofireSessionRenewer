//
//  SessionManager+RequestMock.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

@testable import AlamofireSessionRenewer
import Alamofire

extension Session {
    func request(with requestInfo: MockURLRequestInfo) -> DataRequest {
        let headers: HTTPHeaders = [
            MockDurationKey: String(requestInfo.duration)
        ]
        return request(requestInfo.url, headers: headers).validate(MockResponseValidator)
    }
}
