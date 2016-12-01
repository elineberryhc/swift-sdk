//
//  KinveyTests.swift
//  KinveyTests
//
//  Created by Victor Barros on 2015-12-08.
//  Copyright © 2015 Kinvey. All rights reserved.
//

import XCTest
@testable import Kinvey

extension XCTestCase {
    
    @discardableResult
    func waitValueForObject<V: Equatable>(_ obj: NSObject, keyPath: String, expectedValue: V?, timeout: TimeInterval = 60) -> Bool {
        let date = Date()
        let loop = RunLoop.current
        var result = false
        repeat {
            let currentValue = obj.value(forKey: keyPath)
            if let currentValue = currentValue as? V {
                result = currentValue == expectedValue
            } else if currentValue == nil && expectedValue == nil {
                result = true
            }
            if !result {
                loop.run(until: Date(timeIntervalSinceNow: 0.1))
            }
        } while !result && -date.timeIntervalSinceNow > timeout
        return result
    }
    
}

struct HttpResponse {
    
    let statusCode: Int?
    let headerFields: [String : String]?
    let data: Data?
    
    init(statusCode: Int? = nil, headerFields: [String : String]? = nil, data: Data? = nil) {
        var headerFields = headerFields ?? [:]
        if let data = data {
            headerFields["Content-Length"] = "\(data.count)"
        }
        
        self.statusCode = statusCode
        self.headerFields = headerFields
        self.data = data
    }
    
    init(statusCode: Int? = nil, headerFields: [String : String]? = nil, json: JsonDictionary) {
        var headerFields = headerFields ?? [:]
        headerFields["Content-Type"] = "application/json; charset=utf-8"
        let data = try! JSONSerialization.data(withJSONObject: json)
        self.init(statusCode: statusCode, headerFields: headerFields, data: data)
    }
    
    init(statusCode: Int? = nil, headerFields: [String : String]? = nil, json: [JsonDictionary]) {
        var headerFields = headerFields ?? [:]
        headerFields["Content-Type"] = "application/json; charset=utf-8"
        let data = try! JSONSerialization.data(withJSONObject: json)
        self.init(statusCode: statusCode, headerFields: headerFields, data: data)
    }
    
}

extension JSONSerialization {
    
    class func jsonObject(with request: URLRequest, options opt: JSONSerialization.ReadingOptions = []) throws -> Any {
        if let data = request.httpBody {
            return try jsonObject(with: data, options: opt)
        } else if let inputStream = request.httpBodyStream {
            inputStream.open()
            defer {
                inputStream.close()
            }
            return try jsonObject(with: inputStream, options: opt)
        } else {
            preconditionFailure()
        }
    }
    
}

extension XCTestCase {
    
    func setURLProtocol(_ type: URLProtocol.Type?, client: Client = Kinvey.sharedClient) {
        if let type = type {
            let sessionConfiguration = URLSessionConfiguration.default
            sessionConfiguration.protocolClasses = [type]
            client.urlSession = URLSession(configuration: sessionConfiguration)
            XCTAssertEqual(client.urlSession.configuration.protocolClasses!.count, 1)
        } else {
            client.urlSession = URLSession(configuration: URLSessionConfiguration.default)
        }
    }
    
    class MockURLProtocol: URLProtocol {
        
        static var completionHandler: ((URLRequest) -> HttpResponse)? = nil
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            let responseObj = MockURLProtocol.completionHandler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: responseObj.statusCode ?? 200, httpVersion: "1.1", headerFields: responseObj.headerFields)
            client!.urlProtocol(self, didReceive: response!, cacheStoragePolicy: .notAllowed)
            if let data = responseObj.data {
                client!.urlProtocol(self, didLoad: data)
            }
            client!.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
        }
        
    }
    
    func setResponseBody(statusCode: Int? = nil, headerFields: [String : String]? = nil, json: JsonDictionary) {
        var headerFields = headerFields ?? [:]
        headerFields["Content-Type"] = "application/json; charset=utf-8"
        setResponseBody(statusCode: statusCode, headerFields: headerFields, data: try! JSONSerialization.data(withJSONObject: json))
    }
    
    func setResponseBody(statusCode: Int? = nil, headerFields: [String : String]? = nil, json: [JsonDictionary]) {
        var headerFields = headerFields ?? [:]
        headerFields["Content-Type"] = "application/json; charset=utf-8"
        setResponseBody(statusCode: statusCode, headerFields: headerFields, data: try! JSONSerialization.data(withJSONObject: json))
    }
    
    func setResponseBody(statusCode: Int? = nil, headerFields: [String : String]? = nil, data: Data?) {
        var headerFields = headerFields ?? [:]
        if let data = data {
            headerFields["Content-Length"] = "\(data.count)"
        }
        MockURLProtocol.completionHandler = { _ in
            return HttpResponse(statusCode: statusCode, headerFields: headerFields, data: data)
        }
        setURLProtocol(MockURLProtocol.self)
    }
    
    func setResponseBody(completionHandler: @escaping (URLRequest) -> HttpResponse) {
        MockURLProtocol.completionHandler = completionHandler
        setURLProtocol(MockURLProtocol.self)
    }
    
}

class KinveyTestCase: XCTestCase {
    
    let client = Kinvey.sharedClient
    var encrypted = false
    var useMockData = !ProcessInfo.processInfo.arguments.contains("--integrationTests")
    
    static let defaultTimeout = TimeInterval(Int8.max)
    lazy var defaultTimeout: TimeInterval = {
        KinveyTestCase.defaultTimeout
    }()
    
    static let appKey = ProcessInfo.processInfo.environment["KINVEY_APP_KEY"]
    static let appSecret = ProcessInfo.processInfo.environment["KINVEY_APP_SECRET"]
    
    typealias AppInitialize = (appKey: String, appSecret: String)
    static let appInitializeDevelopment = AppInitialize(appKey: "kid_Wy35WH6X9e", appSecret: "d85f81cad5a649baaa6fdcd99a108ab1")
    static let appInitializeProduction = AppInitialize(appKey: MockKinveyBackend.kid, appSecret: "appSecret")
    static let appInitialize = appInitializeProduction
    
    func initializeDevelopment() {
        if !Kinvey.sharedClient.isInitialized() {
            Kinvey.sharedClient.initialize(
                appKey: KinveyTestCase.appInitializeDevelopment.appKey,
                appSecret: KinveyTestCase.appInitializeDevelopment.appSecret,
                apiHostName: URL(string: "https://v3yk1n-kcs.kinvey.com")!,
                encrypted: encrypted
            )
        }
    }
    
    func initializeProduction() {
        if !Kinvey.sharedClient.isInitialized() {
            Kinvey.sharedClient.initialize(
                appKey: KinveyTestCase.appKey ?? KinveyTestCase.appInitializeProduction.appKey,
                appSecret: KinveyTestCase.appSecret ?? KinveyTestCase.appInitializeProduction.appSecret,
                encrypted: encrypted
            )
        }
        
    }
    
    override func setUp() {
        super.setUp()
        
        if KinveyTestCase.appInitialize == KinveyTestCase.appInitializeDevelopment {
            initializeDevelopment()
        } else {
            initializeProduction()
        }
        
        XCTAssertNotNil(client.isInitialized())
        
        if let activeUser = client.activeUser {
            activeUser.logout()
        }
    }
    
    class SignUpMockURLProtocol: URLProtocol {
        
        override class func canInit(with request: URLRequest) -> Bool {
            return true
        }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            return request
        }
        
        override func startLoading() {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "1.1", headerFields: [ "Content-Type" : "application/json; charset=utf-8" ])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            
            var resquestBody: [String : Any]? = nil
            if let data = request.httpBody {
                resquestBody = try! JSONSerialization.jsonObject(with: data) as? [String : Any]
            } else if let httpBodyStream = request.httpBodyStream {
                httpBodyStream.open()
                defer {
                    httpBodyStream.close()
                }
                resquestBody = try! JSONSerialization.jsonObject(with: httpBodyStream) as? [String : Any]
            }
            
            var responseBody = [
                "_id" : UUID().uuidString,
                "username" : (resquestBody?["username"] as? String) ?? UUID().uuidString,
                "_kmd" : [
                    "lmt" : "2016-10-19T21:06:17.367Z",
                    "ect" : "2016-10-19T21:06:17.367Z",
                    "authtoken" : "my-auth-token"
                ],
                "_acl" : [
                    "creator" : "masterKey-creator-id"
                ]
            ] as [String : Any]
            if let resquestBody = resquestBody {
                responseBody += resquestBody
            }
            let data = try! JSONSerialization.data(withJSONObject: responseBody)
            client?.urlProtocol(self, didLoad: data)
            
            client?.urlProtocolDidFinishLoading(self)
        }
        
        override func stopLoading() {
        }
        
    }
    
    func signUp<UserType: User>(username: String? = nil, password: String? = nil, user: UserType? = nil, mustHaveAValidUserInTheEnd: Bool = true, completionHandler: ((UserType?, Swift.Error?) -> Void)? = nil) {
        if let user = client.activeUser {
            user.logout()
        }
        
        if useMockData {
            setURLProtocol(MockKinveyBackend.self)
        }
        defer {
            if useMockData {
                setURLProtocol(nil)
            }
        }
        
        weak var expectationSignUp = expectation(description: "Sign Up")
        
        let handler: (UserType?, Swift.Error?) -> Void = { user, error in
            if let completionHandler = completionHandler {
                completionHandler(user, error)
            } else {
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertNotNil(user)
            }
            
            expectationSignUp?.fulfill()
        }
        
        if let username = username {
            User.signup(username: username, user: user, completionHandler: handler)
        } else {
            User.signup(user: user, completionHandler: handler)
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSignUp = nil
        }
        
        if mustHaveAValidUserInTheEnd {
            XCTAssertNotNil(client.activeUser)
        }
    }
    
    func signUp(username: String, password: String) {
        if let user = client.activeUser {
            user.logout()
        }
        
        weak var expectationSignUp = expectation(description: "Sign Up")
        
        User.signup(username: username, password: password) { user, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(error)
            XCTAssertNotNil(user)
            
            expectationSignUp?.fulfill()
        }
        
        waitForExpectations(timeout: defaultTimeout) { error in
            expectationSignUp = nil
        }
        
        XCTAssertNotNil(client.activeUser)
    }
    
    override func tearDown() {
        setURLProtocol(nil)
        
        if let user = client.activeUser {
            if useMockData {
                setURLProtocol(MockKinveyBackend.self)
            }
            defer {
                if useMockData {
                    setURLProtocol(nil)
                }
            }
            
            weak var expectationDestroyUser = expectation(description: "Destroy User")
            
            user.destroy { (error) -> Void in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                
                expectationDestroyUser?.fulfill()
            }
            
            waitForExpectations(timeout: defaultTimeout) { error in
                expectationDestroyUser = nil
            }
            
            XCTAssertNil(client.activeUser)
        }
        
        super.tearDown()
    }
    
}
