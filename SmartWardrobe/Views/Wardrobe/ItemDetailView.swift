import SwiftUI
import CoreData

struct ItemDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let item: WardrobeItem
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var fullImage: UIImage?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                imageSection

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(item.name ?? "未命名")
                            .font(.title2.bold())
                        Spacer()
                        Button {
                            isEditing.toggle()
                            editedName = item.name ?? ""
                        } label: {
                            Image(systemName: isEditing ? "checkmark" : "pencil")
                        }
                    }

                    if isEditing {
                        TextField("物品名称", text: $editedName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                item.name = editedName
                                item.updatedAt = Date()
                                try? viewContext.save()
                                isEditing = false
                            }
                    }

                    if let tags = item.tags as? Set<Tag>, !tags.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 6) {
                            ForEach(tags.sorted(by: { $0.name ?? "" < $1.name ?? "" })) { tag in
                                Text(tag.name ?? "")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: tag.color ?? "#95A5A6").opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Label(item.createdAt ?? Date(), format: .dateTime.year().month().day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("物品详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("确定要删除这件衣物吗？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive) { deleteItem() }
            Button("取消", role: .cancel) {}
        }
        .task {
            await loadFullImage()
        }
    }

    private var imageSection: some View {
        Group {
            if let fullImage = fullImage {
                Image(uiImage: fullImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay {
                        ProgressView()
                    }
                    .frame(height: 300)
            }
        }
    }

    private func loadFullImage() async {
        guard let filename = item.photoURL else { return }
        let storage = ImageStorageService()
        let image = await storage.loadImage(filename: filename)
        await MainActor.run {
            fullImage = image
        }
    }

    private func deleteItem() {
        withAnimation {
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
            try? viewContext.save()
            dismiss()
        }
    }
}
