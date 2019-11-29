//
//  MockResponseValidator.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

@testable import AlamofireSessionRenewer
import Alamofire

func MockResponseValidator(request: URLRequest?, response: HTTPURLResponse, data: Data?) -> Request.ValidationResult {
    switch response.statusCode {
    case 400...Int.max:
        return .failure(NSError(domain: "com.test.error", code: response.statusCode, userInfo: nil))
    default:
        return .success
    }
}
