import SwiftUI
import CoreData

struct TagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTags: Set<Tag>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.category), SortDescriptor(\.name)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>

    @State private var searchText = ""
    @State private var showAddTag = false
    @State private var newTagName = ""
    @State private var newTagCategory: TagCategory = .custom
    @State private var newTagColor = "#95A5A6"

    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return Array(allTags)
        }
        return allTags.filter { tag in
            (tag.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedTags: [(TagCategory, [Tag])] {
        let groups = Dictionary(grouping: filteredTags) { tag in
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
                            tagRow(tag)
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.systemIcon)
                    }
                }

                Section {
                    Button {
                        showAddTag = true
                    } label: {
                        Label("添加自定义标签", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索标签")
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("新建标签", isPresented: $showAddTag) {
                TextField("标签名称", text: $newTagName)
                Button("取消", role: .cancel) {
                    newTagName = ""
                }
                Button("添加") {
                    createTag()
                }
                .disabled(newTagName.isEmpty)
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        Button {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            HStack {
                Circle()
                    .fill(Color(hex: tag.color ?? "#95A5A6"))
                    .frame(width: 12, height: 12)

                Text(tag.name ?? "")
                    .foregroundStyle(.primary)

                Spacer()

                if selectedTags.contains(tag) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func createTag() {
        guard let context = allTags.first?.managedObjectContext else { return }
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = newTagName
        tag.category = newTagCategory.rawValue
        tag.color = newTagColor
        tag.isCustom = true
        try? context.save()
        newTagName = ""
    }
}
