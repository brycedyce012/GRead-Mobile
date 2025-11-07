import Foundation
extension String {
    func stripHTML() -> String {
        // Remove HTML tags
        var result = self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // Decode HTML entities
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&#8217;", with: "'")
        result = result.replacingOccurrences(of: "&#8220;", with: "\"")
        result = result.replacingOccurrences(of: "&#8221;", with: "\"")
        
        // Trim whitespace
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func toRelativeTime() -> String {
        // Try multiple date formats
        let formatters = [
            ISO8601DateFormatter(),
            createDateFormatter(format: "yyyy-MM-dd'T'HH:mm:ss"),
            createDateFormatter(format: "yyyy-MM-dd HH:mm:ss")
        ]
        
        var date: Date?
        for formatter in formatters {
            if let iso8601Formatter = formatter as? ISO8601DateFormatter {
                date = iso8601Formatter.date(from: self)
            } else if let dateFormatter = formatter as? DateFormatter {
                date = dateFormatter.date(from: self)
            }
            
            if date != nil {
                break
            }
        }
        
        guard let parsedDate = date else {
            return self
        }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.second, .minute, .hour, .day, .weekOfYear, .month, .year], from: parsedDate, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)y ago"
        } else if let month = components.month, month > 0 {
            return "\(month)mo ago"
        } else if let week = components.weekOfYear, week > 0 {
            return "\(week)w ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else if let second = components.second, second > 10 {
            return "\(second)s ago"
        }
        
        return "Just now"
    }
    
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
