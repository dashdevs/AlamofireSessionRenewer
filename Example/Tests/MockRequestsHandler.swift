//
//  MockRequestsHandler.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

@testable import AlamofireSessionRenewer
import Alamofire

class MockRequestsHandler: AlamofireSessionRenewer, RequestAdapter {
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        guard let cred = credential else { return urlRequest }
        var updatedRequest = urlRequest
        updatedRequest.setValue(cred, forHTTPHeaderField: credentialHeaderField)
        return updatedRequest
    }
}
