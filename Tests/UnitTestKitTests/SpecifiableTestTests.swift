//
//  File.swift
//  
//
//  Created by Sudo.park on 2020/01/04.
//

import XCTest
import Combine

@testable import UnitTestKit


class SpecifiableTestTests: BaseTestCase, SpecifiableTest {
    
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


extension SpecifiableTestTests {
    
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
    
    func test_waitSingleEventAndAssert() {
        
        let expect = expectation(description: "assert runs")
        
        given(wait: self.makeFuture(100, delay: 0.3)) {
        }
        .when {
        }
        .then(assert:  { value in
            (value == 100).assert()
            expect.fulfill()
        })
        
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
    
    func test_waitFinishAndAssert() {
        
        let expect = expectation(description: "assert runs")
        
        given(wait: self.makePublisher()) {
        }
        .when {
        }
        .thenFinish {
            expect.fulfill()
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
    
    func test_assertFinishFromActionResult() {
        
        let expect = expectation(description: "assert runs")
        
        given {
        }
        .whenWait {
            self.makePublisher()
        }
        .thenFinish {
            expect.fulfill()
        }
        
        self.wait(for: [expect], timeout: self.timeout)
    }
}



extension SpecifiableTestTests {
    
    func test_publisher_eventCollecting() {
        
        let waitResult = self.subject.wait(10) {
            (0..<10).forEach { v in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.subject.send(v)
                }
            }
        }
        
        switch waitResult {
        case .success(let values):
            XCTAssertEqual(values?.sorted(), Array(0..<10))
            
        case .failure(let error):
            XCTFail(error.localizedDescription)
        }
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


class TestSpecifiableTests_usage: BaseTestCase, SpecifiableTest {

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
            self.stubFileHandler
                .stubbing("read", value: Result<String, Error>.success("dummy_data").toFuture)
        }
        .whenWait { () -> Future<String, Error> in
            Swift.print("컴파일러 타입추론 맛탱이가는 포인트")
            return self.sut.loadFile(path: "dummy_path")
        }
        .then { value in
            (value == "dummy_data").assert()
        }
    }
    
    func testResourceManager_loadFileUsingClosure() {
        
        let handler = ClosureEventHandler<String?>()
        given(wait: handler.eraseToAnyPublisher()) {
            self.stubFileHandler.stubbing("read:closure", value: "dummy_data")
        }
        .when {
            self.sut.loadFile(path: "dummy_path", completed: handler.receiver.send)
        }
        .then { value in
            (value == "dummy_data").assert()
        }
    }
}

// MARK: Test Handler to publisher

extension TestSpecifiableTests_usage {
    
    func testHandler_valuePassingUsingEscapingClosure() {

        given {
        }
        .whenWait { () -> AnyPublisher<Int, Never> in
            let handler = ClosureEventHandler<Int>()
            self.sut.pass(value: 100, withEscapingClosure: handler.receiver.send)
            return handler.eraseToAnyPublisher()
        }
        .then(assert: { value in
            (value == 100).assert()
        })
    }

    func testHandler_valuesPassingUsingNonEscapingClosure() {
        given {
        }
        .whenWait { () -> AnyPublisher<Int, Never> in
            let handler = ClosureEventHandler<Int>()
            self.sut.pass(value: 100, withNonEscapingClosure: handler.receiver.send)
            return handler.eraseToAnyPublisher()
        }
        .then(assert: { value in
            (value == 100).assert()
        })
    }
}

// MARK: - Doubles

fileprivate protocol FileHandler {
    
    var isDownloading: Bool { get }
    
    func read(path: String) -> Future<String, Error>
    
    func read(path: String, complete: @escaping (String?) -> Void)
    
    func download(path: String) -> AnyPublisher<Double, Error>
}

fileprivate class StubFileManager: FileHandler, Stubbale {
    
    private var _isDownloading = false
    var isDownloading: Bool {
        return _isDownloading
    }
    
    func read(path: String) -> Future<String, Error> {
        
        self.stubbedOutput("read") ?? Future{ _ in }
    }
    
    func read(path: String, complete: @escaping (String?) -> Void) {
        let result: String? = self.stubbedOutput("read:closure")
        complete(result)
    }
    
    func download(path: String) -> AnyPublisher<Double, Error> {
        
        if let progresses: [Double] = self.stubbedOutput("download") {
            
            self._isDownloading = true
            
            return progresses.publisher
                .map{ $0 }
                .mapError{ _ in NSError() as Error }
                .eraseToAnyPublisher()
        }
        
        let error: Error = self.stubbedOutput("download") ?? NSError()
        return Fail(error: error).eraseToAnyPublisher()
    }
    
    
    
}


fileprivate class ResourceManager {
    
    private var disposebag = CancelBag()
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
            .disposed(by: self.disposebag)
    }
    
    func loadFile(path: String) -> Future<String, Error> {
        
        return self.fileHandler
            .read(path: path)
    }
    
    func loadFile(path: String, completed: @escaping (String?) -> Void) {
        return self.fileHandler
            .read(path: path, complete: completed)
    }
    
    func pass(value: Int, withEscapingClosure closure: @escaping (Int) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            closure(value)
        }
    }
    
    func pass(value: Int, withNonEscapingClosure closure: (Int) -> Void) {
        closure(value)
    }
}



private extension Result {
    
    var toFuture: Future<Success, Failure> {
        return Future { promise in
            switch self {
            case .success(let output):
                promise(.success(output))
                
            case .failure(let error):
                promise(.failure(error))
            }
        }
    }
}
