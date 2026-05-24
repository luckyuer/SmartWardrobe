import SwiftUI
import CoreData
import PhotosUI

struct AddItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var itemName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var showCamera = false
    @State private var selectedTags: Set<Tag> = []
    @State private var showTagPicker = false
    @State private var step: AddStep = .selectPhoto

    private enum AddStep: Int, CaseIterable {
        case selectPhoto = 0
        case reviewImage = 1
        case fillDetails = 2
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step.rawValue + 1), total: 3.0)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Group {
                    switch step {
                    case .selectPhoto:
                        selectPhotoStep
                    case .reviewImage:
                        reviewImageStep
                    case .fillDetails:
                        fillDetailsStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("添加衣物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step != .selectPhoto {
                        Button("返回") { moveBack() }
                    } else {
                        Button("取消") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if step == .fillDetails {
                        Button("保存") { saveItem() }
                            .disabled(itemName.isEmpty)
                    } else if step == .reviewImage {
                        Button("下一步") { step = .fillDetails }
                            .disabled(processedImage == nil)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { image in
                    sourceImage = image
                    processImage(image)
                }
            }
            .sheet(isPresented: $showTagPicker) {
                TagPickerView(selectedTags: $selectedTags)
            }
        }
    }

    private var selectPhotoStep: some View {
        VStack(spacing: 24) {
            Spacer()

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Button {
                showCamera = true
            } label: {
                Label("拍照", systemImage: "camera")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Spacer()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    sourceImage = image
                    processImage(image)
                }
            }
        }
    }

    private var reviewImageStep: some View {
        VStack(spacing: 16) {
            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在处理图片...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else if let processed = processedImage {
                Image(uiImage: processed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }

            if processedImage != nil {
                Button("重新选择") {
                    step = .selectPhoto
                    processedImage = nil
                    sourceImage = nil
                }
                .padding(.bottom)
            }
        }
    }

    private var fillDetailsStep: some View {
        Form {
            Section("基本信息") {
                TextField("物品名称", text: $itemName)

                if let image = processedImage {
                    HStack {
                        Spacer()
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                }
            }

            Section("标签") {
                Button {
                    showTagPicker = true
                } label: {
                    HStack {
                        Text("选择标签")
                        Spacer()
                        if selectedTags.isEmpty {
                            Text("未选择")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(selectedTags.count) 个标签")
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }

                if !selectedTags.isEmpty {
                    WrappingHStack(tags: Array(selectedTags)) { tag in
                        Text(tag.name ?? "")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: tag.color ?? "#95A5A6").opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func processImage(_ image: UIImage) {
        step = .reviewImage
        isProcessing = true

        Task {
            let service = ImageProcessingService()
            do {
                let result = try await service.removeBackground(from: image)
                await MainActor.run {
                    processedImage = result
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    processedImage = image
                    isProcessing = false
                }
            }
        }
    }

    private func moveBack() {
        guard let prev = AddStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    private func saveItem() {
        withAnimation {
            let item = WardrobeItem(context: viewContext)
            item.id = UUID()
            item.name = itemName
            item.createdAt = Date()
            item.updatedAt = Date()
            item.sortOrder = 0

            if let image = processedImage ?? sourceImage {
                Task {
                    let storage = ImageStorageService()
                    do {
                        let photoFilename = try await storage.saveImage(image, withID: item.id!)
                        let thumbFilename = try await storage.saveThumbnail(image, withID: item.id!)
                        item.photoURL = photoFilename
                        item.thumbnailURL = thumbFilename
                        try viewContext.save()
                    } catch {
                        print("Save failed: \(error)")
                    }
                }
            }

            for tag in selectedTags {
                item.addToTags(tag)
            }

            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Save failed: \(error)")
            }
        }
    }
}

struct WrappingHStack: Layout {
    let tags: [Tag]
    let content: (Tag) -> AnyView

    init(tags: [Tag], @ViewBuilder content: @escaping (Tag) -> some View) {
        self.tags = tags
        self.content = { tag in AnyView(content(tag)) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var result = LayoutResult()
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + 4
                rowHeight = 0
            }
            result.positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + 4
            rowHeight = max(rowHeight, size.height)
        }

        result.size = CGSize(width: maxWidth, height: currentY + rowHeight)
        return result
    }
}
