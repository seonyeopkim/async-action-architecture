@testable import AsyncActionArchitecture
import Combine
import XCTest

final class StoreTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()
    
    func testRelayBetweenActionAndAsyncAction() {
        struct TestReducer: Reducer {
            struct State: Equatable {}
            
            enum Action {
                case first
                case third
            }
            
            enum AsyncAction {
                case second
            }
            
            let expectation: XCTestExpectation
            
            func reduce(into state: inout State, action: Action) -> Effect<Action, AsyncAction> {
                switch action {
                case .first:
                    return .run(.second)
                case .third:
                    self.expectation.fulfill()
                    return .none
                }
            }
            
            func run(action: AsyncAction) async -> Effect<Action, AsyncAction> {
                switch action {
                case .second: .send(.third)
                }
            }
        }
        
        // given
        let reducer = TestReducer(expectation: XCTestExpectation())
        let store = Store(reducer: reducer, initialState: .init())
        
        // when
        store._send(.first)
        
        // then
        wait(for: [reducer.expectation], timeout: 1)
    }
    
    func testRelayBetweenActions() {
        struct TestReducer: Reducer {
            struct State: Equatable {}
            struct AsyncAction {}
            
            enum Action {
                case first
                case second
            }
            
            let expectation: XCTestExpectation
            
            func reduce(into state: inout State, action: Action) -> Effect<Action, AsyncAction> {
                switch action {
                case .first:
                    return .send(.second)
                case .second:
                    self.expectation.fulfill()
                    return .none
                }
            }
        }
        
        // given
        let reducer = TestReducer(expectation: XCTestExpectation())
        let store = Store(reducer: reducer, initialState: .init())
        
        // when
        store._send(.first)
        
        // then
        wait(for: [reducer.expectation], timeout: 1)
    }
    
    func testRelayBetweenAsyncActions() {
        struct TestReducer: Reducer {
            struct State: Equatable {}
            struct Action {}
            
            enum AsyncAction {
                case first
                case second
            }
            
            let expectation: XCTestExpectation
            
            func run(action: AsyncAction) async -> Effect<Action, AsyncAction> {
                switch action {
                case .first:
                    return .run(.second)
                case .second:
                    self.expectation.fulfill()
                    return .none
                }
            }
        }
        
        // given
        let reducer = TestReducer(expectation: XCTestExpectation())
        let store = Store(reducer: reducer, initialState: .init())
        
        // when
        store.run(.first)
        
        // then
        wait(for: [reducer.expectation], timeout: 1)
    }
    
    func testPublisherForWholeState() {
        // given
        let store = Store<TestReducer>()
        var stream = [TestReducer.State]()
        store.publisher
            .sink { stream.append($0) }
            .store(in: &self.cancellables)
        
        // when
        store.send(.resetState)
        store.send(.resetState)
        store.send(.logCount)
        store.send(.logCount)
        store.send(.increase)
        store.send(.increase)
        
        //then
        let expectation: [TestReducer.State] = [
            .init(counter: 0, log: nil),
            .init(counter: 0, log: "0"),
            .init(counter: 1, log: "0"),
            .init(counter: 2, log: "0")
        ]
        XCTAssertEqual(stream, expectation)
    }
    
    func testPublisherForKeyPath() {
        // given
        let store = Store<TestReducer>()
        var counterStream = [Int]()
        var logStream = [String?]()
        var passthroughLogStream = [String?]()
        store.publisher(for: \.counter)
            .sink { counterStream.append($0)}
            .store(in: &self.cancellables)
        store.publisher(for: \.log)
            .sink { logStream.append($0) }
            .store(in: &self.cancellables)
        store.passthroughPublisher(for: \.$log)
            .sink { passthroughLogStream.append($0) }
            .store(in: &self.cancellables)
        
        // when
        store.send(.resetState)
        store.send(.resetState)
        store.send(.logCount)
        store.send(.logCount)
        store.send(.increase)
        store.send(.increase)
        
        //then
        XCTAssertEqual(counterStream, [0, 1, 2])
        XCTAssertEqual(logStream, [nil, "0"])
        XCTAssertEqual(passthroughLogStream, [nil, "0", "0"])
    }
}

extension Store where R == TestReducer {
    convenience init() {
        self.init(reducer: .init(), initialState: .init())
    }
}

struct TestReducer: Reducer {
    struct AsyncAction {}
    
    struct State: Equatable {
        var counter: Int = .zero
        @Passthrough var log: String?
    }
    
    enum Action {
        case increase
        case logCount
        case resetState
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action, AsyncAction> {
        switch action {
        case .increase: state.counter += 1
        case .logCount: state.log = "\(state.counter)"
        case .resetState: state = .init()
        }
        return .none
    }
}

extension Reducer {
    func reduce(into state: inout State, action: Action) -> Effect<Action, AsyncAction> { .none }
    func run(action: AsyncAction) async -> Effect<Action, AsyncAction> { .none }
}
