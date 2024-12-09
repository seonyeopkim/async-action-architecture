import Combine
import Foundation

public final class Store<R: Reducer> {
    public var currentState: R.State {
        self.state
    }
    @Published private var state: R.State
    private let reducer: R
    
    public init(reducer: R, initialState: R.State) {
        self.reducer = reducer
        self.state = initialState
    }
}

public extension Store {
    var publisher: AnyPublisher<R.State, Never> {
        self.$state
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func publisher<Value: Equatable>(for keyPath: KeyPath<R.State, Value>) -> AnyPublisher<Value, Never> {
        self.$state
            .map(keyPath)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func passthroughPublisher<Value>(for keyPath: KeyPath<R.State, Passthrough<Value>>) -> AnyPublisher<Value, Never> {
        self.$state
            .map(keyPath)
            .removeDuplicates { $0.version == $1.version }
            .map(\.wrappedValue)
            .eraseToAnyPublisher()
    }
}

extension Store {
    public func send(_ action: R.Action) {
        self._send(action)
        if !Thread.isMainThread {
            // TODO: Issue a non main thread runtime warning
        }
    }
    
    public func run(_ action: R.AsyncAction, priority: TaskPriority? = nil) {
        Task(priority: priority) {
            switch await self.reducer.run(action: action) {
            case .none:
                return
            case .send(let action):
                await MainActor.run {
                    self._send(action)
                }
            case .run(let action, let priority):
                self.run(action, priority: priority)
            }
        }
    }

    func _send(_ action: R.Action) {
        switch self.reducer.reduce(into: &self.state, action: action) {
        case .none:
            return
        case .send(let action):
            self._send(action)
        case .run(let action, let priority):
            self.run(action, priority: priority)
        }
    }
}
