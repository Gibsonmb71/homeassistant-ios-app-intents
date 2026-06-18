import Shared

@available(iOS 18, *)
struct HAIntentLightController {
    /// Returns true after the command is submitted to an available connection, matching the existing quiet
    /// intent behavior.
    @discardableResult
    func control(
        serverId: String,
        entityId: String,
        value: Bool,
        toggle: Bool
    ) async -> Bool {
        await Current.connectivity.syncNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }),
              let connection = Current.api(for: server)?.connection else {
            return false
        }

        let _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.light.rawValue),
                service: .init(stringLiteral: service(value: value, toggle: toggle)),
                data: [
                    "entity_id": entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        return true
    }

    func currentState(serverId: String, entityId: String) async -> String? {
        await Current.connectivity.syncNetworkInformation()
        do {
            return try await ControlEntityProvider(domains: [.light]).currentState(
                serverId: serverId,
                entityId: entityId
            )
        } catch {
            Current.Log.error("Failed to fetch light state for \(entityId): \(error)")
            return nil
        }
    }

    private func service(value: Bool, toggle: Bool) -> String {
        if toggle {
            return Service.toggle.rawValue
        }

        return value ? Service.turnOn.rawValue : Service.turnOff.rawValue
    }
}
