import Foundation
import SwiftUI

struct Constants {
    private init() {}

    // App Info
    static let appName = "图片压缩器"
    static let appVersion = "1.0.0"

    // Compression Defaults
    static let defaultQuality = 75
    static let minQuality = 1
    static let maxQuality = 100

    // File Size Limits
    static let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
    static let maxTotalFiles = 100

    // Supported Formats
    static let supportedExtensions = ["jpg", "jpeg", "png", "tiff", "tif", "bmp", "gif"]

    // Thumbnails
    static let thumbnailSize = 64
    static let thumbnailQuality: CGFloat = 0.8

    // Animation
    static let defaultAnimationDuration: Double = 0.25
}

// MARK: - Semantic Colors

/// Semantic colors that adapt to light/dark mode
enum AppColors {
    // Savings/success color
    static let savingsGreen = Color(red: 0.13, green: 0.77, blue: 0.37) // #22C55E

    // Card background
    static let cardBackground = Color.primary.opacity(0.05)

    // Secondary backgrounds
    static let secondaryBackground = Color(nsColor: .controlBackgroundColor)

    // Status colors
    static let warning = Color.orange
    static let error = Color.red
}
