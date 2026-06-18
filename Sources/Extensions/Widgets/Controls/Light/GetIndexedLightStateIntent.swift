import AppIntents
import Shared

@available(iOS 18.0, *)
enum HAIndexedLightState: String, AppEnum, Codable, Sendable {
    case on
    case off
    case unavailable
    case unknown

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Light State")

    static let caseDisplayRepresentations: [HAIndexedLightState: DisplayRepresentation] = [
        .on: .init(title: "On"),
        .off: .init(title: "Off"),
        .unavailable: .init(title: "Unavailable"),
        .unknown: .init(title: "Unknown"),
    ]

    init(homeAssistantState: String) {
        switch homeAssistantState.lowercased() {
        case ControlEntityProvider.States.on.rawValue:
            self = .on
        case ControlEntityProvider.States.off.rawValue:
            self = .off
        case "unavailable":
            self = .unavailable
        default:
            self = .unknown
        }
    }

    var dialogSuffix: String {
        switch self {
        case .on:
            return "is on."
        case .off:
            return "is off."
        case .unavailable:
            return "is unavailable."
        case .unknown:
            return "has an unknown state."
        }
    }
}

@available(iOS 18.0, *)
struct GetIndexedLightStateIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.get_indexed_light_state.title",
        defaultValue: "Get Home Assistant light state"
    )

    static var description = IntentDescription(.init(
        "app_intents.get_indexed_light_state.description",
        defaultValue: "Get the current state of an indexed Home Assistant light"
    ))

    static var openAppWhenRun = false

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$light
        }
    }

    @Parameter(title: .init("app_intents.get_indexed_light_state.light.title", defaultValue: "Light"))
    var light: HAIndexedLightEntity

    func perform() async throws -> some IntentResult & ReturnsValue<HAIndexedLightState> & ProvidesDialog {
        guard let currentState = await HAIntentLightController().currentState(
            serverId: light.serverId,
            entityId: light.entityId
        ) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let lightState = HAIndexedLightState(homeAssistantState: currentState)
        return .result(value: lightState, dialog: "\(light.displayName) \(lightState.dialogSuffix)")
    }
}
