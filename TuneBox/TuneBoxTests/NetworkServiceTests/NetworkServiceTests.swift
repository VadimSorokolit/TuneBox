//
//  NetworkServiceTests.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 08.05.2026.
//

import Foundation
import Moya
import Testing
@testable import TuneBox

struct NetworkServiceTests {
    
    @Test
    func getPopularTracksReturnsDecodedTracks() async throws {
        let service = makeService { target in
            guard case .getPopularTracks = target else {
                Issue.record("Unexpected target: \(target)")
                
                return makeJSONResponse(statusCode: 500, body: "{}")
            }
            
            return makeJSONResponse(
                statusCode: 200,
                body: """
                {
                  "headers": { "status": "success", "code": 0 },
                  "results": [
                    {
                      "id": "1",
                      "image": "https://example.com/image1.jpg",
                      "name": "Track 1",
                      "artist_name": "Artist 1",
                      "album_name": "Album 1",
                      "releasedate": "2026-05-08",
                      "audiodownload": "https://example.com/audio1.mp3"
                    },
                    {
                      "id": "2",
                      "image": "https://example.com/image2.jpg",
                      "name": "Track 2",
                      "artist_name": "Artist 2",
                      "album_name": "Album 2",
                      "releasedate": "2026-05-09",
                      "audiodownload": "https://example.com/audio2.mp3"
                    }
                  ]
                }
                """
            )
        }
        
        let tracks = try await service.getPopularTracks(
            limit: 20,
            offset: 20
        )
        
        #expect(tracks.count == 2)
        
        #expect(tracks.first?.id == "1")
        #expect(tracks.first?.trackName == "Track 1")
        
        #expect(tracks.last?.id == "2")
        #expect(tracks.last?.trackName == "Track 2")
    }
    
    @Test
    func getTracksByGenreMapsFailedAPIStatusToServerError() async throws {
        let service = makeService { _ in
            makeJSONResponse(
                statusCode: 200,
                body: """
                {
                  "headers": {
                    "status": "failed",
                    "code": 1,
                    "error_message": "Invalid genre"
                  },
                  "results": []
                }
                """
            )
        }
        
        do {
            _ = try await service.getTracksByGenre(genre: "bad", limit: 20, offset: 20)
            Issue.record("Expected APIError.server")
        } catch let error as APIError {
            guard case .server(let message) = error else {
                Issue.record("Expected APIError.server, got \(error)")
                
                return
            }
            
            #expect(message == "Invalid genre")
        }
    }
    
//    @Test
//    func getTrackSizeReturnsParsedContentLength() async throws {
//        let service = makeService { target in
//            guard case .getTrackSize = target else {
//                Issue.record("Unexpected target: \(target)")
//                
//                return makeHeadResponse(statusCode: 500, headers: [:])
//            }
//            return makeHeadResponse(statusCode: 200, headers: ["Content-Length": "12345"])
//        }
//        
//        let size = try await service.getTrackSize(id: 42)
//        
//        #expect(size == 12345)
//    }
//    
//    @Test
//    func getTrackSizeThrowsMissingContentLength() async throws {
//        let service = makeService { _ in
//            makeHeadResponse(statusCode: 200, headers: [:])
//        }
//        
//        do {
//            _ = try await service.getTrackSize(id: 42)
//            
//            Issue.record("Expected APIError.missingContentLength")
//        } catch let error as APIError {
//            guard case .missingContentLength = error else {
//                Issue.record("Expected APIError.missingContentLength, got \(error)")
//                
//                return
//            }
//        }
//    }
//    
//    @Test
//    func getTrackSizeThrowsInvalidContentLength() async throws {
//        let service = makeService { _ in
//            makeHeadResponse(statusCode: 200, headers: ["Content-Length": "abc"])
//        }
//        
//        do {
//            _ = try await service.getTrackSize(id: 42)
//            
//            Issue.record("Expected APIError.invalidContentLength")
//        } catch let error as APIError {
//            guard case .invalidContentLength = error else {
//                Issue.record("Expected APIError.invalidContentLength, got \(error)")
//                
//                return
//            }
//        }
//    }
    
    private func makeService(requestHandler: @escaping (TuneBoxRouter) async throws -> Response) -> NetworkService {
        NetworkService(requestHandler: requestHandler)
    }
    
    private func makeJSONResponse(statusCode: Int, body: String) -> Response {
        Response(statusCode: statusCode, data: Data(body.utf8))
    }
    
    private func makeHeadResponse(statusCode: Int,headers: [String: String]) -> Response {
        guard let url = URL(string: "https://example.com") else {
            fatalError("Invalid test URL")
        }
        
        guard let httpURLResponse = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        ) else {
            fatalError("Failed to create HTTPURLResponse")
        }
        
        return Response(
            statusCode: statusCode,
            data: .init(),
            request: nil,
            response: httpURLResponse
        )
    }
}
