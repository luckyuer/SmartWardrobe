import Foundation

enum TagCategory: String, CaseIterable, Identifiable {
    case category = "品类"
    case color = "颜色"
    case season = "季节"
    case occasion = "场合"
    case custom = "自定义"

    var id: String { rawValue }

    var systemIcon: String {
        switch self {
        case .category: return "shirt"
        case .color: return "paintpalette"
        case .season: return "thermometer.medium"
        case .occasion: return "briefcase"
        case .custom: return "star"
        }
    }
}

struct PresetTag: Identifiable {
    let id = UUID()
    let name: String
    let category: TagCategory
    let color: String

    static let all: [PresetTag] = {
        var tags: [PresetTag] = []

        let categories: [(String, TagCategory, String)] = [
            ("上装", .category, "#4A90D9"),
            ("下装", .category, "#4A90D9"),
            ("外套", .category, "#4A90D9"),
            ("连衣裙", .category, "#4A90D9"),
            ("鞋", .category, "#4A90D9"),
            ("包", .category, "#4A90D9"),
            ("配饰", .category, "#4A90D9"),
            ("内衣", .category, "#4A90D9"),

            ("红", .color, "#E74C3C"),
            ("橙", .color, "#E67E22"),
            ("黄", .color, "#F1C40F"),
            ("绿", .color, "#2ECC71"),
            ("青", .color, "#1ABC9C"),
            ("蓝", .color, "#3498DB"),
            ("紫", .color, "#9B59B6"),
            ("黑", .color, "#2C3E50"),
            ("白", .color, "#ECF0F1"),
            ("灰", .color, "#95A5A6"),
            ("棕", .color, "#8B6914"),
            ("粉", .color, "#FF69B4"),

            ("春", .season, "#A8D5BA"),
            ("夏", .season, "#F9E79F"),
            ("秋", .season, "#E59866"),
            ("冬", .season, "#AED6F1"),
            ("四季通用", .season, "#D5DBDB"),

            ("日常", .occasion, "#85C1E9"),
            ("通勤", .occasion, "#5DADE2"),
            ("运动", .occasion, "#58D68D"),
            ("约会", .occasion, "#F1948A"),
            ("正式", .occasion, "#5D6D7E"),
            ("休闲", .occasion, "#82E0AA"),
        ]

        for (name, category, color) in categories {
            tags.append(PresetTag(name: name, category: category, color: color))
        }

        return tags
    }()
}
