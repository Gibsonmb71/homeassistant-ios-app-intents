import AppIntents
import CoreSpotlight
import Foundation
import GRDB
import SFSafeSymbols
import Shared
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

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
struct HAIndexedLightEntity: IndexedEntity, URLRepresentableEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Home Assistant Light",
        synonyms: [
            "light",
            "lamp",
        ]
    )
    static let defaultQuery = HAIndexedLightEntityQuery()
    static var urlRepresentation: URLRepresentation {
        #if DEBUG
        "homeassistant-dev://entity/\(.id)"
        #elseif BETA
        "homeassistant-beta://entity/\(.id)"
        #else
        "homeassistant://entity/\(.id)"
        #endif
    }

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
            image: .init(systemName: SFSymbol.lightbulbFill.rawValue),
            synonyms: displaySynonyms.map { .init(stringLiteral: $0) }
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .data)
        attributes.title = displayName
        attributes.displayName = displayName
        attributes.alternateNames = alternateNames
        attributes.keywords = keywords
        attributes.contentDescription = contentDescription
        attributes.identifier = serverName
        attributes.contentURL = AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId)
        attributes.domainIdentifier = "home-assistant.lights.\(serverId)"
        attributes.containerIdentifier = serverId
        attributes.containerTitle = serverName
        attributes.containerDisplayName = serverName
        attributes.relatedUniqueIdentifier = serverId
        attributes.thumbnailData = Self.lightbulbThumbnailData
        attributes.userOwned = NSNumber(value: true)
        attributes.userCurated = NSNumber(value: true)
        attributes.rankingHint = NSNumber(value: 80)
        return attributes
    }

    var urlRepresentation: URL? {
        AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId)
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
            Domain.light.localizedDescription,
            areaName.map { "in \($0)" },
            areaName == nil ? serverName : nil,
        ]
        .compactMap { $0?.nilIfEmpty }
        .joined(separator: " ")
    }

    private var alternateNames: [String] {
        [
            entityId,
            entityId.replacingOccurrences(of: ".", with: " "),
            entityId.replacingOccurrences(of: "_", with: " "),
            displayName.nilIfDuplicate(of: entityId),
        ]
        .compactMap { $0?.nilIfEmpty }
        + displaySynonyms
    }

    private var displaySynonyms: [String] {
        [
            deviceName?.nilIfDuplicate(of: displayName),
            areaName,
            areaName.map { "\($0) light" },
            areaName.map { "\($0) lights" },
            areaName.map { "\($0) lamp" },
            deviceName.map { "\($0) light" },
            deviceName.map { "\($0) lamp" },
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
        ].compactMap { $0?.nilIfEmpty } + displaySynonyms
    }

    private static var lightbulbThumbnailData: Data? {
        #if canImport(UIKit)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 42, weight: .regular)
        guard let symbol = UIImage(
            systemName: SFSymbol.lightbulbFill.rawValue,
            withConfiguration: symbolConfiguration
        )?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal) else {
            return nil
        }

        let imageSize = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: imageSize).pngData { _ in
            let origin = CGPoint(
                x: (imageSize.width - symbol.size.width) / 2,
                y: (imageSize.height - symbol.size.height) / 2
            )
            symbol.draw(at: origin)
        }
        #else
        return nil
        #endif
    }
}

@available(iOS 18.0, *)
private struct HAIndexedEntityDomain: Sendable {
    let domain: Domain
    let displayName: String
    let synonyms: [String]
    let symbolName: String

    static let all: [HAIndexedEntityDomain] = [
        .init(
            domain: .switch,
            displayName: Domain.switch.localizedDescription,
            synonyms: ["switches"],
            symbolName: SFSymbol.lightswitchOnFill.rawValue
        ),
        .init(
            domain: .inputBoolean,
            displayName: Domain.switch.localizedDescription,
            synonyms: ["switch", "switches", "input boolean", "helper"],
            symbolName: SFSymbol.lightswitchOnFill.rawValue
        ),
        .init(
            domain: .fan,
            displayName: Domain.fan.localizedDescription,
            synonyms: ["fans"],
            symbolName: SFSymbol.fan.rawValue
        ),
        .init(
            domain: .cover,
            displayName: Domain.cover.localizedDescription,
            synonyms: ["covers", "blind", "blinds", "shade", "shades", "garage door"],
            symbolName: "window.shade.closed"
        ),
        .init(
            domain: .lock,
            displayName: Domain.lock.localizedDescription,
            synonyms: ["locks", "door lock"],
            symbolName: "lock.fill"
        ),
        .init(
            domain: .scene,
            displayName: Domain.scene.localizedDescription,
            synonyms: ["scenes"],
            symbolName: "sparkles"
        ),
        .init(
            domain: .script,
            displayName: Domain.script.localizedDescription,
            synonyms: ["scripts"],
            symbolName: SFSymbol.applescriptFill.rawValue
        ),
        .init(
            domain: .button,
            displayName: Domain.button.localizedDescription,
            synonyms: ["buttons"],
            symbolName: SFSymbol.circleCircle.rawValue
        ),
        .init(
            domain: .inputButton,
            displayName: Domain.button.localizedDescription,
            synonyms: ["button", "buttons", "input button", "helper"],
            symbolName: SFSymbol.circleCircle.rawValue
        ),
        .init(
            domain: .camera,
            displayName: Domain.camera.localizedDescription,
            synonyms: ["cameras"],
            symbolName: "camera.fill"
        ),
        .init(
            domain: .climate,
            displayName: Domain.climate.localizedDescription,
            synonyms: ["thermostat", "thermostats", "climate control"],
            symbolName: "thermometer.medium"
        ),
        .init(
            domain: .mediaPlayer,
            displayName: friendlyDisplayName(for: .mediaPlayer),
            synonyms: ["media player", "media players", "speaker", "speakers", "tv"],
            symbolName: "play.tv.fill"
        ),
        .init(
            domain: .vacuum,
            displayName: friendlyDisplayName(for: .vacuum),
            synonyms: ["vacuum", "vacuums", "robot vacuum"],
            symbolName: "sensor.tag.radiowaves.forward.fill"
        ),
    ]

    static var indexedDomains: [Domain] {
        all.map(\.domain)
    }

    static func config(for domain: Domain) -> HAIndexedEntityDomain? {
        all.first { $0.domain == domain }
    }

    static func friendlyDisplayName(for domain: Domain) -> String {
        let localized = domain.localizedDescription
        guard localized == domain.rawValue else { return localized }

        return domain.rawValue
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

@available(iOS 18.0, *)
enum HAIndexedHomeAssistantEntityVisibility: Sendable {
    case primary
    case hidden

    static func visibility(
        for entity: HAAppEntity,
        registry: EntityRegistryListForDisplay.Entity?
    ) -> HAIndexedHomeAssistantEntityVisibility {
        guard registry?.isHidden != true else { return .hidden }
        guard registry?.entityCategory == nil else { return .hidden }
        guard let domain = Domain(rawValue: entity.domain) else { return .hidden }
        guard HAIndexedEntityDomain.config(for: domain) != nil else { return .hidden }
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

        let commonTechnicalTerms = [
            "firmware",
            "identify",
            "last_seen",
            "last seen",
            "linkquality",
            "link quality",
            "power-on",
            "power on",
            "rssi",
        ]

        let switchTechnicalTerms = [
            "calibration",
            "diagnostic",
            "led",
            "ota",
            "pairing",
            "reboot",
            "restart",
            "signal",
            "sync",
            "update",
        ]

        let domain = Domain(rawValue: entity.domain)
        let technicalTerms = domain == .switch || domain == .inputBoolean ?
            commonTechnicalTerms + switchTechnicalTerms :
            commonTechnicalTerms

        return technicalTerms.contains { searchableText.contains($0) }
    }
}

@available(iOS 18.0, *)
struct HAIndexedHomeAssistantEntity: IndexedEntity, URLRepresentableEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Home Assistant Entity",
        synonyms: [
            "switch",
            "fan",
            "cover",
            "lock",
            "scene",
            "script",
            "button",
            "camera",
            "thermostat",
            "media player",
            "vacuum",
        ]
    )
    static let defaultQuery = HAIndexedHomeAssistantEntityQuery()
    static var urlRepresentation: URLRepresentation {
        #if DEBUG
        "homeassistant-dev://entity/\(.id)"
        #elseif BETA
        "homeassistant-beta://entity/\(.id)"
        #else
        "homeassistant://entity/\(.id)"
        #endif
    }

    let id: String
    let entityId: String
    let serverId: String
    let serverName: String
    let displayName: String
    let areaName: String?
    let deviceName: String?
    let iconName: String?
    let domainRawValue: String

    var domain: Domain? {
        Domain(rawValue: domainRawValue)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: .init(stringLiteral: displayName),
            subtitle: .init(stringLiteral: subtitle),
            image: .init(systemName: domainConfig.symbolName),
            synonyms: displaySynonyms.map { .init(stringLiteral: $0) }
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .data)
        attributes.title = displayName
        attributes.displayName = displayName
        attributes.alternateNames = alternateNames
        attributes.keywords = keywords
        attributes.contentDescription = contentDescription
        attributes.identifier = serverName
        attributes.contentURL = deeplinkURL
        attributes.domainIdentifier = "home-assistant.\(domainRawValue).\(serverId)"
        attributes.containerIdentifier = serverId
        attributes.containerTitle = serverName
        attributes.containerDisplayName = serverName
        attributes.relatedUniqueIdentifier = serverId
        attributes.thumbnailData = Self.thumbnailData(symbolName: domainConfig.symbolName)
        attributes.userOwned = NSNumber(value: true)
        attributes.userCurated = NSNumber(value: true)
        attributes.rankingHint = NSNumber(value: rankingHint)
        return attributes
    }

    var urlRepresentation: URL? {
        deeplinkURL
    }

    func matches(_ string: String) -> Bool {
        guard string.isEmpty == false else { return true }
        return searchableFields.contains { field in
            field.range(of: string, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private var domainConfig: HAIndexedEntityDomain {
        domain.flatMap { HAIndexedEntityDomain.config(for: $0) } ?? .init(
            domain: .switch,
            displayName: "Entity",
            synonyms: [],
            symbolName: "app.connected.to.app.below.fill"
        )
    }

    private var deeplinkURL: URL? {
        if domain == .camera {
            return AppConstants.openCameraDeeplinkURL(entityId: entityId, serverId: serverId)
        }

        return AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId)
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
            domainConfig.displayName,
            areaName.map { "in \($0)" },
            areaName == nil ? serverName : nil,
        ]
        .compactMap { $0?.nilIfEmpty }
        .joined(separator: " ")
    }

    private var alternateNames: [String] {
        [
            entityId,
            entityId.replacingOccurrences(of: ".", with: " "),
            entityId.replacingOccurrences(of: "_", with: " "),
            displayName.nilIfDuplicate(of: entityId),
        ]
        .compactMap { $0?.nilIfEmpty }
        + displaySynonyms
    }

    private var displaySynonyms: [String] {
        [
            deviceName?.nilIfDuplicate(of: displayName),
            areaName,
            areaName.map { "\($0) \(domainConfig.displayName)" },
            deviceName.map { "\($0) \(domainConfig.displayName)" },
        ]
        .compactMap { $0?.nilIfEmpty }
        + domainConfig.synonyms
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
            domainRawValue,
            domainConfig.displayName,
            areaName,
            deviceName,
            iconName,
        ].compactMap { $0?.nilIfEmpty } + displaySynonyms
    }

    private var rankingHint: Int {
        switch domain {
        case .some(.switch), .some(.inputBoolean), .some(.fan), .some(.cover), .some(.lock), .some(.scene),
             .some(.script), .some(.button), .some(.inputButton):
            return 75
        case .some(.camera), .some(.climate), .some(.mediaPlayer), .some(.vacuum):
            return 65
        default:
            return 50
        }
    }

    private static func thumbnailData(symbolName: String) -> Data? {
        #if canImport(UIKit)
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 42, weight: .regular)
        guard let symbol = UIImage(
            systemName: symbolName,
            withConfiguration: symbolConfiguration
        )?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal) else {
            return nil
        }

        let imageSize = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: imageSize).pngData { _ in
            let origin = CGPoint(
                x: (imageSize.width - symbol.size.width) / 2,
                y: (imageSize.height - symbol.size.height) / 2
            )
            symbol.draw(at: origin)
        }
        #else
        return nil
        #endif
    }
}

@available(iOS 18.0, *)
private struct HAIndexedEntityDatabaseSnapshot {
    let entitiesPerServer: [(Server, [HAAppEntity])]
    let registryMaps: [String: [String: EntityRegistryListForDisplay.Entity]]
    let deviceMaps: [String: [String: AppDeviceRegistry]]
    let areaMaps: [String: [String: AppArea]]

    static func load(domains: [Domain]) -> HAIndexedEntityDatabaseSnapshot {
        var entitiesPerServer: [(Server, [HAAppEntity])] = []
        var registryMaps: [String: [String: EntityRegistryListForDisplay.Entity]] = [:]
        var deviceMaps: [String: [String: AppDeviceRegistry]] = [:]
        var areaMaps: [String: [String: AppArea]] = [:]
        let domainValues = domains.map(\.rawValue)

        for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
            let serverId = server.identifier.rawValue

            do {
                let snapshot = try Current.database().read { db in
                    let entities = try fetchEntities(
                        db: db,
                        serverId: serverId,
                        domainValues: domainValues
                    )
                    let registryMap = try fetchRegistryMap(db: db, serverId: serverId)
                    let devices = try AppDeviceRegistry
                        .filter(Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId)
                        .fetchAll(db)
                    let areas = try AppArea
                        .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                        .fetchAll(db)

                    return (
                        entities: entities,
                        registryMap: registryMap,
                        deviceMap: buildDeviceMap(registryMap: registryMap, devices: devices),
                        areaMap: buildAreaMap(areas: areas)
                    )
                }

                entitiesPerServer.append((server, snapshot.entities))
                registryMaps[serverId] = snapshot.registryMap
                deviceMaps[serverId] = snapshot.deviceMap
                areaMaps[serverId] = snapshot.areaMap
            } catch {
                Current.Log.error("Failed to load entity database snapshot for Spotlight indexing: \(error)")
            }
        }

        return HAIndexedEntityDatabaseSnapshot(
            entitiesPerServer: entitiesPerServer,
            registryMaps: registryMaps,
            deviceMaps: deviceMaps,
            areaMaps: areaMaps
        )
    }

    private static func fetchEntities(
        db: Database,
        serverId: String,
        domainValues: [String]
    ) throws -> [HAAppEntity] {
        let serverFilter = Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId
        guard domainValues.isEmpty == false else {
            return try HAAppEntity
                .filter(serverFilter)
                .fetchAll(db)
        }

        return try HAAppEntity
            .filter(serverFilter)
            .filter(domainValues.contains(Column(DatabaseTables.AppEntity.domain.rawValue)))
            .fetchAll(db)
    }

    private static func fetchRegistryMap(
        db: Database,
        serverId: String
    ) throws -> [String: EntityRegistryListForDisplay.Entity] {
        try EntityRegistryListForDisplay.Entity
            .filter(Column(DatabaseTables.DisplayEntityRegistry.serverId.rawValue) == serverId)
            .fetchAll(db)
            .reduce(into: [:]) { result, entity in
                result[entity.entityId] = entity
            }
    }

    private static func buildDeviceMap(
        registryMap: [String: EntityRegistryListForDisplay.Entity],
        devices: [AppDeviceRegistry]
    ) -> [String: AppDeviceRegistry] {
        let devicesByDeviceId = Dictionary(uniqueKeysWithValues: devices.map { ($0.deviceId, $0) })
        return registryMap.reduce(into: [:]) { result, entry in
            guard let deviceId = entry.value.deviceId,
                  let device = devicesByDeviceId[deviceId] else {
                return
            }
            result[entry.key] = device
        }
    }

    private static func buildAreaMap(areas: [AppArea]) -> [String: AppArea] {
        areas.reduce(into: [:]) { result, area in
            for entityId in area.entities {
                result[entityId] = area
            }
        }
    }
}

@available(iOS 18.0, *)
struct HAIndexedLightEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HAIndexedLightEntity] {
        await MainActor.run {
            let identifierSet = Set(identifiers)
            return primaryLights()
                .flatMap(\.1)
                .filter { identifierSet.contains($0.id) }
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HAIndexedLightEntity> {
        let sections = await MainActor.run {
            primaryLights(matching: string).map { server, lights in
                (server.info.name, lights)
            }
        }
        return collection(sections: sections)
    }

    func suggestedEntities() async throws -> IntentItemCollection<HAIndexedLightEntity> {
        let sections = await MainActor.run {
            primaryLights().map { server, lights in
                (server.info.name, lights)
            }
        }
        return collection(sections: sections)
    }

    func primaryLights(matching string: String? = nil) -> [(Server, [HAIndexedLightEntity])] {
        let snapshot = HAIndexedEntityDatabaseSnapshot.load(domains: [.light])
        return snapshot.entitiesPerServer.compactMap { result -> (Server, [HAIndexedLightEntity])? in
            let (server, entities) = result
            let serverId = server.identifier.rawValue
            let lights = primaryLights(
                for: server,
                entities: entities,
                deviceMap: snapshot.deviceMaps[serverId] ?? [:],
                areaMap: snapshot.areaMaps[serverId] ?? [:],
                registryMap: snapshot.registryMaps[serverId] ?? [:],
                matching: string
            )
            return lights.isEmpty ? nil : (server, lights)
        }
    }

    private func collection(matching string: String? = nil) -> IntentItemCollection<HAIndexedLightEntity> {
        collection(sections: primaryLights(matching: string).map { server, lights in
            (server.info.name, lights)
        })
    }

    private func collection(
        sections: [(String, [HAIndexedLightEntity])]
    ) -> IntentItemCollection<HAIndexedLightEntity> {
        .init(sections: sections.map { section in
            let (serverName, lights) = section
            return IntentItemSection<HAIndexedLightEntity>(
                .init(stringLiteral: serverName),
                items: lights
            )
        })
    }

    private func primaryLights(
        for server: Server,
        entities: [HAAppEntity],
        deviceMap: [String: AppDeviceRegistry],
        areaMap: [String: AppArea],
        registryMap: [String: EntityRegistryListForDisplay.Entity],
        matching string: String?
    ) -> [HAIndexedLightEntity] {
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
}

@available(iOS 18.0, *)
struct HAIndexedHomeAssistantEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HAIndexedHomeAssistantEntity] {
        await MainActor.run {
            let identifierSet = Set(identifiers)
            return primaryEntities()
                .flatMap(\.1)
                .filter { identifierSet.contains($0.id) }
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HAIndexedHomeAssistantEntity> {
        let sections = await MainActor.run {
            primaryEntities(matching: string).map { server, entities in
                (server.info.name, entities)
            }
        }
        return collection(sections: sections)
    }

    func suggestedEntities() async throws -> IntentItemCollection<HAIndexedHomeAssistantEntity> {
        let sections = await MainActor.run {
            primaryEntities().map { server, entities in
                (server.info.name, entities)
            }
        }
        return collection(sections: sections)
    }

    func primaryEntities(matching string: String? = nil) -> [(Server, [HAIndexedHomeAssistantEntity])] {
        let snapshot = HAIndexedEntityDatabaseSnapshot.load(domains: HAIndexedEntityDomain.indexedDomains)
        return snapshot.entitiesPerServer.compactMap { result -> (Server, [HAIndexedHomeAssistantEntity])? in
            let (server, entities) = result
            let serverId = server.identifier.rawValue
            let indexedEntities = primaryEntities(
                for: server,
                entities: entities,
                deviceMap: snapshot.deviceMaps[serverId] ?? [:],
                areaMap: snapshot.areaMaps[serverId] ?? [:],
                registryMap: snapshot.registryMaps[serverId] ?? [:],
                matching: string
            )
            return indexedEntities.isEmpty ? nil : (server, indexedEntities)
        }
    }

    private func collection(
        matching string: String? = nil
    ) -> IntentItemCollection<HAIndexedHomeAssistantEntity> {
        collection(sections: primaryEntities(matching: string).map { server, entities in
            (server.info.name, entities)
        })
    }

    private func collection(
        sections: [(String, [HAIndexedHomeAssistantEntity])]
    ) -> IntentItemCollection<HAIndexedHomeAssistantEntity> {
        .init(sections: sections.map { section in
            let (serverName, entities) = section
            return IntentItemSection<HAIndexedHomeAssistantEntity>(
                .init(stringLiteral: serverName),
                items: entities
            )
        })
    }

    private func primaryEntities(
        for server: Server,
        entities: [HAAppEntity],
        deviceMap: [String: AppDeviceRegistry],
        areaMap: [String: AppArea],
        registryMap: [String: EntityRegistryListForDisplay.Entity],
        matching string: String?
    ) -> [HAIndexedHomeAssistantEntity] {
        return entities.compactMap { entity in
            let registry = registryMap[entity.entityId]
            let visibility = HAIndexedHomeAssistantEntityVisibility.visibility(for: entity, registry: registry)
            guard visibility == .primary else { return nil }
            guard Domain(rawValue: entity.domain) != .light else { return nil }

            let indexedEntity = HAIndexedHomeAssistantEntity(
                id: entity.id,
                entityId: entity.entityId,
                serverId: entity.serverId,
                serverName: server.info.name,
                displayName: entity.name,
                areaName: areaMap[entity.entityId]?.name,
                deviceName: deviceMap[entity.entityId]?.displayName,
                iconName: registry?.icon ?? entity.icon,
                domainRawValue: entity.domain
            )

            guard let string else { return indexedEntity }
            return indexedEntity.matches(string) ? indexedEntity : nil
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
        _ = try await HAIndexedLightEntitySpotlightIndexer().reindexPrimaryLights(in: index)
    }

    private func spotlightIndex(indexDescription: CSSearchableIndexDescription) -> CSSearchableIndex {
        HAIndexedLightEntitySpotlightIndexer.spotlightIndex(protectionClass: indexDescription.protectionClass)
    }
}

@available(iOS 27.0, *)
extension HAIndexedHomeAssistantEntityQuery: IndexedEntityQuery {
    func reindexEntities(
        for identifiers: [HAIndexedHomeAssistantEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        let index = spotlightIndex(indexDescription: indexDescription)
        let entities = try await entities(for: identifiers)
        let indexedIdentifiers = Set(entities.map(\.id))
        let staleIdentifiers = identifiers.filter { indexedIdentifiers.contains($0) == false }

        if staleIdentifiers.isEmpty == false {
            try await index.deleteAppEntities(
                identifiedBy: staleIdentifiers,
                ofType: HAIndexedHomeAssistantEntity.self
            )
        }

        if entities.isEmpty == false {
            try await index.indexAppEntities(entities)
        }
    }

    func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let index = spotlightIndex(indexDescription: indexDescription)
        _ = try await HAIndexedHomeAssistantEntitySpotlightIndexer().reindexPrimaryEntities(in: index)
    }

    private func spotlightIndex(indexDescription: CSSearchableIndexDescription) -> CSSearchableIndex {
        HAIndexedHomeAssistantEntitySpotlightIndexer.spotlightIndex(
            protectionClass: indexDescription.protectionClass
        )
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
        let lights = await MainActor.run {
            query.primaryLights().flatMap(\.1)
        }
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
struct HAIndexedHomeAssistantEntitySpotlightIndexer {
    struct Summary: Sendable {
        let indexedCount: Int
    }

    static let indexName = "home-assistant.entities"

    private let query = HAIndexedHomeAssistantEntityQuery()

    static func spotlightIndex(protectionClass: FileProtectionType? = nil) -> CSSearchableIndex {
        CSSearchableIndex(
            name: indexName,
            protectionClass: protectionClass
        )
    }

    func indexPrimaryEntities() async throws -> Summary {
        try await indexPrimaryEntities(in: Self.spotlightIndex())
    }

    func indexPrimaryEntities(in index: CSSearchableIndex) async throws -> Summary {
        let entities = await MainActor.run {
            query.primaryEntities().flatMap(\.1)
        }
        guard entities.isEmpty == false else {
            return Summary(indexedCount: 0)
        }

        try await index.indexAppEntities(entities)
        return Summary(indexedCount: entities.count)
    }

    func reindexPrimaryEntities() async throws -> Summary {
        try await reindexPrimaryEntities(in: Self.spotlightIndex())
    }

    func reindexPrimaryEntities(in index: CSSearchableIndex) async throws -> Summary {
        try await index.deleteAppEntities(ofType: HAIndexedHomeAssistantEntity.self)
        return try await indexPrimaryEntities(in: index)
    }

    func deleteEntities(identifiedBy identifiers: [String]) async throws {
        guard identifiers.isEmpty == false else { return }
        try await Self.spotlightIndex().deleteAppEntities(
            identifiedBy: identifiers,
            ofType: HAIndexedHomeAssistantEntity.self
        )
    }
}

@available(iOS 18.0, *)
enum HAIndexedEntityIndexingCoordinator {
    static func indexAvailableEntities(reason: String) async {
        do {
            async let lightSummary = HAIndexedLightEntitySpotlightIndexer().indexPrimaryLights()
            async let entitySummary = HAIndexedHomeAssistantEntitySpotlightIndexer().indexPrimaryEntities()
            let summaries = try await (lightSummary, entitySummary)
            Current.Log.info(
                "Indexed \(summaries.0.indexedCount) Home Assistant lights and "
                    + "\(summaries.1.indexedCount) other entities for Spotlight (\(reason))"
            )
        } catch {
            Current.Log.error(
                "Failed to index Home Assistant entities for Spotlight (\(reason)): \(error)"
            )
        }
    }

    static func reindexAfterAppEntityCacheUpdate(serverId: String, serverName: String?) async {
        do {
            async let lightSummary = HAIndexedLightEntitySpotlightIndexer().reindexPrimaryLights()
            async let entitySummary = HAIndexedHomeAssistantEntitySpotlightIndexer().reindexPrimaryEntities()
            let summaries = try await (lightSummary, entitySummary)
            Current.Log.info(
                "Indexed \(summaries.0.indexedCount) Home Assistant lights and "
                    + "\(summaries.1.indexedCount) other entities for Spotlight after app entity cache update"
                    + serverLogSuffix(serverId: serverId, serverName: serverName)
            )
        } catch {
            Current.Log.error(
                "Failed to index Home Assistant entities for Spotlight"
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

@available(iOS 18.0, *)
enum HAIndexedLightEntityIndexingCoordinator {
    static func indexAvailableLights(reason: String) async {
        await HAIndexedEntityIndexingCoordinator.indexAvailableEntities(reason: reason)
    }

    static func reindexAfterAppEntityCacheUpdate(serverId: String, serverName: String?) async {
        await HAIndexedEntityIndexingCoordinator.reindexAfterAppEntityCacheUpdate(
            serverId: serverId,
            serverName: serverName
        )
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
