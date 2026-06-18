import AppIntents
import CoreSpotlight
import Foundation
import SFSafeSymbols
import Shared
import UniformTypeIdentifiers

@available(iOS 18.0, *)
enum HAIntentLightEntityVisibility: Sendable {
    case primary
    case hidden

    static func visibility(
        for entity: HAAppEntity,
        registry: EntityRegistryListForDisplay.Entity?
    ) -> HAIntentLightEntityVisibility {
        guard registry?.isHidden != true else { return .hidden }
        guard registry?.entityCategory == nil else { return .hidden }
        guard Domain(rawValue: entity.domain) == .light else { return .hidden }
        guard isLikelyTechnicalEntity(entity: entity, registry: registry) == false else { return .hidden }

        return .primary
    }

    private static func isLikelyTechnicalEntity(
        entity: HAAppEntity,
        registry: EntityRegistryListForDisplay.Entity?
    ) -> Bool {
        let searchableText = [
            entity.entityId,
            entity.name,
            entity.icon,
            entity.rawDeviceClass,
            registry?.translationKey,
            registry?.platform,
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        return [
            "firmware",
            "identify",
            "last_seen",
            "last seen",
            "linkquality",
            "link quality",
            "power-on",
            "power on",
            "rssi",
        ].contains { searchableText.contains($0) }
    }
}

@available(iOS 18.0, *)
struct HAIndexedLightEntity: IndexedEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Home Assistant Light")
    static let defaultQuery = HAIndexedLightEntityQuery()

    let id: String
    let entityId: String
    let serverId: String
    let serverName: String
    let displayName: String
    let areaName: String?
    let deviceName: String?
    let iconName: String?

    var intentLightEntity: IntentLightEntity {
        IntentLightEntity(
            id: id,
            entityId: entityId,
            serverId: serverId,
            areaName: areaName,
            deviceName: deviceName,
            displayString: displayName,
            iconName: iconName ?? SFSymbol.lightbulbFill.rawValue
        )
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: .init(stringLiteral: displayName),
            subtitle: .init(stringLiteral: subtitle),
            image: .init(systemName: SFSymbol.lightbulbFill.rawValue)
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .data)
        attributes.title = displayName
        attributes.displayName = displayName
        attributes.alternateNames = alternateNames
        attributes.keywords = keywords
        attributes.contentDescription = contentDescription
        attributes.domainIdentifier = "home-assistant.lights.\(serverId)"
        attributes.containerIdentifier = serverId
        attributes.containerTitle = areaName ?? serverName
        attributes.userOwned = NSNumber(value: true)
        attributes.userCurated = NSNumber(value: true)
        attributes.rankingHint = NSNumber(value: 80)
        return attributes
    }

    func matches(_ string: String) -> Bool {
        guard string.isEmpty == false else { return true }
        return searchableFields.contains { field in
            field.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var subtitle: String {
        [
            areaName,
            deviceName?.nilIfDuplicate(of: displayName),
            serverName,
        ]
        .compactMap { $0?.nilIfEmpty }
        .joined(separator: " - ")
    }

    private var contentDescription: String {
        [
            displayName,
            Domain.light.localizedDescription,
            areaName,
            deviceName,
            serverName,
            entityId,
        ]
        .compactMap { $0?.nilIfEmpty }
        .joined(separator: ", ")
    }

    private var alternateNames: [String] {
        [
            entityId,
            entityId.replacingOccurrences(of: ".", with: " "),
            entityId.replacingOccurrences(of: "_", with: " "),
            deviceName?.nilIfDuplicate(of: displayName),
            areaName,
        ]
        .compactMap { $0?.nilIfEmpty }
        .deduplicatedCaseInsensitive()
    }

    private var keywords: [String] {
        searchableFields
            .flatMap { [$0, $0.replacingOccurrences(of: "_", with: " ")] }
            .deduplicatedCaseInsensitive()
    }

    private var searchableFields: [String] {
        [
            displayName,
            entityId,
            serverName,
            Domain.light.rawValue,
            Domain.light.localizedDescription,
            areaName,
            deviceName,
            iconName,
        ].compactMap { $0?.nilIfEmpty }
    }
}

@available(iOS 18.0, *)
struct HAIndexedLightEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HAIndexedLightEntity] {
        let identifierSet = Set(identifiers)
        return primaryLights()
            .flatMap(\.1)
            .filter { identifierSet.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HAIndexedLightEntity> {
        collection(matching: string)
    }

    func suggestedEntities() async throws -> IntentItemCollection<HAIndexedLightEntity> {
        collection()
    }

    func primaryLights(matching string: String? = nil) -> [(Server, [HAIndexedLightEntity])] {
        ControlEntityProvider(domains: [.light])
            .getEntities()
            .compactMap { result -> (Server, [HAIndexedLightEntity])? in
                let (server, entities) = result
                let lights = primaryLights(
                    for: server,
                    entities: entities,
                    matching: string
                )
                return lights.isEmpty ? nil : (server, lights)
            }
    }

    private func collection(matching string: String? = nil) -> IntentItemCollection<HAIndexedLightEntity> {
        .init(sections: primaryLights(matching: string).map { result in
            let (server, lights) = result
            return IntentItemSection<HAIndexedLightEntity>(
                .init(stringLiteral: server.info.name),
                items: lights
            )
        })
    }

    private func primaryLights(
        for server: Server,
        entities: [HAAppEntity],
        matching string: String?
    ) -> [HAIndexedLightEntity] {
        let serverId = server.identifier.rawValue
        let deviceMap = entities.devicesMap(for: serverId)
        let areaMap = entities.areasMap(for: serverId)
        let registryMap = registryMap(serverId: serverId)

        return entities.compactMap { entity in
            let registry = registryMap[entity.entityId]
            let visibility = HAIntentLightEntityVisibility.visibility(for: entity, registry: registry)
            guard visibility == .primary else { return nil }

            let indexedEntity = HAIndexedLightEntity(
                id: entity.id,
                entityId: entity.entityId,
                serverId: entity.serverId,
                serverName: server.info.name,
                displayName: entity.name,
                areaName: areaMap[entity.entityId]?.name,
                deviceName: deviceMap[entity.entityId]?.displayName,
                iconName: registry?.icon ?? entity.icon
            )

            guard let string else { return indexedEntity }
            return indexedEntity.matches(string) ? indexedEntity : nil
        }
    }

    private func registryMap(serverId: String) -> [String: EntityRegistryListForDisplay.Entity] {
        do {
            return try EntityRegistryListForDisplay.Entity
                .config(serverId: serverId)
                .reduce(into: [:]) { result, entity in
                    result[entity.entityId] = entity
                }
        } catch {
            Current.Log.error("Failed to fetch light entity registry for Spotlight indexing: \(error)")
            return [:]
        }
    }
}

@available(iOS 27.0, *)
extension HAIndexedLightEntityQuery: IndexedEntityQuery {
    func reindexEntities(
        for identifiers: [HAIndexedLightEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let index = spotlightIndex(indexDescription: indexDescription)
        let lights = try await entities(for: identifiers)
        let indexedIdentifiers = Set(lights.map(\.id))
        let staleIdentifiers = identifiers.filter { indexedIdentifiers.contains($0) == false }

        if staleIdentifiers.isEmpty == false {
            try await index.deleteAppEntities(
                identifiedBy: staleIdentifiers,
                ofType: HAIndexedLightEntity.self
            )
        }

        if lights.isEmpty == false {
            try await index.indexAppEntities(lights)
        }
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let index = spotlightIndex(indexDescription: indexDescription)
        try await HAIndexedLightEntitySpotlightIndexer().reindexPrimaryLights(in: index)
    }

    private func spotlightIndex(indexDescription: CSSearchableIndexDescription) -> CSSearchableIndex {
        HAIndexedLightEntitySpotlightIndexer.spotlightIndex(protectionClass: indexDescription.protectionClass)
    }
}

@available(iOS 18.0, *)
struct HAIndexedLightEntitySpotlightIndexer {
    struct Summary: Sendable {
        let indexedCount: Int
    }

    static let indexName = "home-assistant.lights"

    private let query = HAIndexedLightEntityQuery()

    static func spotlightIndex(protectionClass: FileProtectionType? = nil) -> CSSearchableIndex {
        CSSearchableIndex(
            name: indexName,
            protectionClass: protectionClass
        )
    }

    func indexPrimaryLights() async throws -> Summary {
        try await indexPrimaryLights(in: Self.spotlightIndex())
    }

    func indexPrimaryLights(in index: CSSearchableIndex) async throws -> Summary {
        let lights = query.primaryLights().flatMap(\.1)
        guard lights.isEmpty == false else {
            return Summary(indexedCount: 0)
        }

        try await index.indexAppEntities(lights)
        return Summary(indexedCount: lights.count)
    }

    func reindexPrimaryLights() async throws -> Summary {
        try await reindexPrimaryLights(in: Self.spotlightIndex())
    }

    func reindexPrimaryLights(in index: CSSearchableIndex) async throws -> Summary {
        try await index.deleteAppEntities(ofType: HAIndexedLightEntity.self)
        return try await indexPrimaryLights(in: index)
    }

    func deleteLights(identifiedBy identifiers: [String]) async throws {
        guard identifiers.isEmpty == false else { return }
        try await Self.spotlightIndex().deleteAppEntities(
            identifiedBy: identifiers,
            ofType: HAIndexedLightEntity.self
        )
    }
}

@available(iOS 18.0, *)
enum HAIndexedLightEntityIndexingCoordinator {
    static func indexAvailableLights(reason: String) async {
        do {
            let summary = try await HAIndexedLightEntitySpotlightIndexer().indexPrimaryLights()
            Current.Log.info(
                "Indexed \(summary.indexedCount) Home Assistant lights for Spotlight (\(reason))"
            )
        } catch {
            Current.Log.error(
                "Failed to index Home Assistant lights for Spotlight (\(reason)): \(error)"
            )
        }
    }

    static func reindexAfterAppEntityCacheUpdate(serverId: String, serverName: String?) async {
        do {
            let summary = try await HAIndexedLightEntitySpotlightIndexer().reindexPrimaryLights()
            Current.Log.info(
                "Indexed \(summary.indexedCount) Home Assistant lights for Spotlight after app entity cache update"
                    + serverLogSuffix(serverId: serverId, serverName: serverName)
            )
        } catch {
            Current.Log.error(
                "Failed to index Home Assistant lights for Spotlight"
                    + serverLogSuffix(serverId: serverId, serverName: serverName)
                    + ": \(error)"
            )
        }
    }

    private static func serverLogSuffix(serverId: String, serverName: String?) -> String {
        if let serverName, serverName.isEmpty == false {
            return " for \(serverName) (\(serverId))"
        }

        return " for server \(serverId)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func nilIfDuplicate(of value: String) -> String? {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare(value.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame ?
            nil :
            self
    }
}

private extension [String] {
    func deduplicatedCaseInsensitive() -> [String] {
        var seen: Set<String> = []
        return filter { value in
            seen.insert(value.lowercased()).inserted
        }
    }
}
