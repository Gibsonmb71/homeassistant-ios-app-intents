import AppIntents

@available(iOS 26.0, *)
struct HAIndexedLightAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .yellow

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ControlIndexedLightIntent(),
            phrases: [
                "\(\.$action) \(\.$light) in \(.applicationName)",
                "\(\.$action) my \(\.$light) in \(.applicationName)",
            ],
            shortTitle: .init(
                "app_shortcuts.indexed_light_control.short_title",
                defaultValue: "Control Light"
            ),
            systemImageName: "lightbulb.fill"
        )

        AppShortcut(
            intent: GetIndexedLightStateIntent(),
            phrases: [
                "Is \(\.$light) on in \(.applicationName)",
                "Check \(\.$light) in \(.applicationName)",
            ],
            shortTitle: .init(
                "app_shortcuts.indexed_light_state.short_title",
                defaultValue: "Light State"
            ),
            systemImageName: "lightbulb"
        )
    }
}
