import AppIntents
import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct HAIndexedLightSnippetIntent: SnippetIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.indexed_light_snippet.title",
        defaultValue: "Show Home Assistant light"
    )

    static var isDiscoverable = false
    static var openAppWhenRun = false

    @Parameter(title: .init("app_intents.indexed_light_snippet.light.title", defaultValue: "Light"))
    var light: HAIndexedLightEntity

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let currentState = await HAIntentLightController().currentState(
            serverId: light.serverId,
            entityId: light.entityId
        )
        let lightState = currentState.map(HAIndexedLightState.init(homeAssistantState:)) ?? .unknown

        return .result(view: HAIndexedLightSnippetView(
            light: light,
            state: lightState
        ))
    }
}

@available(iOS 26.0, *)
private struct HAIndexedLightSnippetView: View {
    let light: HAIndexedLightEntity
    let state: HAIndexedLightState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image(uiImage: icon.image(
                    ofSize: .init(width: 34, height: 34),
                    color: iconColor
                ))
                    .frame(width: 52, height: 52)
                    .background(.thinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(light.displayName)
                        .font(.headline)
                        .lineLimit(2)

                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                Button(intent: controlIntent(value: true)) {
                    Label {
                        Text("On")
                    } icon: {
                        Image(systemSymbol: .power)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .disabled(state == .on)

                Button(intent: controlIntent(value: false)) {
                    Label {
                        Text("Off")
                    } icon: {
                        Image(systemSymbol: .power)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(state == .off)
            }
        }
        .padding()
    }

    private var statusText: String {
        switch state {
        case .on:
            return "On"
        case .off:
            return "Off"
        case .unavailable:
            return "Unavailable"
        case .unknown:
            return "Unknown"
        }
    }

    private var icon: MaterialDesignIcons {
        MaterialDesignIcons(
            serversideValueNamed: light.iconName ?? "mdi:lightbulb",
            fallback: .lightbulbIcon
        )
    }

    private var iconColor: UIColor {
        switch state {
        case .on:
            return .systemYellow
        case .off, .unavailable, .unknown:
            return .secondaryLabel
        }
    }

    private func controlIntent(value: Bool) -> LightIntent {
        let intent = LightIntent()
        intent.light = light.intentLightEntity
        intent.value = value
        intent.toggle = false
        return intent
    }
}
