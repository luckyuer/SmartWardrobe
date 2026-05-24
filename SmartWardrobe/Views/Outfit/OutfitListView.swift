import SwiftUI
import CoreData

struct OutfitListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var outfits: FetchedResults<Outfit>

    @State private var showAddOutfit = false

    var body: some View {
        NavigationStack {
            Group {
                if outfits.isEmpty {
                    ContentUnavailableView {
                        Label("还没有搭配", systemImage: "person.bust")
                    } description: {
                        Text("创建你的第一个穿搭方案")
                    } actions: {
                        Button("创建搭配") {
                            showAddOutfit = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(outfits) { outfit in
                            NavigationLink(destination: OutfitDetailView(outfit: outfit)) {
                                OutfitListRow(outfit: outfit)
                            }
                        }
                        .onDelete(perform: deleteOutfits)
                    }
                }
            }
            .navigationTitle("搭配")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddOutfit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddOutfit) {
                AddOutfitView()
            }
        }
    }

    private func deleteOutfits(offsets: IndexSet) {
        withAnimation {
            offsets.map { outfits[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

struct OutfitListRow: View {
    let outfit: Outfit

    var body: some View {
        HStack(spacing: 8) {
            if let items = outfit.outfitItems as? Set<OutfitItem> {
                let sorted = items.sorted { $0.sortOrder < $1.sortOrder }
                HStack(spacing: -16) {
                    ForEach(sorted.prefix(4)) { outfitItem in
                        if let item = outfitItem.item {
                            ItemMiniThumbnail(item: item)
                        }
                    }
                }
                .padding(.leading, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.name ?? "未命名搭配")
                    .font(.body)
                if let note = outfit.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 8)

            Spacer()

            if let date = outfit.date {
                Text(date, format: .dateTime.month().day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ItemMiniThumbnail: View {
    let item: WardrobeItem
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
        .task {
            guard let filename = item.thumbnailURL ?? item.photoURL else { return }
            let storage = ImageStorageService()
            thumbnail = await storage.loadThumbnail(filename: filename)
        }
    }
}

struct OutfitDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let outfit: Outfit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(outfit.name ?? "未命名搭配")
                    .font(.title2.bold())

                if let note = outfit.note, !note.isEmpty {
                    Text(note)
                        .foregroundStyle(.secondary)
                }

                if let items = outfit.outfitItems as? Set<OutfitItem> {
                    let sorted = items.sorted { $0.sortOrder < $1.sortOrder }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(sorted) { outfitItem in
                            if let item = outfitItem.item {
                                OutfitItemCard(item: item)
                            }
                        }
                    }
                }

                if let date = outfit.date {
                    HStack {
                        Image(systemName: "calendar")
                        Text(date, format: .dateTime.year().month().day())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("搭配详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct OutfitItemCard: View {
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
                        .overlay { Image(systemName: "hanger").foregroundStyle(.secondary) }
                }
            }
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.name ?? "")
                .font(.caption2)
                .lineLimit(1)
        }
        .task {
            guard let filename = item.thumbnailURL ?? item.photoURL else { return }
            let storage = ImageStorageService()
            thumbnail = await storage.loadThumbnail(filename: filename) ?? await storage.loadImage(filename: filename)
        }
    }
}
