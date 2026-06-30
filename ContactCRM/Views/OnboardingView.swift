import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @StateObject private var contactsService = ContactsService.shared
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("lock.shield.fill", "Private by design",
         "All your notes, likes, dislikes, and client history are encrypted on this device. Nothing leaves your phone."),
        ("person.crop.circle.fill.badge.plus", "Linked to your Contacts",
         "ContactCRM layers CRM data on top of your existing iOS Contacts. Names, photos, and emails stay in the place you already manage them."),
        ("chart.bar.xaxis", "Visual pipelines",
         "See every lead and client at a glance on a Kanban board. Create custom pipelines for different workflows — sales, onboarding, follow-up."),
        ("bell.badge.fill", "Never miss a follow-up",
         "Set reminders tied to specific contacts. You'll get a notification at exactly the right time.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPage(icon: item.0, title: item.1, body: item.2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: page)

            VStack(spacing: 12) {
                if page == pages.count - 1 {
                    Button("Get started") {
                        Task { await grantContactsAndFinish() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Next") { page += 1 }
                        .buttonStyle(.borderedProminent)
                    Button("Skip") { finish() }
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func grantContactsAndFinish() async {
        _ = await contactsService.requestAccess()
        ReminderService.shared.requestNotificationPermission()
        finish()
    }

    private func finish() {
        hasCompleted = true
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let body: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(.accent)
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            Spacer()
        }
    }
}
