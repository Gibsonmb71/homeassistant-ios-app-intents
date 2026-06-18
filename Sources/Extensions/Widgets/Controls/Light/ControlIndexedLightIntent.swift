import AppIntents
import Shared

@available(iOS 18.0, *)
enum HAIndexedLightControlAction: String, AppEnum, Codable, Sendable {
    case turnOn
    case turnOff
    case toggle

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Light Action")

    static let caseDisplayRepresentations: [HAIndexedLightControlAction: DisplayRepresentation] = [
        .turnOn: .init(title: "Turn On"),
        .turnOff: .init(title: "Turn Off"),
        .toggle: .init(title: "Toggle"),
    ]

    var value: Bool {
        switch self {
        case .turnOn:
            return true
        case .turnOff, .toggle:
            return false
        }
    }

    var toggle: Bool {
        self == .toggle
    }

    var completedDialogPrefix: String {
        switch self {
        case .turnOn:
            return "Turned on"
        case .turnOff:
            return "Turned off"
        case .toggle:
            return "Toggled"
        }
    }
}

@available(iOS 26.0, *)
struct ControlIndexedLightIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.control_indexed_light.title",
        defaultValue: "Control Home Assistant light"
    )

    static var description = IntentDescription(.init(
        "app_intents.control_indexed_light.description",
        defaultValue: "Control an indexed Home Assistant light"
    ))

    static var openAppWhenRun = false

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$light
            \.$action
        }
    }

    @Parameter(title: .init("app_intents.control_indexed_light.light.title", defaultValue: "Light"))
    var light: HAIndexedLightEntity

    @Parameter(title: .init("app_intents.control_indexed_light.action.title", defaultValue: "Action"))
    var action: HAIndexedLightControlAction

    init() {
        action = .turnOn
    }

    init(action: HAIndexedLightControlAction) {
        self.action = action
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let lightIntent = LightIntent()
        lightIntent.light = light.intentLightEntity
        lightIntent.value = action.value
        lightIntent.toggle = action.toggle

        let didSubmitCommand = await lightIntent.controlLight()

        guard didSubmitCommand else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let snippetIntent = HAIndexedLightSnippetIntent()
        snippetIntent.light = light

        return .result(
            dialog: "\(action.completedDialogPrefix) \(light.displayName).",
            snippetIntent: snippetIntent
        )
    }
}
