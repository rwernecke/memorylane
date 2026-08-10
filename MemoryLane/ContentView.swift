//
//  ContentView.swift
//  MemoryLane
//
//  Created by Rafael on 8/9/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Memory.capturedAt, order: .reverse) private var memories: [Memory]
    @State private var isShowingComposer = false

    var body: some View {
        NavigationStack {
            ZStack {
                MemoryLaneBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HeaderView(memoryCount: memories.count)
                        TodayPromptCard(addAction: showComposer)

                        if memories.isEmpty {
                            EmptyMemoryState(addAction: showComposer)
                        } else {
                            MemoryTimeline(memories: memories)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("MemoryLane")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: showComposer) {
                        Label("Add Memory", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingComposer) {
                AddMemoryView()
            }
        }
    }

    private func showComposer() {
        isShowingComposer = true
    }
}

private struct HeaderView: View {
    let memoryCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your lane")
                .font(.largeTitle.weight(.bold))

            HStack(spacing: 12) {
                Label(memoryCountText, systemImage: "photo.stack")
                Label("Private on device", systemImage: "lock.fill")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryCountText: String {
        memoryCount == 1 ? "1 memory" : "\(memoryCount) memories"
    }
}

private struct TodayPromptCard: View {
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.memoryAccent)
                    .frame(width: 34, height: 34)
                    .background(Color.memoryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Capture today")
                        .font(.headline)

                    Text("Turn one ordinary moment into a future favorite.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: addAction) {
                Label("New memory", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.memoryAccent)
        }
        .padding(16)
        .memoryCardStyle()
    }
}

private struct EmptyMemoryState: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.memoryAccent)

            VStack(spacing: 6) {
                Text("Your first memory starts here")
                    .font(.headline)

                Text("Write a short note, add a mood, and give the moment a few tags.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: addAction) {
                Label("Add memory", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .tint(Color.memoryAccent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .memoryCardStyle()
    }
}

private struct MemoryTimeline: View {
    let memories: [Memory]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.title2.weight(.bold))

            LazyVStack(spacing: 12) {
                ForEach(memories) { memory in
                    NavigationLink {
                        MemoryDetailView(memory: memory)
                    } label: {
                        MemoryCard(memory: memory)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MemoryCard: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: memory.mood.symbolName)
                    .font(.headline)
                    .foregroundStyle(memory.mood.tint)
                    .frame(width: 34, height: 34)
                    .background(memory.mood.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(memory.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(memory.capturedAt, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Text(memory.story)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if memory.hasLocation || !memory.tags.isEmpty {
                HStack(spacing: 8) {
                    if memory.hasLocation {
                        Label(memory.locationName, systemImage: "mappin.and.ellipse")
                            .lineLimit(1)
                    }

                    ForEach(memory.tags.prefix(2), id: \.self) { tag in
                        Text("#\(tag)")
                            .lineLimit(1)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .memoryCardStyle()
    }
}

private struct MemoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let memory: Memory
    @State private var isConfirmingDelete = false

    var body: some View {
        ZStack {
            MemoryLaneBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(memory.mood.displayName, systemImage: memory.mood.symbolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(memory.mood.tint)

                        Text(memory.title)
                            .font(.largeTitle.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(memory.capturedAt, format: .dateTime.weekday(.wide).month(.wide).day().year())
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(memory.story)
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .memoryCardStyle()

                    if memory.hasLocation {
                        DetailRow(title: "Place", value: memory.locationName, systemImage: "mappin.and.ellipse")
                    }

                    if !memory.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Tags", systemImage: "tag.fill")
                                .font(.headline)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(memory.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.memoryAccent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.memoryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                        .padding(16)
                        .memoryCardStyle()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Memory")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this memory?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Memory", role: .destructive, action: deleteMemory)
            Button("Cancel", role: .cancel) { }
        }
    }

    private func deleteMemory() {
        modelContext.delete(memory)
        try? modelContext.save()
        dismiss()
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.memoryAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .memoryCardStyle()
    }
}

private struct AddMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var story = ""
    @State private var capturedAt = Date()
    @State private var locationName = ""
    @State private var selectedMood = MemoryMood.warm
    @State private var tagsInput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Memory") {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $capturedAt, displayedComponents: .date)

                    TextEditor(text: $story)
                        .frame(minHeight: 140)
                }

                Section("Context") {
                    TextField("Place", text: $locationName)

                    Picker("Mood", selection: $selectedMood) {
                        ForEach(MemoryMood.allCases) { mood in
                            Label(mood.displayName, systemImage: mood.symbolName)
                                .tag(mood)
                        }
                    }

                    TextField("Tags", text: $tagsInput, prompt: Text("family, summer, firsts"))
                        .memoryTagFieldStyle()
                }
            }
            .navigationTitle("New Memory")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveMemory)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !story.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveMemory() {
        let memory = Memory(
            title: title,
            story: story,
            capturedAt: capturedAt,
            locationName: locationName,
            mood: selectedMood,
            tags: Memory.normalizedTags(from: tagsInput)
        )
        modelContext.insert(memory)
        try? modelContext.save()
        dismiss()
    }
}

private struct MemoryLaneBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.96, blue: 0.91),
                Color(red: 0.91, green: 0.95, blue: 0.94),
                Color(red: 0.89, green: 0.91, blue: 0.97)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct MemoryCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.memoryCardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

private extension View {
    func memoryCardStyle() -> some View {
        modifier(MemoryCardModifier())
    }

    @ViewBuilder
    func memoryTagFieldStyle() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never)
#else
        self
#endif
    }
}

private extension MemoryMood {
    var tint: Color {
        switch self {
        case .warm:
            return Color(red: 0.78, green: 0.32, blue: 0.18)
        case .joyful:
            return Color(red: 0.82, green: 0.55, blue: 0.05)
        case .grateful:
            return Color(red: 0.66, green: 0.22, blue: 0.34)
        case .bittersweet:
            return Color(red: 0.39, green: 0.42, blue: 0.65)
        case .quiet:
            return Color(red: 0.23, green: 0.49, blue: 0.39)
        }
    }
}

private extension Color {
    static var memoryAccent: Color {
        Color(red: 0.20, green: 0.45, blue: 0.42)
    }

    static var memoryCardBackground: Color {
#if os(iOS)
        return Color(uiColor: .secondarySystemGroupedBackground)
#elseif os(macOS)
        return Color(nsColor: .controlBackgroundColor)
#else
        return Color.white.opacity(0.86)
#endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Memory.self, inMemory: true)
}
