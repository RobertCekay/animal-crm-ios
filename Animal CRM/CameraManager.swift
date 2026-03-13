//
//  CameraManager.swift
//  Animal CRM
//
//  Manages camera and photo library access with image upload
//

import SwiftUI
import UIKit
import PhotosUI
import Combine

@MainActor
class CameraManager: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var isUploading = false
    @Published var uploadError: String?
    @Published var showImageSourcePicker = false
    
    // MARK: - Image Upload
    
    func uploadImage(_ image: UIImage, to baseURL: URL) async {
        isUploading = true
        uploadError = nil
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            uploadError = "Failed to convert image to data"
            isUploading = false
            return
        }
        
        // Create upload URL
        guard let uploadURL = URL(string: APIConfig.uploadURL) else {
            uploadError = "Invalid upload URL"
            isUploading = false
            return
        }
        
        // Create multipart form data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add additional metadata if needed
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"\r\n\r\n".data(using: .utf8)!)
        body.append("ios_app\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✅ Image uploaded successfully")
                    
                    // Parse response
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("Upload response: \(json)")
                        
                        // Notify WebView about successful upload
                        if let imageURL = json["url"] as? String {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("ImageUploaded"),
                                object: nil,
                                userInfo: ["imageURL": imageURL]
                            )
                        }
                    }
                } else {
                    uploadError = "Upload failed with status code: \(httpResponse.statusCode)"
                    print("❌ Upload failed: \(httpResponse.statusCode)")
                }
            }
        } catch {
            uploadError = error.localizedDescription
            print("❌ Upload error: \(error.localizedDescription)")
        }
        
        isUploading = false
    }
}

// MARK: - ImagePickerView

struct ImagePickerView: UIViewControllerRepresentable {
    enum SourceType {
        case camera
        case photoLibrary
        
        var imagePickerSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return .camera
            case .photoLibrary:
                return .photoLibrary
            }
        }
    }
    
    let sourceType: SourceType
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType.imagePickerSourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - PHPickerView (Modern Alternative)

@available(iOS 14.0, *)
struct PHPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHPickerView
        
        init(_ parent: PHPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let result = results.first else { return }
            
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.onImagePicked(image)
                    }
                }
            }
        }
    }
}
