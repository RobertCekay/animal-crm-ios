//
//  AddLeadView.swift
//  Animal CRM
//
//  Quick form to capture a new lead in the field
//

import SwiftUI

struct AddLeadView: View {
    @StateObject private var apiService = APIService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Info")) {
                    TextField("Name *", text: $name)
                        .textContentType(.name)
                    
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text("Location")) {
                    TextField("Address", text: $address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                        .lineLimit(3)
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLead()
                    }
                    .disabled(name.isEmpty || isSubmitting)
                }
            }
        }
    }
    
    private func saveLead() {
        guard !name.isEmpty else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await apiService.createLead(
                    name: name,
                    phone: phone.isEmpty ? nil : phone,
                    email: email.isEmpty ? nil : email,
                    address: address.isEmpty ? nil : address,
                    notes: notes.isEmpty ? nil : notes
                )
                
                print("✅ Lead created successfully")
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Error creating lead: \(error)")
            }
            
            isSubmitting = false
        }
    }
}

#Preview {
    AddLeadView()
}
