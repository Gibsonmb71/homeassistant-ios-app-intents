import AppIntents

@available(iOS 26.0, *)
struct HAIndexedLightAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .yellow

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ControlIndexedLightIntent(action: .turnOn),
            phrases: [
                "Turn on \(\.$light) in \(.applicationName)",
                "Turn \(\.$light) on in \(.applicationName)",
                "Switch on \(\.$light) in \(.applicationName)",
                "Switch \(\.$light) on in \(.applicationName)",
                "Set \(\.$light) on in \(.applicationName)",
                "Turn on \(\.$light) with \(.applicationName)",
            ],
            shortTitle: .init(
                "app_shortcuts.indexed_light_turn_on.short_title",
                defaultValue: "Turn On Light"
            ),
            systemImageName: "lightbulb.fill"
        )

        AppShortcut(
            intent: ControlIndexedLightIntent(action: .turnOff),
            phrases: [
                "Turn off \(\.$light) in \(.applicationName)",
                "Turn \(\.$light) off in \(.applicationName)",
                "Switch off \(\.$light) in \(.applicationName)",
                "Switch \(\.$light) off in \(.applicationName)",
                "Set \(\.$light) off in \(.applicationName)",
                "Turn off \(\.$light) with \(.applicationName)",
            ],
            shortTitle: .init(
                "app_shortcuts.indexed_light_turn_off.short_title",
                defaultValue: "Turn Off Light"
            ),
            systemImageName: "lightbulb"
        )

        AppShortcut(
            intent: ControlIndexedLightIntent(action: .toggle),
            phrases: [
                "Toggle \(\.$light) in \(.applicationName)",
                "Toggle \(\.$light) with \(.applicationName)",
            ],
            shortTitle: .init(
                "app_shortcuts.indexed_light_toggle.short_title",
                defaultValue: "Toggle Light"
            ),
            systemImageName: "lightbulb.2"
        )

        AppShortcut(
            intent: GetIndexedLightStateIntent(),
            phrases: [
                "Is \(\.$light) on in \(.applicationName)",
                "Is \(\.$light) turned on in \(.applicationName)",
                "Check \(\.$light) in \(.applicationName)",
                "Check \(\.$light) with \(.applicationName)",
                "What is \(\.$light) in \(.applicationName)",
            ],
            shortTitle: .init(
                "app_shortcuts.indexed_light_state.short_title",
                defaultValue: "Light State"
            ),
            systemImageName: "lightbulb"
        )
    }
}
