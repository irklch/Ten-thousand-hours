import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case home
    case history

    var title: LocalizedStringKey {
        switch self {
        case .home: "Главная"
        case .history: "История"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "stopwatch"
        case .history: "list.bullet"
        }
    }
}
