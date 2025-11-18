//
//  Debouncer.swift
//  Cashooya Playground
//
//  Created by Claude on Performance Optimization
//

import Foundation

/// Utility for debouncing rapid function calls
/// Particularly useful for search text fields to avoid excessive filtering operations
class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    /// Initialize debouncer with specified delay
    /// - Parameters:
    ///   - delay: Time to wait before executing the debounced action
    ///   - queue: Queue to execute the action on (defaults to main queue)
    init(delay: TimeInterval = 0.3, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// Debounce a closure - cancels previous calls and schedules new one
    /// - Parameter action: Closure to execute after the delay
    func debounce(_ action: @escaping () -> Void) {
        // Cancel previous work item
        workItem?.cancel()
        
        // Create new work item
        let newWorkItem = DispatchWorkItem(block: action)
        self.workItem = newWorkItem
        
        // Schedule execution after delay
        queue.asyncAfter(deadline: .now() + delay, execute: newWorkItem)
    }
    
    /// Cancel any pending debounced action
    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
    
    /// Execute any pending action immediately and cancel debouncing
    func executeImmediately() {
        workItem?.perform()
        workItem = nil
    }
    
    deinit {
        cancel()
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// SwiftUI view modifier for debounced text changes
struct DebouncedTextModifier: ViewModifier {
    let delay: TimeInterval
    let onTextChange: (String) -> Void
    
    @State private var debouncer: Debouncer
    
    init(delay: TimeInterval = 0.3, onTextChange: @escaping (String) -> Void) {
        self.delay = delay
        self.onTextChange = onTextChange
        self._debouncer = State(initialValue: Debouncer(delay: delay))
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: getText(from: content)) { oldValue, newValue in
                debouncer.debounce {
                    onTextChange(newValue)
                }
            }
    }
    
    // Helper to extract text from content (simplified for TextField)
    private func getText(from content: Content) -> String {
        // This would need proper implementation based on the specific text field
        // For now, we'll handle this in the calling view
        return ""
    }
}

extension View {
    /// Add debounced text change handling to a view
    /// - Parameters:
    ///   - delay: Debounce delay in seconds
    ///   - action: Action to perform when text changes (after delay)
    func onDebouncedTextChange(delay: TimeInterval = 0.3, perform action: @escaping (String) -> Void) -> some View {
        modifier(DebouncedTextModifier(delay: delay, onTextChange: action))
    }
}