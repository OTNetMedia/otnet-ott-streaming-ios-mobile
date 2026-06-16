import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settingsStore: SettingsStore

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @FocusState private var focused: Field?

    enum Mode { case signIn, signUp }
    enum Field: Hashable { case name, email, password }

    private var brand: String { settingsStore.settings?.brandName ?? "OTNet" }

    private var canSubmit: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passOK = password.count >= 6
        let nameOK = mode == .signIn || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        return emailOK && passOK && nameOK && !auth.isLoading
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                        .padding(.top, 60)
                    modeSwitch
                    formCard
                    Spacer(minLength: 12)
                    footer
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            OTNetTheme.background.ignoresSafeArea()
            RadialGradient(
                colors: [OTNetTheme.primary.opacity(0.25), .clear],
                center: .topLeading, startRadius: 20, endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2)
                    .foregroundStyle(OTNetTheme.primary)
                Text(brand)
                    .font(.title2.bold())
                    .foregroundStyle(OTNetTheme.textPrimary)
            }
            Text(mode == .signIn ? "Welcome back" : "Create your account")
                .font(.largeTitle.bold())
                .foregroundStyle(OTNetTheme.textPrimary)
            Text(mode == .signIn ? "Pick up where you left off." : "Start watching in seconds.")
                .font(.subheadline)
                .foregroundStyle(OTNetTheme.textSecondary)
        }
    }

    private var modeSwitch: some View {
        HStack(spacing: 0) {
            modeChip("Sign in", isOn: mode == .signIn) { setMode(.signIn) }
            modeChip("Sign up", isOn: mode == .signUp) { setMode(.signUp) }
        }
        .padding(4)
        .background(OTNetTheme.card, in: Capsule())
        .overlay(Capsule().strokeBorder(OTNetTheme.border, lineWidth: 1))
    }

    private func modeChip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? .white : OTNetTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn ? OTNetTheme.primary : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }

    @ViewBuilder
    private var formCard: some View {
        VStack(spacing: 14) {
            if mode == .signUp {
                inputField(
                    label: "Name",
                    text: $displayName,
                    placeholder: "Your name",
                    field: .name,
                    isSecure: false,
                    contentType: .name
                )
            }
            inputField(
                label: "Email",
                text: $email,
                placeholder: "you@example.com",
                field: .email,
                isSecure: false,
                contentType: .emailAddress,
                keyboard: .emailAddress,
                autocap: .never
            )
            inputField(
                label: "Password",
                text: $password,
                placeholder: mode == .signIn ? "Your password" : "At least 6 characters",
                field: .password,
                isSecure: true,
                contentType: mode == .signIn ? .password : .newPassword
            )

            if let err = auth.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            Button(action: submit) {
                HStack(spacing: 8) {
                    if auth.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text(mode == .signIn ? "Sign in" : "Create account")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? OTNetTheme.primary : OTNetTheme.primary.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .padding(.top, 4)
        }
        .padding(18)
        .background(OTNetTheme.card.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(OTNetTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func inputField(
        label: String,
        text: Binding<String>,
        placeholder: String,
        field: Field,
        isSecure: Bool,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default,
        autocap: TextInputAutocapitalization = .sentences
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(OTNetTheme.textTertiary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .focused($focused, equals: field)
            .textInputAutocapitalization(autocap)
            .autocorrectionDisabled(true)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(OTNetTheme.muted.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(focused == field ? OTNetTheme.primary : OTNetTheme.border,
                                  lineWidth: focused == field ? 1.5 : 1)
            )
            .foregroundStyle(OTNetTheme.textPrimary)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(mode == .signIn ? "New here?" : "Already have an account?")
                .font(.footnote)
                .foregroundStyle(OTNetTheme.textSecondary)
            Button {
                setMode(mode == .signIn ? .signUp : .signIn)
            } label: {
                Text(mode == .signIn ? "Create an account" : "Sign in instead")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OTNetTheme.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func setMode(_ newMode: Mode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            mode = newMode
            auth.lastError = nil
        }
    }

    private func submit() {
        focused = nil
        Task {
            switch mode {
            case .signIn:
                await auth.login(email: email.trimmingCharacters(in: .whitespaces),
                                 password: password)
            case .signUp:
                await auth.register(email: email.trimmingCharacters(in: .whitespaces),
                                    password: password,
                                    displayName: displayName.trimmingCharacters(in: .whitespaces))
            }
        }
    }
}
