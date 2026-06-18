import AppIntents

@available(iOS 18, *)
struct LightIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.light.title", defaultValue: "Control light")

    @Parameter(title: .init("app_intents.lights.light.title", defaultValue: "Light"))
    var light: IntentLightEntity

    @Parameter(title: .init("app_intents.state.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.state.toggle", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult {
        await controlLight()
        return .result()
    }

    @discardableResult
    func controlLight() async -> Bool {
        await HAIntentLightController().control(
            serverId: light.serverId,
            entityId: light.entityId,
            value: value,
            toggle: toggle
        )
    }
}
