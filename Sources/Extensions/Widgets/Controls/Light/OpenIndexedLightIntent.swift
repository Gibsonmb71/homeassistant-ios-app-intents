import AppIntents

@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenIndexedLightIntent: OpenIntent {
    var target: HAIndexedLightEntity
}
