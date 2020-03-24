//
//  URLSession.swift
//  CoLocate
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import Foundation

extension URLSession: Session {

    var baseURL: URL {
        let endpoint = Bundle(for: AppDelegate.self).infoDictionary?["API_ENDPOINT"] as! String
        return URL(string: endpoint)!
    }
    
    func execute<R: Request>(_ request: R, queue: OperationQueue, completion: @escaping (Result<R.ResponseType, Error>) -> Void) {
        let completion = { result in queue.addOperation { completion(result) } }

        let url = URL(string: request.path, relativeTo: baseURL)!
        var urlRequest = URLRequest(url: url)
        
        urlRequest.allHTTPHeaderFields = request.headers
        
        switch request.method {
        case .get:
            urlRequest.httpMethod = "GET"
            
        case .post(let data):
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = data
            
        case .patch(let data):
            urlRequest.httpMethod = "PATCH"
            urlRequest.httpBody = data
        }
        
        let task = dataTask(with: urlRequest) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            do {
                switch (data, statusCode, error) {
                case (let data?, let statusCode?, _) where 200..<300 ~= statusCode:
                    let parsed = try request.parse(data)
                    completion(.success(parsed))

                case (_, let statusCode?, _):
                    throw NSError(domain: "RequestErrorDomain", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Received \(statusCode) status code from server"])

                case (_, _, let error?):
                    throw error

                default:
                    break
                }
            } catch (let error) {
                completion(.failure(error))
            }
        }

        task.resume()
    }

}
