// MARK: - ViewModel Template
// Use this template for creating new ViewModels in your project

import Foundation
import Combine

// MARK: - Protocol
protocol __NAME__ViewModelProtocol: ObservableObject {
    var isLoading: Bool { get }
    var error: Error? { get }
    func load() async
}

// MARK: - ViewModel
@MainActor
final class __NAME__ViewModel: __NAME__ViewModelProtocol {
    // MARK: - Published Properties
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error? = nil
    @Published private(set) var data: __TYPE__? = nil
    
    // MARK: - Dependencies
    private let service: __NAME__ServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(service: __NAME__ServiceProtocol = __NAME__Service()) {
        self.service = service
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Add Combine bindings here
    }
    
    // MARK: - Public Methods
    func load() async {
        isLoading = true
        error = nil
        
        do {
            data = try await service.fetch()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await load()
    }
}

// MARK: - Preview Helper
#if DEBUG
extension __NAME__ViewModel {
    static var preview: __NAME__ViewModel {
        __NAME__ViewModel(service: Mock__NAME__Service())
    }
}

final class Mock__NAME__Service: __NAME__ServiceProtocol {
    func fetch() async throws -> __TYPE__ {
        // Return mock data
        fatalError("Implement mock data")
    }
}
#endif
