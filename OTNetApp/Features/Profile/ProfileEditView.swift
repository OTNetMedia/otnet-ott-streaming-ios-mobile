import SwiftUI

struct ProfileEditView: View {
    enum Mode {
        case create
        case edit(index: Int, profile: ViewerProfile)
    }

    let mode: Mode
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var avatar: String = ""
    @State private var kids: Bool = false
    @State private var saving = false
    @State private var deleteConfirm = false
    @State private var localError: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editIndex: Int? {
        if case .edit(let i, _) = mode { return i }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    TextField("Avatar URL (optional)", text: $avatar)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Toggle("Kids profile", isOn: $kids)
                }

                if let err = localError ?? auth.lastError {
                    Section {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                if isEditing, let idx = editIndex, auth.profiles.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            deleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete this profile")
                            }
                        }
                        .confirmationDialog(
                            "Delete \(auth.profiles[safe: idx]?.displayName ?? "profile")?",
                            isPresented: $deleteConfirm,
                            titleVisibility: .visible
                        ) {
                            Button("Delete", role: .destructive) {
                                Task { await delete(index: idx) }
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OTNetTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit profile" : "New profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Save" : "Create") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                        .bold()
                }
            }
        }
        .onAppear { hydrateFromMode() }
    }

    private func hydrateFromMode() {
        if case .edit(_, let profile) = mode {
            name = profile.name ?? ""
            avatar = profile.avatar ?? ""
            kids = profile.kids ?? false
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedAvatar = avatar.trimmingCharacters(in: .whitespaces)
        saving = true
        localError = nil
        defer { saving = false }
        let ok: Bool
        switch mode {
        case .create:
            ok = await auth.createProfile(
                name: trimmedName,
                avatar: trimmedAvatar.isEmpty ? nil : trimmedAvatar,
                kids: kids
            )
        case .edit(let idx, _):
            ok = await auth.updateProfile(
                index: idx,
                name: trimmedName,
                avatar: trimmedAvatar.isEmpty ? nil : trimmedAvatar,
                kids: kids
            )
        }
        if ok {
            await auth.refreshProfiles()
            dismiss()
        }
    }

    private func delete(index: Int) async {
        saving = true
        defer { saving = false }
        if await auth.deleteProfile(index: index) {
            dismiss()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
