import SwiftUI
import CoreData

struct TagListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.category), SortDescriptor(\.name)],
        animation: .default
    )
    private var tags: FetchedResults<Tag>

    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .custom
    @State private var newTagColor = "#95A5A6"

    private var groupedTags: [(TagCategory, [Tag])] {
        let groups = Dictionary(grouping: Array(tags)) { tag in
            TagCategory(rawValue: tag.category ?? "") ?? .custom
        }
        return TagCategory.allCases.compactMap { category in
            guard let tags = groups[category], !tags.isEmpty else { return nil }
            return (category, tags)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedTags, id: \.0) { category, tags in
                    Section {
                        ForEach(tags) { tag in
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.color ?? "#95A5A6"))
                                    .frame(width: 12, height: 12)

                                Text(tag.name ?? "")

                                Spacer()

                                if let count = tag.items?.count, count > 0 {
                                    Text("\(count) 件")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if tag.isCustom {
                                    Button(role: .destructive) {
                                        deleteTag(tag)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.systemIcon)
                    }
                }
            }
            .navigationTitle("标签")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("新建标签", isPresented: $showAddTag) {
                TextField("标签名称", text: $newTagName)
                Button("取消", role: .cancel) { newTagName = "" }
                Button("添加") { createTag() }
                    .disabled(newTagName.isEmpty)
            }
            .onAppear {
                seedPresetTagsIfNeeded()
            }
        }
    }

    private func seedPresetTagsIfNeeded() {
        let existingCount = tags.count
        if existingCount > 0 { return }

        for preset in PresetTag.all {
            let tag = Tag(context: viewContext)
            tag.id = UUID()
            tag.name = preset.name
            tag.category = preset.category.rawValue
            tag.color = preset.color
            tag.isCustom = false
        }
        try? viewContext.save()
    }

    private func createTag() {
        let tag = Tag(context: viewContext)
        tag.id = UUID()
        tag.name = newTagName
        tag.category = newTagCategory.rawValue
        tag.color = newTagColor
        tag.isCustom = true
        try? viewContext.save()
        newTagName = ""
    }

    private func deleteTag(_ tag: Tag) {
        viewContext.delete(tag)
        try? viewContext.save()
    }
}
