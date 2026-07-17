//
//  Array+Chunked.swift
//  CashMonki
//
//  Splits an array into fixed-size chunks (e.g. for paged grid layouts).
//

import Foundation

extension Array {
    /// Splits the array into consecutive subarrays of at most `size` elements.
    /// The final chunk may contain fewer than `size` elements.
    /// - Parameter size: Maximum number of elements per chunk (must be > 0).
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
