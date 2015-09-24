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

/// Represents a general OAuth 2.0 request.
public protocol Request {
    /// The authorization URL for the request, if applicable to the grant type.
    var authorizationURL: NSURL? { get }
    
    /// The token URL for the request, if applicable to the grant type.
    var tokenURL: NSURL? { get }
    
    /// Any HTTP headers that need to be set for the request.
    var headers: [String: String] { get }
    
    /// Any URI parameters that need to be set for the request.
    var parameters: [String: String] { get }
}

/// Represents an OAuth 2.0 `client_credentials` request. This is a two-legged request type.
struct ClientCredentialsRequest : Request {
    let authorizationURL: NSURL?
    let tokenURL: NSURL? = nil
    let headers: [String: String]
    let parameters: [String: String]
    
    /// Initializes a `client_credentials` request.
    /// - Parameters:
    ///   - url: The URL of the authorization service.
    ///   - clientId: The client ID for the caller, must have been provided by the service.
    ///   - clientSecret: The client secret for the caller, must have been provided by the service.
    ///   - useAuthorizationHeader: Whether or not to use the `Authorization` HTTP header. If not used,
    ///                             the `client_id` and `client_secret` parameters will be passed via
    ///                             HTTP request parameters instead.
    init?(url: String, clientId: String, clientSecret: String, useAuthorizationHeader: Bool = true) {
        var parameters: [String : String] = [:]
        var headers: [String : String] = [:]
        
        if let authorizationURL = NSURL(string: url) {
            self.authorizationURL = authorizationURL
            parameters["grant_type"] = "client_credentials"
            if !useAuthorizationHeader {
                parameters["client_id"] = clientId
                parameters["client_secret"] = clientSecret
            } else {
                let credentials = "\(clientId):\(clientSecret)".base64Value!
                headers["Authorization"] = "Basic \(credentials)"
            }
            self.parameters = parameters
            self.headers = headers
        } else {
            return nil
        }
    }
}

extension Request {
    /// Converts an OAuth request into an `NSURLRequest`. Headers and parameters
    /// are added to the request.
    /// - Parameters:
    ///   - url: The URL to use as the base URL for the request.
    func toNSURLRequest(url: NSURL) -> NSURLRequest? {
        if let urlComponents = NSURLComponents(string: url.absoluteString) {
            for (name, value) in parameters {
                let component = NSURLQueryItem(name: name, value: value)
                urlComponents.queryItems?.append(component)
            }
            if let url = urlComponents.URL {
                let request = NSMutableURLRequest(URL: url)
                for (name, value) in headers {
                    request.setValue(value, forHTTPHeaderField: name)
                }
                return request
            }
        }
        return nil
    }
}