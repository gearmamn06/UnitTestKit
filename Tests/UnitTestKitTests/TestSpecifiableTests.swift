//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import XCTest
import Combine

@testable import UnitTestKit


class TestSpecifiableTests: BaseTestCase, TestSpecifiable {
    
    struct DummyError: Error {}
 
    private var state: Int!
    private var subject: PassthroughSubject<Int, Never>!
    
    override func setUp() {
        super.setUp()
        self.state = 0
        self.subject = PassthroughSubject()
    }
    
    override func tearDown() {
        self.subject = nil
        self.state = nil
        super.tearDown()
    }
}


extension TestSpecifiableTests {
    
    func test_waitPublisherEventsAndAssert() {
        
        let expect = expectation(description: "assert runs")

        given(wait: self.makePublisher()) {}
        .when {
            Swift.print("fake action")
        }
        .then(take: 10) { values in
            (values == Array(0..<10)).assert()
            expect.fulfill()
        }

        wait(for: [expect], timeout: self.timeout)
    }
    
    func test_waitFailureAndAssert() {
        
        let expect = expectation(description: "assert runs")

        given(wait: self.makeFailure(delay: 0.1)){}
        .when {
        }
        .thenFail(take: 10) {
            if $0 is DummyError {
                expect.fulfill()
            }
        }
        wait(for: [expect], timeout: self.timeout)
    }
    
    func test_makeSideEffectAndAssert() {
        
        let expect = expectation(description: "assert runs")
        
        given {}
        .when {
            self.mutateState(100)
        }
        .then {_ in
            (self.state == 100).assert()
            expect.fulfill()
        }
        
        wait(for: [expect], timeout: self.timeout)
    }
    
    func test_assertValueFromActionResult() {
        
        let expect = expectation(description: "assert runs")
//
        given {
        }
        .when {
            return self.sum(1, rhs: 1)
        }
        .then {
            ($0 == 2).assert()
            expect.fulfill()
        }

        wait(for: [expect], timeout: self.timeout)
    }
    
    func test_assertFutureFromActionResult() {
        
        let expect = expectation(description: "assert runs")
        
        given {
        }
        .whenWait {
            self.makeFuture(100, delay: 0.5)
        }
        .then {
            ($0 == 100).assert()
            expect.fulfill()
        }
        
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func test_assertPublisherFromActionResult() {
        
        let expect = expectation(description: "assert runs")
        
        given {
        }
        .whenWait{ () -> AnyPublisher<Int, Error> in
            return self.makePublisher()
        }
        .then(take: 10, timeout: self.timeout + 0.5) { values in
            (values == Array(0..<10)).assert()
            expect.fulfill()
        }
        
        self.wait(for: [expect], timeout: self.timeout + 0.5)
    }
    
    func test_assertFailreFromActionResult() {
        
        let expect = expectation(description: "assert runs")
        
        given {
        }
        .whenWait {
            self.makeFailure(delay: 0.1)
        }
        .thenFail(take: 10) {
            if $0 is DummyError {
                expect.fulfill()
            }
        }
        wait(for: [expect], timeout: self.timeout)
    }
}



extension TestSpecifiableTests {
    
    func test_publisher_eventCollecting() {
        
        let values = self.subject.wait(10) {
            (0..<10).forEach { v in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.subject.send(v)
                }
            }
        }
        
        XCTAssertEqual(values?.sorted(), Array(0..<10))
    }
    
    
    private func makeFuture(_ value: Int,
                                 delay: TimeInterval) -> Future<Int, Error> {
        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                promise(.success(value))
            }
        }
    }
    
    private func makePublisher() -> AnyPublisher<Int, Error> {
        let justs = Array(0..<10).map{ Just($0).eraseToAnyPublisher() }
        let seedEvent = Empty<Int, Error>().eraseToAnyPublisher()
        return justs.reduce(into: seedEvent, { acc, just in
            let delayed = just
                .delay(for: .milliseconds(10), scheduler: RunLoop.main)
                .eraseToAnyPublisher()
                .mapError{ _ in NSError(domain: "", code: 0, userInfo: nil) as Error }
            acc = acc.append(delayed).eraseToAnyPublisher()
        })
        .eraseToAnyPublisher()
    }
    
    private func makeFailure(delay: TimeInterval) -> AnyPublisher<Int, Error> {
        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                promise(.failure(DummyError()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func mutateState(_ newValue: Int) {
        self.state = newValue
    }
    
    private func sum(_ lhs: Int, rhs: Int) -> Int {
        return lhs + rhs
    }
}



// MARK: - Usage


class TestSpecifiableTests_usage: BaseTestCase, TestSpecifiable {

    private var sut: ResourceManager!
    private var stubFileHandler: StubFileManager!
    
    override func setUp() {
        super.setUp()
        self.stubFileHandler = StubFileManager()
        self.sut = ResourceManager(fileHandler: self.stubFileHandler)
    }
    
    override func tearDown() {
        self.stubFileHandler = nil
        self.sut = nil
        super.tearDown()
    }
    
    // action -> side effect, and assert
    func testResourceManager_whenDownloadStarted_changeStatus() {
        given {
            let progresses: [Double] = [0, 0.1, 0.2]
            self.stubFileHandler.stubbing("download", value: progresses)
        }
        .when {
            self.sut.startDownloading(path: "dummy_path")
        }
        .then {
            (self.sut.isDownloading == true).assert()
        }
    }
    
    func testResourceManager_whenDownloadFail_emitError() {
        
        given(wait: self.sut.downloadingError) {
            Swift.print("no stubbing -> error")
        }
        .when {
            self.sut.startDownloading(path: "dummy_path")
        }
        .then(take: 1) { errors in
            (errors.isEmpty == false).assert()
        }
    }
    
    func testResourceManager_whenDownloading_emitPercent() {
        
        given(wait: self.sut.downloadingPercent) {
            let progresses: [Double] = [0, 0.1, 0.2]
            self.stubFileHandler.stubbing("download", value: progresses)
        }
        .when {
            self.sut.startDownloading(path: "dummy_path")
        }
        .then(take: 3) {
            ($0 == [0, 0.1, 0.2]).assert()
        }
    }
    
    func testResourceManager_loadFile() {
        
        given {
            self.stubFileHandler.stubbing("read", value: "dummy_data")
        }
        .whenWait { () -> Future<String, Error> in
            Swift.print("컴파일러 타입추론 맛탱이가는 포인트")
            return self.sut.loadFile(path: "dummy_path")
        }
        .then { value in
            (value == "dummy_data").assert()
        }
    }
}

// MARK: - Doubles

fileprivate protocol FileHandler {
    
    var isDownloading: Bool { get }
    
    func read(path: String) -> Future<String, Error>
    
    func download(path: String) -> AnyPublisher<Double, Error>
}

fileprivate class StubFileManager: FileHandler, Stubbale {
    
    private var _isDownloading = false
    var isDownloading: Bool {
        return _isDownloading
    }
    
    func read(path: String) -> Future<String, Error> {
        
        return Future { promise in
            promise(self.result("read"))
        }
    }
    
    func download(path: String) -> AnyPublisher<Double, Error> {
        
        let result: Result<[Double], Error> = self.result("download")

        switch result {
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
            
        case .success(let progresses):
            
            self._isDownloading = true
            
            let justs = progresses.map{ Just($0).eraseToAnyPublisher() }
            let seedEvent = Empty<Double, Error>().eraseToAnyPublisher()
            return justs.reduce(into: seedEvent, { acc, just in
                let delayed = just
                    .mapError{ _ in NSError(domain: "", code: 0, userInfo: nil) as Error }
                acc = acc.append(delayed).eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
        }
    }
    
    
    
}


fileprivate class ResourceManager {
    
    private var disposebag = PublisherDisposeBag()
    private let fileHandler: FileHandler
    
    private let _percent = PassthroughSubject<Double, Never>()
    private let _occuredError = PassthroughSubject<Error, Never>()
    
    public init(fileHandler: FileHandler) {
        self.fileHandler = fileHandler
    }
}


extension ResourceManager {
    
    var isDownloading: Bool {
        return self.fileHandler.isDownloading
    }
    
    var downloadingError: AnyPublisher<Error, Never> {
        return self._occuredError
            .eraseToAnyPublisher()
    }
    
    var downloadingPercent: AnyPublisher<Double, Never> {
        return self._percent
            .eraseToAnyPublisher()
    }
    
    
    func startDownloading(path: String) {
        self.fileHandler
        .download(path: path)
            .sink(receiveCompletion: { complete in
                
                switch complete {
                case .failure(let error):
                    self._occuredError.send(error)
                    
                default:break
                }
                
            }, receiveValue: { [weak self] percent in
                self?._percent.send(percent)
            })
            .disposed(by: &self.disposebag)
    }
    
    func loadFile(path: String) -> Future<String, Error> {
        
        return self.fileHandler
            .read(path: path)
    }
}
