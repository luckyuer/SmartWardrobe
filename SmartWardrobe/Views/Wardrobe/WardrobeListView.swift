import SwiftUI
import CoreData

struct WardrobeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showAddSheet = false
    @State private var displayMode: DisplayMode = .grid
    @State private var filterTags: Set<Tag> = []
    @State private var sortOption: SortOption = .createdAt

    private enum DisplayMode {
        case grid, list
    }

    private enum SortOption: String, CaseIterable {
        case createdAt = "添加时间"
        case name = "名称"
        case sortOrder = "自定义"
    }

    private var sortDescriptors: [SortDescriptor<WardrobeItem>] {
        switch sortOption {
        case .createdAt: return [SortDescriptor(\.createdAt, order: .reverse)]
        case .name: return [SortDescriptor(\.name)]
        case .sortOrder: return [SortDescriptor(\.sortOrder)]
        }
    }

    @FetchRequest private var items: FetchedResults<WardrobeItem>

    init() {
        _items = FetchRequest<WardrobeItem>(
            sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyStateView
                } else {
                    contentBasedOnDisplayMode
                }
            }
            .navigationTitle("衣橱")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            displayMode = .grid
                        } label: {
                            Label("网格视图", systemImage: "square.grid.2x2")
                        }
                        Button {
                            displayMode = .list
                        } label: {
                            Label("列表视图", systemImage: "list.bullet")
                        }
                    } label: {
                        Image(systemName: displayMode == .grid ? "square.grid.2x2" : "list.bullet")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemView()
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("衣橱为空", systemImage: "hanger")
        } description: {
            Text("点击右上角 + 添加第一件衣物")
        } actions: {
            Button("添加衣物") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var contentBasedOnDisplayMode: some View {
        if displayMode == .grid {
            gridView
        } else {
            listView
        }
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        WardrobeItemGridCell(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var listView: some View {
        List {
            ForEach(items) { item in
                NavigationLink(destination: ItemDetailView(item: item)) {
                    WardrobeItemListRow(item: item)
                }
            }
            .onDelete(perform: deleteItems)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach { item in
                if let photoURL = item.photoURL {
                    Task {
                        let storage = ImageStorageService()
                        await storage.deleteImage(filename: photoURL)
                        if let thumbURL = item.thumbnailURL {
                            await storage.deleteThumbnail(filename: thumbURL)
                        }
                    }
                }
                viewContext.delete(item)
            }
            do {
                try viewContext.save()
            } catch {
                print("Delete failed: \(error)")
            }
        }
    }
}

struct WardrobeItemGridCell: View {
    let item: WardrobeItem
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "hanger")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.name ?? "未命名")
                .font(.caption)
                .lineLimit(1)
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let filename = item.thumbnailURL ?? item.photoURL else { return }
        let storage = ImageStorageService()
        if let thumb = item.thumbnailURL {
            thumbnail = await storage.loadThumbnail(filename: thumb)
        }
        if thumbnail == nil {
            thumbnail = await storage.loadImage(filename: filename)
        }
    }
}

struct WardrobeItemListRow: View {
    let item: WardrobeItem
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "hanger")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? "未命名")
                    .font(.body)
                HStack {
                    ForEach(Array(item.tags ?? []).prefix(3)) { tag in
                        if let tag = tag as? Tag {
                            Text(tag.name ?? "")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: tag.color ?? "#95A5A6").opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()
        }
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        guard let filename = item.thumbnailURL ?? item.photoURL else { return }
        let storage = ImageStorageService()
        if let thumb = item.thumbnailURL {
            thumbnail = await storage.loadThumbnail(filename: thumb)
        }
        if thumbnail == nil {
            thumbnail = await storage.loadImage(filename: filename)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
