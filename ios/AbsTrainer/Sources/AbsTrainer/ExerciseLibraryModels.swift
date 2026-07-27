import CryptoKit
import Foundation

struct ExerciseLibraryContent: Equatable, Identifiable {
    let exerciseID: String
    let phases: [String]
    let cues: [String]

    var id: String { exerciseID }
    var posterName: String { "exercise_\(exerciseID)_poster_v1" }
}

enum ExerciseLibraryContentCatalog {
    static let disclaimer = "Демонстрация носит ознакомительный характер. Выбирайте комфортную амплитуду и остановитесь, если движение вызывает дискомфорт."

    static let local: [ExerciseLibraryContent] = [
        ExerciseLibraryContent(
            exerciseID: "crunch",
            phases: [
                "Лягте, согните колени, поставьте стопы.",
                "На выдохе приподнимите плечи, направляя рёбра к тазу.",
                "Плавно опустите плечи."
            ],
            cues: [
                "Сохраняйте шею продолжением спины.",
                "Поясница остаётся в комфортном контакте с опорой."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "reverse_crunch",
            phases: [
                "Лягте, поднимите согнутые ноги.",
                "Подведите колени к корпусу и слегка приподнимите таз.",
                "Контролируемо верните таз и ноги."
            ],
            cues: ["Не разгоняйте ноги.", "Сохраняйте движение небольшим и плавным."]
        ),
        ExerciseLibraryContent(
            exerciseID: "bicycle_twist",
            phases: [
                "Лягте, поднимите согнутые ноги и плечи.",
                "Поверните корпус к противоположному колену, вытягивая другую ногу.",
                "Через центр смените сторону."
            ],
            cues: [
                "Поворачивайте корпус, не тяните голову рукой.",
                "Двигайтесь в ровном темпе без рывка."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "plank",
            phases: [
                "Поставьте предплечья под плечами.",
                "Вытяните ноги и соберите корпус в одну линию.",
                "Удерживайте положение до конца интервала."
            ],
            cues: [
                "Направляйте макушку вперёд, пятки назад.",
                "Выберите положение колен как упрощение, если так комфортнее."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "mountain_climber",
            phases: [
                "Примите упор на ладонях.",
                "Подведите одно колено к корпусу.",
                "Верните ногу и смените сторону."
            ],
            cues: [
                "Ладони остаются под плечами.",
                "Сохраняйте темп, при котором корпус не раскачивается резко."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "toe_touch",
            phases: [
                "Лягте и поднимите ноги вверх с комфортным сгибом.",
                "Потянитесь руками в сторону стоп, приподнимая плечи.",
                "Плавно верните плечи на опору."
            ],
            cues: [
                "Не прижимайте подбородок к груди.",
                "Достаточна небольшая амплитуда подъёма."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "leg_raise",
            phases: [
                "Лягте, вытяните ноги или слегка согните колени.",
                "Поднимите ноги до комфортного угла.",
                "Медленно опустите, не бросая их на опору."
            ],
            cues: [
                "Уменьшите амплитуду, если поясница теряет комфортное положение.",
                "Не используйте инерцию."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "russian_twist",
            phases: [
                "Сядьте с согнутыми коленями и слегка отклоните корпус.",
                "Поверните грудную клетку в одну сторону.",
                "Через центр повернитесь в другую."
            ],
            cues: [
                "Стопы могут оставаться на полу.",
                "Поворот идёт всем корпусом без резкого движения рук."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "dead_bug",
            phases: [
                "Лягте, поднимите руки и согнутые ноги.",
                "Вытяните противоположные руку и ногу.",
                "Вернитесь в центр и смените сторону."
            ],
            cues: [
                "Двигайтесь медленно и сохраняйте корпус устойчивым.",
                "Укоротите траекторию конечностей при необходимости."
            ]
        ),
        ExerciseLibraryContent(
            exerciseID: "hollow_hold",
            phases: [
                "Лягте и приподнимите плечи.",
                "Поднимите согнутые или вытянутые ноги до комфортной высоты.",
                "Удерживайте компактное положение."
            ],
            cues: [
                "Согнутые колени — допустимое упрощение.",
                "Не увеличивайте амплитуду ценой контролируемого положения корпуса."
            ]
        )
    ]

    static let byID = Dictionary(uniqueKeysWithValues: local.map { ($0.exerciseID, $0) })
}

struct ExerciseLibraryFilter: Equatable {
    var query = ""
    var zone: AbsZone?
    var difficulty: Difficulty?

    static let `default` = ExerciseLibraryFilter()

    mutating func reset() {
        self = .default
    }

    func apply(to exercises: [Exercise]) -> [Exercise] {
        ExerciseLibraryQuery.filter(
            exercises,
            query: query,
            zone: zone,
            difficulty: difficulty
        )
    }
}

enum ExerciseLibraryQuery {
    static func filter(
        _ exercises: [Exercise],
        query: String,
        zone: AbsZone?,
        difficulty: Difficulty?
    ) -> [Exercise] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises.filter { exercise in
            let titleMatches = normalizedQuery.isEmpty || exercise.title.range(
                of: normalizedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "ru_RU")
            ) != nil
            let zoneMatches = zone.map(exercise.zones.contains) ?? true
            let difficultyMatches = difficulty.map { exercise.difficulty == $0 } ?? true
            return titleMatches && zoneMatches && difficultyMatches
        }
    }
}

extension Difficulty: Identifiable {
    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Начальный"
        case .intermediate: return "Средний"
        case .advanced: return "Продвинутый"
        }
    }
}

struct ExerciseAssetManifest: Decodable {
    struct Asset: Decodable {
        struct File: Decodable {
            let path: String
            let sha256: String
        }

        let exerciseID: String
        let catalogMediaName: String
        let video: File
        let poster: File

        enum CodingKeys: String, CodingKey {
            case exerciseID = "exercise_id"
            case catalogMediaName = "catalog_media_name"
            case video
            case poster
        }
    }

    let schemaVersion: Int
    let catalog: String
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case catalog
        case assets
    }
}

enum ExerciseMediaRepository {
    static let resourceDirectory = "ExerciseMedia"

    private struct Inventory {
        let catalogIsValid: Bool
        let validVideoIDs: Set<String>
        let validPosterIDs: Set<String>
    }

    private static let inventory: Inventory = {
        guard let manifestURL = Bundle.main.url(
            forResource: "exercise-assets",
            withExtension: "json",
            subdirectory: resourceDirectory
        ),
        let data = try? Data(contentsOf: manifestURL),
        let manifest = try? JSONDecoder().decode(ExerciseAssetManifest.self, from: data),
        manifest.schemaVersion == 1,
        manifest.catalog == "ExerciseCatalog.starter",
        manifest.assets.count == ExerciseCatalog.starter.count,
        Set(manifest.assets.map(\.exerciseID)) == Set(ExerciseCatalog.starter.map(\.id)),
        Set(manifest.assets.map(\.catalogMediaName)) == Set(ExerciseCatalog.starter.map(\.mediaName)) else {
            return Inventory(catalogIsValid: false, validVideoIDs: [], validPosterIDs: [])
        }

        var validVideoIDs: Set<String> = []
        var validPosterIDs: Set<String> = []
        for asset in manifest.assets where asset.catalogMediaName == "exercise_\(asset.exerciseID)_v1" {
            if let videoURL = bundledURL(for: asset.catalogMediaName, extension: "mp4"),
               checksum(of: videoURL) == asset.video.sha256 {
                validVideoIDs.insert(asset.exerciseID)
            }
            if let posterURL = bundledURL(
                for: "exercise_\(asset.exerciseID)_poster_v1",
                extension: "jpg"
            ), checksum(of: posterURL) == asset.poster.sha256 {
                validPosterIDs.insert(asset.exerciseID)
            }
        }
        return Inventory(
            catalogIsValid: true,
            validVideoIDs: validVideoIDs,
            validPosterIDs: validPosterIDs
        )
    }()

    static func videoURL(for exercise: Exercise) -> URL? {
        guard inventory.validVideoIDs.contains(exercise.id) else { return nil }
        return bundledURL(for: exercise.mediaName, extension: "mp4")
    }

    static func posterURL(for exercise: Exercise) -> URL? {
        guard inventory.validPosterIDs.contains(exercise.id) else { return nil }
        return bundledURL(for: "exercise_\(exercise.id)_poster_v1", extension: "jpg")
    }

    private static func bundledURL(for name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: resourceDirectory
        )
    }

    static func availableExercises() -> [Exercise] {
        guard inventory.catalogIsValid else { return [] }
        return ExerciseCatalog.starter.filter {
            ExerciseLibraryContentCatalog.byID[$0.id] != nil
        }
    }

    private static func checksum(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
