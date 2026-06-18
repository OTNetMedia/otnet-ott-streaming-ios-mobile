import SwiftUI

/// 4-digit PIN entry for the parental-control gate on a profile switch.
/// Driven by `AuthStore.pinPromptForIndex`; calls back through
/// `auth.submitProfilePin(_:)` / `auth.cancelProfilePin()`.
struct PinEntrySheet: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var pin: String = ""
    @State private var countdownTick = Date()
    @Environment(\.dismiss) private var dismiss

    private let digits = 4

    var body: some View {
        VStack(spacing: 0) {
            handle
            Spacer(minLength: 0)
            VStack(spacing: 28) {
                header
                pinDisplay
                if let lockMessage {
                    Text(lockMessage)
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else if let err = auth.pinError {
                    Text(err)
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                keypad
                Button("Cancel") {
                    auth.cancelProfilePin()
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OTNetTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OTNetTheme.background.ignoresSafeArea())
        .onChange(of: auth.pinPromptForIndex) { newValue in
            if newValue == nil { dismiss() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            countdownTick = Date()
        }
    }

    private var handle: some View {
        Capsule()
            .fill(.white.opacity(0.3))
            .frame(width: 44, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(OTNetTheme.primary.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(OTNetTheme.primary)
            }
            Text(profileNameLine)
                .font(.title3.bold())
                .foregroundStyle(OTNetTheme.textPrimary)
            Text("Enter the PIN to switch profiles.")
                .font(.subheadline)
                .foregroundStyle(OTNetTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var profileNameLine: String {
        if let idx = auth.pinPromptForIndex,
           idx >= 0, idx < auth.profiles.count {
            return auth.profiles[idx].displayName
        }
        return "Profile locked"
    }

    private var pinDisplay: some View {
        HStack(spacing: 16) {
            ForEach(0..<digits, id: \.self) { i in
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    .background(
                        Circle().fill(i < pin.count ? OTNetTheme.primary : Color.clear)
                    )
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var keypad: some View {
        VStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 14) {
                    ForEach(1...3, id: \.self) { col in
                        let n = row * 3 + col
                        digitButton("\(n)")
                    }
                }
            }
            HStack(spacing: 14) {
                Spacer().frame(width: 72, height: 72)
                digitButton("0")
                deleteButton
            }
        }
        .opacity(locked ? 0.4 : 1)
        .allowsHitTesting(!locked)
    }

    private func digitButton(_ digit: String) -> some View {
        Button {
            guard pin.count < digits else { return }
            pin.append(digit)
            if pin.count == digits { submit() }
        } label: {
            Text(digit)
                .font(.title.weight(.semibold))
                .foregroundStyle(OTNetTheme.textPrimary)
                .frame(width: 72, height: 72)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(auth.pinSwitchInFlight)
    }

    private var deleteButton: some View {
        Button {
            if !pin.isEmpty { pin.removeLast() }
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.title3)
                .foregroundStyle(OTNetTheme.textSecondary)
                .frame(width: 72, height: 72)
                .background(.white.opacity(0.04), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(auth.pinSwitchInFlight || pin.isEmpty)
    }

    private func submit() {
        let entered = pin
        auth.submitProfilePin(entered)
        // Clear the visible digits so a wrong PIN gives a fresh input next try.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            pin = ""
        }
    }

    private var locked: Bool {
        guard let until = auth.pinLockedUntil else { return false }
        return until > countdownTick
    }

    private var lockMessage: String? {
        guard let until = auth.pinLockedUntil, until > countdownTick else { return nil }
        let seconds = Int(until.timeIntervalSince(countdownTick).rounded(.up))
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return "Locked. Try again in \(m)m \(String(format: "%02d", s))s."
        }
        return "Locked. Try again in \(seconds)s."
    }
}
