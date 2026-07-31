import Foundation

// Shared enum for date selection used across multiple views
enum DateSelectionTarget: Identifiable {
    case start
    case end

    var id: String {
        switch self {
        case .start: return "start"
        case .end: return "end"
        }
    }
}
