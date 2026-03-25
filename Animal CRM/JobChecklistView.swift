//
//  JobChecklistView.swift
//  Animal CRM
//
//  Checklist section embedded in JobDetailView.
//

import SwiftUI

struct JobChecklistView: View {
    let jobId: Int

    @State private var checklists: [JobChecklist] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Checklists").font(.headline)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if isLoading && checklists.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if checklists.isEmpty {
                Text("No checklists yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach($checklists) { $checklist in
                    ChecklistCard(
                        jobId: jobId,
                        checklist: $checklist,
                        onDelete: { id in
                            Task { await deleteChecklist(id: id) }
                        }
                    )
                }
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingAddSheet) {
            AddChecklistSheet(jobId: jobId) { newChecklist in
                checklists.append(newChecklist)
            }
        }
    }

    private func load() async {
        isLoading = true
        checklists = (try? await APIService.shared.fetchJobChecklists(jobId: jobId)) ?? []
        isLoading = false
    }

    private func deleteChecklist(id: Int) async {
        try? await APIService.shared.deleteJobChecklist(jobId: jobId, checklistId: id)
        checklists.removeAll { $0.id == id }
    }
}

// MARK: - Checklist Card

private struct ChecklistCard: View {
    let jobId: Int
    @Binding var checklist: JobChecklist
    let onDelete: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with template name + progress
            HStack {
                Text(checklist.templateName ?? "Checklist")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(checklist.completionPercentage)%")
                    .font(.caption)
                    .foregroundColor(checklist.allComplete ? .green : .secondary)
                Button(role: .destructive) {
                    onDelete(checklist.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(checklist.allComplete ? Color.green : Color.blue)
                        .frame(width: geo.size.width * CGFloat(checklist.completionPercentage) / 100, height: 6)
                }
            }
            .frame(height: 6)

            // Items
            ForEach(Array(checklist.items.enumerated()), id: \.offset) { idx, item in
                ChecklistItemRow(
                    item: item,
                    onToggle: { Task { await toggle(index: idx) } }
                )
                if idx < checklist.items.count - 1 { Divider() }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func toggle(index: Int) async {
        if let updated = try? await APIService.shared.toggleChecklistItem(
            jobId: jobId, checklistId: checklist.id, index: index
        ) {
            checklist = updated
        }
    }
}

// MARK: - Item Row

private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.completed ? .green : .secondary)
                    .font(.title3)
                Text(item.label)
                    .font(.subheadline)
                    .foregroundColor(item.completed ? .secondary : .primary)
                    .strikethrough(item.completed)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Checklist Sheet

struct AddChecklistSheet: View {
    let jobId: Int
    let onCreated: (JobChecklist) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var templates: [ChecklistTemplate] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading templates…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if templates.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checklist").font(.system(size: 40)).foregroundColor(.secondary)
                        Text("No checklist templates").foregroundColor(.secondary)
                        Text("Create templates in your web account settings.")
                            .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(templates) { template in
                        Button {
                            Task { await create(templateId: template.id) }
                        } label: {
                            HStack {
                                Text(template.name).foregroundColor(.primary)
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(isSaving)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
        }
        .task { await loadTemplates() }
    }

    private func loadTemplates() async {
        isLoading = true
        templates = (try? await APIService.shared.fetchChecklistTemplates()) ?? []
        isLoading = false
    }

    private func create(templateId: Int) async {
        isSaving = true
        do {
            let checklist = try await APIService.shared.createJobChecklist(jobId: jobId, templateId: templateId)
            onCreated(checklist)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
