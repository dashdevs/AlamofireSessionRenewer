//
//  MockRequestsHandler.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

@testable import AlamofireSessionRenewer
import Alamofire

class MockRequestsHandler: AlamofireSessionRenewer {
    override func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        guard let cred = credential else {
            completion(.success(urlRequest))
            return
        }
        var updatedRequest = urlRequest
        updatedRequest.setValue(cred, forHTTPHeaderField: credentialHeaderField)
        completion(.success(updatedRequest))

    }
}
