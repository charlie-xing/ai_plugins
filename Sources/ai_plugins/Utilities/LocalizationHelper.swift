import Foundation

/// Localization helper for Swift Package Manager projects
/// SPM packages have their resources in a module-specific bundle, not the main bundle
struct LocalizationHelper {
    /// The bundle containing localized resources for this module
    private static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle.main
        #endif
    }()

    /// Get localized string from the correct bundle
    static func localizedString(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
}
