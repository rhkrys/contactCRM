import LocalAuthentication
import SwiftUI

/// Gates app content behind Face ID / Touch ID / passcode on launch and on
/// background-to-foreground transitions.
final class AppLockSession: ObservableObject {
    @Published var isUnlocked = false
    @Published var lastError: String?

    func requestUnlock() {
        guard !isUnlocked else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = error?.localizedDescription ?? "Authentication unavailable on this device."
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock ContactCRM to view your client data"
        ) { [weak self] success, evalError in
            DispatchQueue.main.async {
                if success {
                    self?.isUnlocked = true
                    self?.lastError = nil
                } else {
                    self?.lastError = evalError?.localizedDescription ?? "Authentication failed."
                }
            }
        }
    }

    func lock() {
        isUnlocked = false
    }
}
