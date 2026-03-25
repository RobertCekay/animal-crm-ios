//
//  JobPhotosView.swift
//  Animal CRM
//
//  Photo gallery for a job — thumbnail strip, camera capture, full-screen viewer, delete.
//

import SwiftUI

struct JobPhotosView: View {
    let jobId: Int

    @State private var photos: [JobPhoto] = []
    @State private var isLoading = false
    @State private var showingCamera = false
    @State private var selectedPhoto: JobPhoto?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos").font(.headline)
                Spacer()
                Button {
                    showingCamera = true
                } label: {
                    Label("Add", systemImage: "camera.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if isLoading && photos.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if photos.isEmpty {
                Label("No photos yet", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            AsyncImage(url: URL(string: photo.thumbnailUrl)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    Color(.systemGray5)
                                }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture { selectedPhoto = photo }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await deletePhoto(photo) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if let err = errorMessage {
                Text(err).font(.caption).foregroundColor(.red)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showingCamera) {
            ImagePickerView(sourceType: .camera) { image in
                Task { await upload(image) }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoFullScreenView(photo: photo) {
                Task { await deletePhoto(photo) }
            }
        }
    }

    private func load() async {
        isLoading = true
        photos = (try? await APIService.shared.fetchJobPhotos(jobId: jobId)) ?? []
        isLoading = false
    }

    private func upload(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        do {
            let photo = try await APIService.shared.uploadJobPhoto(jobId: jobId, imageData: data)
            photos.append(photo)
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
        }
    }

    private func deletePhoto(_ photo: JobPhoto) async {
        try? await APIService.shared.deleteJobPhoto(jobId: jobId, photoId: photo.id)
        photos.removeAll { $0.id == photo.id }
        if selectedPhoto?.id == photo.id { selectedPhoto = nil }
    }
}

// MARK: - Full Screen Viewer

private struct PhotoFullScreenView: View {
    let photo: JobPhoto
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            AsyncImage(url: URL(string: photo.url)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit().ignoresSafeArea()
                default:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}
