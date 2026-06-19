import AppIntents
import Foundation
import Shared

@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenIndexedLightIntent: OpenIntent {
    static var openAppWhenRun: Bool = true

    var target: HAIndexedLightEntity

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        if let url = AppConstants.openEntityDeeplinkURL(
            entityId: target.entityId,
            serverId: target.serverId
        ) {
            Current.Log.info("OpenIndexedLightIntent opening indexed light deeplink: \(url)")
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            Current.Log.error("OpenIndexedLightIntent failed to build deeplink for indexed light: \(target.id)")
        }
        #endif

        return .result()
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .system.open)
struct OpenIndexedHomeAssistantEntityIntent: OpenIntent {
    static var openAppWhenRun: Bool = true

    var target: HAIndexedHomeAssistantEntity

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let url: URL?
        if target.domain == .camera {
            url = AppConstants.openCameraDeeplinkURL(
                entityId: target.entityId,
                serverId: target.serverId
            )
        } else {
            url = AppConstants.openEntityDeeplinkURL(
                entityId: target.entityId,
                serverId: target.serverId
            )
        }

        if let url {
            Current.Log.info("OpenIndexedHomeAssistantEntityIntent opening indexed entity deeplink: \(url)")
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        } else {
            Current.Log.error(
                "OpenIndexedHomeAssistantEntityIntent failed to build deeplink for indexed entity: \(target.id)"
            )
        }
        #endif

        return .result()
    }
}
