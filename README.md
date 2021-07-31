# UnitTestKit
Test helper kit specialized for asynchronous operation (especially Combine)

## Usage


```swift
import XCTest
import Combine

@testable import UnitTestKit


class TestSpecifiableTests_usage: BaseTestCase, SpecifiableTest {

    private var sut: ResourceManager!
    private var mockFileHandler: MockFileManager!
    
    override func setUp() {
        super.setUp()
        self.mockFileHandler = MockFileManager()
        self.sut = ResourceManager(fileHandler: self.mockFileHandler)
    }
    
    override func tearDown() {
        self.mockFileHandler = nil
        self.sut = nil
        super.tearDown()
    }
    
    // action -> side effect, and assert
    func testResourceManager_whenDownloadStarted_changeStatus() {
        given {
            let progresses: [Double] = [0, 0.1, 0.2]
            self.mockFileHandler.register("download", value: progresses)
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
            struct DummyError: Error {}
            self.mockFileHandler.register("download", value: DummyError())
        }
        .when {
            self.sut.startDownloading(path: "dummy_path")
        }
        .then(assert: { _ in
            (true).assert()
        })
    }
    
    func testResourceManager_whenDownloading_emitPercent() {
        
        given(wait: self.sut.downloadingPercent) {
            let progresses: [Double] = [0, 0.1, 0.2]
            self.mockFileHandler.register("download", value: progresses)
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
            self.mockFileHandler
                .register("read", value: Result<String, Error>.success("dummy_data").toFuture)
        }
        .whenWait { () -> Future<String, Error> in
            return self.sut.loadFile(path: "dummy_path")
        }
        .then { value in
            (value == "dummy_data").assert()
        }
    }
    
    func testResourceManager_loadFileUsingClosure() {
        
        let handler = ClosureEventHandler<String?>()
        given(wait: handler.eraseToAnyPublisher()) {
            self.mockFileHandler.register("read:closure", value: "dummy_data")
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


// MARK: - Mocking

fileprivate protocol FileHandler {
    
    var isDownloading: Bool { get }
    
    func read(path: String) -> Future<String, Error>
    
    func read(path: String, complete: @escaping (String?) -> Void)
    
    func download(path: String) -> AnyPublisher<Double, Error>
}

fileprivate class MockFileManager: FileHandler, Mocking {
    
    private var _isDownloading = false
    var isDownloading: Bool {
        return _isDownloading
    }
    
    func read(path: String) -> Future<String, Error> {
        
        self.resolve("read") ?? Future{ _ in }
    }
    
    func read(path: String, complete: @escaping (String?) -> Void) {
        let result: String? = self.resolve("read:closure")
        complete(result)
    }
    
    func download(path: String) -> AnyPublisher<Double, Error> {
        
        if let progresses: [Double] = self.resolve("download") {
            
            self._isDownloading = true
            
            return progresses.publisher
                .map{ $0 }
                .mapError{ _ in NSError() as Error }
                .eraseToAnyPublisher()
        } else if let error: Error = self.resolve("download") {
            return Fail(error: error).eraseToAnyPublisher()
        } else {
            return Empty().eraseToAnyPublisher()
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
    
    func loadFile(path: String, completed: @escaping (String?) -> Void) {
        return self.fileHandler
            .read(path: path, complete: completed)
    }
}
```  
