import Foundation
import Observation

@MainActor
@Observable
final class DownloadProgress {
    var value: Double = 0.0
}
