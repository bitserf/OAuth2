//
// OAuth2
// Copyright (C) 2015 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import XCTest

@testable import OAuth2

let authorizationURL = "http://nonexistent.com/authorization"
let tokenURL = "http://nonexistent.com/token"
let redirectURL = "http://nonexistent.com/redirection"
let clientId = "test-client-id"
let clientSecret = "test-client-secret"
let accessToken = "open sesame"
let refreshToken = "ali baba"

class OAuth2Tests: XCTestCase {
    override func setUp() {
        OAuth2.urlRequestHook = testURLRequest
        OAuth2.webViewRequestHook = testWebViewRequest
    }

    func testAuthorizationCodeSuccessfulAuth() {
        setUpWebViewResponse(["code": "abc123"], error: nil)
        setUpURLResponse(200,
                         url: tokenURL,
                         body: ["access_token": accessToken].toJSONString(),
                         headers: ["Content-Type": "application/json"])

        let request = AuthorizationCodeRequest(authorizationURL: authorizationURL,
                                               tokenURL: tokenURL,
                                               clientId: clientId,
                                               clientSecret: clientSecret,
                                               redirectURL: redirectURL)!
        var response: Response!
        performOAuthRequest("authorization-code-request") { finished in
            OAuth2.authorize(request) { response = $0 }
            finished()
        }

        switch response! {
        case .Success(let data):
            XCTAssertEqual(accessToken, data.accessToken)
            break
        default:
            XCTFail("expected request to succeed, but was \(response) instead")
        }
    }

    func testAuthorizationCodeServerRejectedAuth() {
        setUpWebViewResponse(["error": "invalid_scope", "error_description": "the+scope+was+not+valid"],
                             error: nil)

        let request = AuthorizationCodeRequest(authorizationURL: authorizationURL,
            tokenURL: tokenURL,
            clientId: clientId,
            clientSecret: clientSecret,
            redirectURL: redirectURL)!
        var response: Response? = nil
        performOAuthRequest("authorization-code-request") { finished in
            OAuth2.authorize(request) { response = $0 }
            finished()
        }

        switch response {
        case .Some(.Failure(let error)):
            switch error {
            case AuthorizationFailure.OAuthInvalidScope(let description):
                XCTAssertEqual("the scope was not valid", description)
            default:
                XCTFail("expected error to be OAuthInvalidScope, but was \(error) instead")
            }
            break
        default:
            XCTFail("expected request to fail, but was \(response) instead")
        }
    }

    func testRefreshTokenSuccessfulAuth() {
        setUpURLResponse(200,
                         url: tokenURL,
                         body: ["access_token": accessToken].toJSONString(),
                         headers: ["Content-Type": "application/json"])

        let request = RefreshTokenRequest(
            tokenURL: tokenURL,
            clientId: clientId,
            clientSecret: clientSecret,
            refreshToken: refreshToken)!
        var response: Response? = nil
        performOAuthRequest("refresh-token-request") { finished in
            OAuth2.refresh(request) { response = $0 }
            finished()
        }

        switch response {
        case .Some(.Success(let data)):
            XCTAssertEqual(accessToken, data.accessToken)
            break
        default:
            XCTFail("expected request to succeed, but was \(response) instead")
        }
    }

    func testRefreshTokenRejectedAuth() {
        setUpURLResponse(400,
                         url: tokenURL,
                         body: [
                            "error": "invalid_grant",
                            "error_description":"refresh+token+expired"
                         ].toJSONString(),
                         headers: ["Content-Type": "application/json"])

        let request = RefreshTokenRequest(
            tokenURL: tokenURL,
            clientId: clientId,
            clientSecret: clientSecret,
            refreshToken: refreshToken)!
        var response: Response? = nil
        performOAuthRequest("refresh-token-request") { finished in
            OAuth2.refresh(request) { response = $0 }
            finished()
        }

        switch response {
        case .Some(.Failure(let error)):
            switch error {
            case AuthorizationFailure.OAuthInvalidGrant(let description):
                XCTAssertEqual("refresh token expired", description)
            default:
                XCTFail("expected request to fail with OAuthInvalidGrant, but was \(error) instead")
            }
        default:
            XCTFail("expected request to fail with OAuthInvalidGrant, but was \(response) instead")
        }
    }

    func testClientCredentialsSuccessfulAuth() {
        setUpURLResponse(200,
                         url: authorizationURL,
                         body: ["access_token": accessToken].toJSONString(),
                         headers: ["Content-Type": "application/json; encoding=utf-8"])

        let request = ClientCredentialsRequest(authorizationURL: authorizationURL,
                                               clientId: clientId,
                                               clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("client-credentials-request") { finished in
            OAuth2.authorize(request) { response = $0 }
            finished()
        }

        switch response! {
        case .Success(let data):
            XCTAssertEqual(accessToken, data.accessToken)
            break
        default:
            XCTFail("expected request to succeed, but was \(response) instead")
        }
    }

    func testClientCredentialsServerRejectedAuth() {
        setUpURLResponse(400,
                         url: authorizationURL,
                         body: [
                            "error": "access_denied",
                            "error_description": "internal error"
                         ].toJSONString(),
                         headers: ["Content-Type": "application/json"])

        let request = ClientCredentialsRequest(authorizationURL: authorizationURL,
                                               clientId: clientId,
                                               clientSecret: clientSecret)!
        var response: Response?
        performOAuthRequest("client-credentials-request") { finished in
            OAuth2.authorize(request) { response = $0 }
            finished()
        }

        switch response {
        case .Some(.Failure(let error)):
            switch error {
            case AuthorizationFailure.OAuthAccessDenied(let description):
                XCTAssertEqual("internal error", description)
            default:
                XCTFail("expected request to fail with OAuthAccessDenied, but was \(error) instead")
            }
        default:
            XCTFail("expected request to fail with OAuthAccessDenied, but was \(response) instead")
        }
    }

    // - MARK: test helpers

    private var handleURLRequest: (OAuth2.URLRequestCompletionHandler -> Void)! = nil
    private var handleWebViewRequest: (WebViewCompletionHandler -> Void)! = nil

    private func testURLRequest(request: NSURLRequest,
                                completionHandler: (NSData?, NSURLResponse?, ErrorType?) -> Void) {
        assert(handleURLRequest != nil)
        handleURLRequest(completionHandler)
    }

    private func testWebViewRequest(request: NSURLRequest,
                                    redirectionURL: NSURL,
                                    createWebViewController: CreateWebViewController,
                                    completionHandler: WebViewCompletionHandler) {
        assert(handleWebViewRequest != nil)
        handleWebViewRequest(completionHandler)
    }

    private func setUpURLResponse(statusCode: Int,
                                  url urlString: String,
                                  body: String,
                                  headers: [String: String] = [:]) {
        let url = NSURL(string: urlString)!
        handleURLRequest = { completion in
            completion(
                body.dataUsingEncoding(NSUTF8StringEncoding),
                NSHTTPURLResponse(URL: url,
                                  statusCode: statusCode,
                                  HTTPVersion: "HTTP/1.1",
                                  headerFields: headers),
                nil)
        }
    }

    private func setUpWebViewResponse(redirectionQueryParameters: [String: String]? = nil,
                                      error: ErrorType? = nil) {
        handleWebViewRequest = { completion in
            if redirectionQueryParameters != nil {
                let redirectionURL = self.redirectionURLWithParameters(redirectionQueryParameters!)
                completion(WebViewResponse.Redirection(redirectionURL: redirectionURL))
            } else if error != nil {
                completion(WebViewResponse.LoadError(error: error!))
            } else {
                fatalError("either redirectionQueryParameters: or error: must be provided")
            }
        }
    }

    private func redirectionURLWithParameters(parameters: [String: String]) -> NSURL {
        let components = NSURLComponents(string: redirectURL)!
        components.queryItems = parameters.map { entry in NSURLQueryItem(name: entry.0, value: entry.1) }
        return components.URL!
    }
}

private protocol NSStringConvertible {
    var nsString: NSString { get }
}

private extension XCTestCase {
    func performOAuthRequest(description: String,
                             timeout: NSTimeInterval = 5.0,
                             callback: (() -> Void) -> Void) {
        let expectation = expectationWithDescription(description)
        callback(expectation.fulfill)
        waitForExpectationsWithTimeout(timeout, handler: nil)
   }
}

extension String : NSStringConvertible {
    public var nsString: NSString {
        return NSString(string: self)
    }
}

private extension Dictionary where Key: NSStringConvertible, Value: NSStringConvertible {
    func toJSONString() -> String {
        var dict: [NSString : NSString] = [:]
        for (name, value) in self {
            dict[name.nsString] = value.nsString
        }
        let options = NSJSONWritingOptions(rawValue: 0)
        if let
            data = try? NSJSONSerialization.dataWithJSONObject(dict, options: options),
            string = NSString(data: data, encoding: NSUTF8StringEncoding) as? String {
            return string
        }
        return ""
    }
}
