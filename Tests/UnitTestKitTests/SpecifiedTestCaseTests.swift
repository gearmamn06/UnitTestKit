//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/02.
//

import Foundation
import Combine

@testable import UnitTestKit


class SpecifiedTestCaseTests: SpecifiedTestCase {
    
    private var disposeBag: Set<AnyCancellable>!
    private var dummyDownloader: DummyDownloader!
    private var sut: FakeDownloadManager!
    
    override func setUp() {
        super.setUp()
        self.disposeBag = []
        self.dummyDownloader = DummyDownloader()
        self.sut = FakeDownloadManager(downloader: self.dummyDownloader)
    }
    
    override func tearDown() {
        self.disposeBag = nil
        self.dummyDownloader = nil
        self.sut = nil
        super.tearDown()
    }
}


extension SpecifiedTestCaseTests {
    
    func test_returnResultSync() {
        
//        given {
//            self.downloader.stubbing(<#T##name: String##String#>, value: <#T##Any#>)
//        }
//        .when {
//            self.downloader.isReady()
//        }
    }
    
    func test_mutatingStateSync() {
        
        given { }
        .when {
            self.sut.mutateState(100)
        }
        .then {
            (self.sut.currentState == 100).assert()
        }
    }
    
    func test_asyncResultAsAFuture() {
        
        given {
            
            self.dummyDownloader.stubbing("download", value: 100)
        }
        .when {
            
            self.sut.download(path: "dummy_path")
        }
        .then {
            $0.assert(100)
                .store(in: &self.disposeBag)
        }
    }
    
    func test_asyncResultAsAnyPublisher() {
        
        given {
            
            self.dummyDownloader.stubbing("download:progress", value: [0.0, 1.0, 2.0])
            self.dummyDownloader.stubbing("download:result", value: 100)
        }
        .when {
            self.sut.downloadWithProgress(path: "dummy_path")
        }
        .then {
            let expected: [DownloadingProgress] = [
                .downloading(0.0), .downloading(1.0),
                .downloading(2.0), .completed(100)
            ]
            $0.assert(expected, message: "take progress and result")
                .store(in: &self.disposeBag)
        }
    }
}



fileprivate enum DownloadingProgress {
    case idle
    case downloading(_ percent: Double)
    case completed(_ data: Int)
    case fail(_ error: Error)
}

extension DownloadingProgress: Equatable {
    
    private var identifiler: String {
        switch self {
        case .idle: return "idle"
        case .downloading(let percent): return "downloading\(percent)"
        case .completed(let result): return "completed\(result)"
        case .fail(let error): return "fail\(error.localizedDescription)"
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.identifiler == rhs.identifiler
    }
}

fileprivate protocol Downloadable {
    
    func isReady() -> Bool
    
    func download(path: String) -> Future<Int, Error>
    
    func downloadWithProgress(path: String) -> AnyPublisher<DownloadingProgress, Never>
    
    func download(path: String, completed: @escaping (Int) -> Void)
    
    func download(path: String,
                  resultHandler: @escaping (Result<Int, Error>) -> Void)
    
    func download(path: String,
                  progressBlock: @escaping (Double) -> Void,
                  resultHandler: @escaping (Result<Int, Error>) -> Void)
}

fileprivate class DummyDownloader: Downloadable, Spyable, Stubbale {
    
    func isReady() -> Bool {
        let result: Result<Bool, Error> = self.result("isReady")
        switch result {
        case .success(let flag):
            return flag
        case .failure:
            return false
        }
    }
    
    func download(path: String) -> Future<Int, Error> {
        
        self.spy("download", args: path)
        
        return self.result("download")
            .asFuture
    }
    
    func downloadWithProgress(path: String) -> AnyPublisher<DownloadingProgress, Never> {
        
        self.spy("downloadWithProgress", args: path)
        
        guard let percents: [Double] = self.resolveValue("download:progress"),
            let result: Int = self.resolveValue("download:result") else {
                fatalError()
        }
        
        let progresses: [DownloadingProgress] =
            percents.map{ DownloadingProgress.downloading($0) }
                + [.completed(result)]
        let seed: AnyPublisher<DownloadingProgress, Never>
            = Just(DownloadingProgress.idle).eraseToAnyPublisher()
        return progresses.reduce(seed) { acc, p in
            return acc.append(p).eraseToAnyPublisher()
        }
        .dropFirst()
        .eraseToAnyPublisher()
    }
    
    func download(path: String, completed: @escaping (Int) -> Void) {
        
        self.spy("download", args: path)
        
        let result: Result<Int, Error> = self.result("download")
        
        switch result {
        case .success(let value):
            completed(value)
            
        default: break
        }
    }
    
    func download(path: String, resultHandler: @escaping (Result<Int, Error>) -> Void) {
        
        self.spy("download", args: path)
        
        let result: Result<Int, Error> = self.result("download")
        resultHandler(result)
    }
    
    func download(path: String, progressBlock: @escaping (Double) -> Void, resultHandler: @escaping (Result<Int, Error>) -> Void) {
        
        // TODO:
    }
}

fileprivate class FakeDownloadManager {
    
    var currentState: Int = 0
    
    func mutateState(_ newValue: Int) {
        self.currentState = newValue
    }
    
    private let downloader: Downloadable
    
    public init(downloader: Downloadable) {
        self.downloader = downloader
    }
    
    func isReady() -> Bool {
        return self.downloader.isReady()
    }
    
    func download(path: String) -> Future<Int, Error> {
        return self.downloader.download(path: path)
    }
    
    func downloadWithProgress(path: String) -> AnyPublisher<DownloadingProgress, Never> {
        return self.downloader.downloadWithProgress(path: path)
    }
    
    func download(path: String, completed: @escaping (Int) -> Void) {
        self.downloader
            .download(path: path,
                      completed: { result in
                        completed(result)
            })
    }
    
    func download(path: String, resultHandler: @escaping (Result<Int, Error>) -> Void) {
        self.downloader
            .download(path: path,
                      resultHandler: { result in
                        resultHandler(result)
            })
    }
    
    func download(path: String, progressBlock: @escaping (Double) -> Void, resultHandler: @escaping (Result<Int, Error>) -> Void) {
        self.downloader
        .download(path: path,
                  progressBlock: { progress in
                    
                    progressBlock(progress)
                    
        }, resultHandler: { result in
            
            resultHandler(result)
        })
    }
}
