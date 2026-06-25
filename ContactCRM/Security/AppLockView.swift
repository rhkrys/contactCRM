import SwiftUI

struct AppLockView: View {
    @ObservedObject var session: AppLockSession

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("ContactCRM is locked")
                .font(.headline)
            if let error = session.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Button("Unlock") { session.requestUnlock() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
