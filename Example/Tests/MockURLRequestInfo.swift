//
//  MockURLRequestInfo.swift
//  ExampleTests
//
//  Copyright © 2019 DashDevs LLC. All rights reserved.
//

import Foundation

struct MockURLRequestInfo: Codable {
    let url: URL
    let duration: Int
}

extension MockURLRequestInfo {
    init(
        urlString: String = "http://test.com/authorization",
        duration: Int = 1
    ) {
        self.init(
            url: URL(string: urlString)!,
            duration: duration
        )
    }
}
