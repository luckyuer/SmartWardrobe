import SwiftUI
import CoreData

struct AddOutfitView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var outfitName = ""
    @State private var outfitNote = ""
    @State private var outfitDate = Date()
    @State private var showItemPicker = false
    @State private var selectedItems: [WardrobeItem] = []

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.createdAt, order: .reverse)],
        animation: .default
    )
    private var allItems: FetchedResults<WardrobeItem>

    var body: some View {
        NavigationStack {
            Form {
                Section("搭配信息") {
                    TextField("搭配名称（可选）", text: $outfitName)
                    TextField("备注（可选）", text: $outfitNote, axis: .vertical)
                        .lineLimit(2...4)
                    DatePicker("日期", selection: $outfitDate, displayedComponents: .date)
                }

                Section("选择单品") {
                    Button {
                        showItemPicker = true
                    } label: {
                        HStack {
                            Text("从衣橱中选择")
                            Spacer()
                            Text("\(selectedItems.count) 件")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !selectedItems.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(selectedItems) { item in
                                selectedItemImage(item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("新建搭配")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { saveOutfit() }
                        .disabled(selectedItems.isEmpty)
                }
            }
            .sheet(isPresented: $showItemPicker) {
                ItemPickerSheet(allItems: Array(allItems), selectedItems: $selectedItems)
            }
        }
    }

    private func selectedItemImage(_ item: WardrobeItem) -> some View {
        VStack(spacing: 2) {
            ItemMiniThumbnail(item: item)
            Text(item.name ?? "")
                .font(.caption2)
                .lineLimit(1)

            Button {
                selectedItems.removeAll { $0 == item }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func saveOutfit() {
        let outfit = Outfit(context: viewContext)
        outfit.id = UUID()
        outfit.name = outfitName.isEmpty ? nil : outfitName
        outfit.note = outfitNote.isEmpty ? nil : outfitNote
        outfit.date = outfitDate
        outfit.createdAt = Date()

        for (index, item) in selectedItems.enumerated() {
            let outfitItem = OutfitItem(context: viewContext)
            outfitItem.id = UUID()
            outfitItem.sortOrder = Int16(index)
            outfitItem.item = item
            outfitItem.outfit = outfit
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Save outfit failed: \(error)")
        }
    }
}

struct ItemPickerSheet: View {
    let allItems: [WardrobeItem]
    @Binding var selectedItems: [WardrobeItem]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredItems: [WardrobeItem] {
        if searchText.isEmpty { return allItems }
        return allItems.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                Button {
                    if let index = selectedItems.firstIndex(where: { $0 == item }) {
                        selectedItems.remove(at: index)
                    } else {
                        selectedItems.append(item)
                    }
                } label: {
                    HStack {
                        ItemMiniThumbnail(item: item)
                        Text(item.name ?? "未命名")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedItems.contains(where: { $0 == item }) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索衣物")
            .navigationTitle("选择单品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
