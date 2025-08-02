import Foundation
import UIKit

// MARK: - String Extensions
public extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }
    
    var isValidPhoneNumber: Bool {
        let phoneRegex = "^[0-9]{10,15}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: self)
    }
    
    var isAlphanumeric: Bool {
        let alphanumericRegex = "^[a-zA-Z0-9]+$"
        let alphanumericPredicate = NSPredicate(format: "SELF MATCHES %@", alphanumericRegex)
        return alphanumericPredicate.evaluate(with: self)
    }
    
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var capitalizedFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
    
    func truncate(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }
    
    func containsOnly(_ characterSet: CharacterSet) -> Bool {
        return self.rangeOfCharacter(from: characterSet.inverted) == nil
    }
    
    func removeSpecialCharacters() -> String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}

// MARK: - Date Extensions
public extension Date {
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    func adding(years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func formattedString(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

// MARK: - UIColor Extensions
public extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
    
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        
        return String(format: "#%06x", rgb)
    }
    
    var isLight: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return brightness > 0.5
    }
}

// MARK: - UIView Extensions
public extension UIView {
    func addShadow(
        color: UIColor = .black,
        opacity: Float = 0.1,
        offset: CGSize = CGSize(width: 0, height: 2),
        radius: CGFloat = 4
    ) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
    
    func addBorder(
        color: UIColor = .black,
        width: CGFloat = 1
    ) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
    }
    
    func roundCorners(_ radius: CGFloat) {
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
    
    func makeCircular() {
        layer.cornerRadius = min(frame.width, frame.height) / 2
        layer.masksToBounds = true
    }
    
    func fadeIn(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        alpha = 0
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 1
        }, completion: { _ in
            completion?()
        })
    }
    
    func fadeOut(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0
        }, completion: { _ in
            completion?()
        })
    }
    
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
        layer.add(animation, forKey: "shake")
    }
}

// MARK: - UIImage Extensions
public extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func withRoundedCorners(_ radius: CGFloat) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        path.addClip()
        
        draw(in: rect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func withTintColor(_ color: UIColor) -> UIImage? {
        return withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                  y: inputImage.extent.origin.y,
                                  z: inputImage.extent.size.width,
                                  w: inputImage.extent.size.height)
        
        guard let filter = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: inputImage,
                                             kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)
        
        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
}

// MARK: - Array Extensions
public extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
    
    func safeIndex(_ index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            if seen.contains(key) {
                return false
            } else {
                seen.insert(key)
                return true
            }
        }
    }
}

// MARK: - Dictionary Extensions
public extension Dictionary {
    func merge(_ other: [Key: Value]) -> [Key: Value] {
        var result = self
        for (key, value) in other {
            result[key] = value
        }
        return result
    }
    
    mutating func merge(_ other: [Key: Value]) {
        for (key, value) in other {
            self[key] = value
        }
    }
}

// MARK: - Optional Extensions
public extension Optional {
    func or(_ defaultValue: Wrapped) -> Wrapped {
        return self ?? defaultValue
    }
    
    func orElse(_ defaultValue: () -> Wrapped) -> Wrapped {
        return self ?? defaultValue()
    }
    
    var isNil: Bool {
        return self == nil
    }
    
    var isNotNil: Bool {
        return self != nil
    }
}

// MARK: - Bundle Extensions
public extension Bundle {
    var appName: String {
        return object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown"
    }
    
    var appVersion: String {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    var fullVersion: String {
        return "\(appVersion) (\(buildNumber))"
    }
}

// MARK: - Device Extensions
public extension UIDevice {
    var isIPad: Bool {
        return userInterfaceIdiom == .pad
    }
    
    var isIPhone: Bool {
        return userInterfaceIdiom == .phone
    }
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
    }
} 