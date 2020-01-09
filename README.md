# UnitTestKit
Test helper kit specialized for asynchronous operation (especially Combine)

## Usage


```swift
import XCTest
import Combine

@testable import UnitTestKit


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
            self.stubFileHandler.stubbing("read", value: "dummy_data")
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
        
        return Future { promise in
            promise(self.result("read"))
        }
    }
    
    func read(path: String, complete: @escaping (String?) -> Void) {
        let result: Result<String, Never> = self.result("read:closure")
        switch result {
        case .success(let data):
            complete(data)
            
        default:
            complete(nil)
        }
    }
    
    func download(path: String) -> AnyPublisher<Double, Error> {
        
        let result: Result<[Double], Error> = self.result("download")

        switch result {
        case .failure(let error):
            return Fail(error: error).eraseToAnyPublisher()
            
        case .success(let progresses):
            
            self._isDownloading = true
            
            return progresses.publisher
                .map{ $0 }
                .mapError { _ in NSError(domain: "", code: 0, userInfo: nil) as Error }
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
    
    func loadFile(path: String, completed: @escaping (String?) -> Void) {
        return self.fileHandler
            .read(path: path, complete: completed)
    }
}
```  
