import Foundation

enum ContactCategory: String, CaseIterable, Identifiable {
    case newLead = "New Lead"
    case warmLead = "Warm Lead"
    case client = "Client"
    case previousClient = "Previous Client"
    case vendor = "Vendor"
    case other = "Other"

    var id: String { rawValue }
}

enum PipelineStage: String, CaseIterable, Identifiable {
    case newLead = "New Lead"
    case contacted = "Contacted"
    case appointmentSet = "Appointment Set"
    case negotiation = "Negotiation"
    case won = "Won"
    case lost = "Lost"

    var id: String { rawValue }
}

enum ActivityType: String, CaseIterable, Identifiable {
    case note = "Note"
    case call = "Call"
    case email = "Email"
    case meeting = "Meeting"
    case message = "Message"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .note: return "note.text"
        case .call: return "phone"
        case .email: return "envelope"
        case .meeting: return "calendar"
        case .message: return "message"
        }
    }
}
