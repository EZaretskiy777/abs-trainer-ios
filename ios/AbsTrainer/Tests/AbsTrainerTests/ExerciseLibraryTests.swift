import XCTest
@testable import AbsTrainer

final class ExerciseLibraryTests: XCTestCase {
    func testVideoFrameCoverStartsVisibleUntilFirstRealFrame() {
        var cover = ExerciseVideoFrameCover()

        XCTAssertTrue(cover.isVisible)

        cover.recordPresentedFrame()

        XCTAssertFalse(cover.isVisible)
    }

    func testVideoFrameCoverReturnsForLooperItemUntilItsFirstRealFrame() {
        var cover = ExerciseVideoFrameCover()
        cover.recordPresentedFrame()

        cover.awaitNextFrame()

        XCTAssertTrue(cover.isVisible)

        cover.recordPresentedFrame()

        XCTAssertFalse(cover.isVisible)
    }

    func testVideoFrameCoverPreservesPresentedHistoryAcrossLooperHandoff() {
        var cover = ExerciseVideoFrameCover()
        XCTAssertFalse(cover.hasPresentedFrame)
        cover.recordPresentedFrame()

        cover.awaitNextFrame()

        XCTAssertTrue(cover.hasPresentedFrame)
    }

    func testLocalContentCoversStarterCatalogInStableOrder() {
        XCTAssertEqual(
            ExerciseLibraryContentCatalog.local.map(\.exerciseID),
            ExerciseCatalog.starter.map(\.id)
        )
        XCTAssertTrue(ExerciseLibraryContentCatalog.local.allSatisfy {
            $0.phases.count == 3 && $0.cues.count == 2
        })
    }

    func testSearchTrimsAndIgnoresCaseAndDiacritics() {
        let results = ExerciseLibraryQuery.filter(
            ExerciseCatalog.starter,
            query: "  МЕРТВЫЙ  ",
            zone: nil,
            difficulty: nil
        )

        XCTAssertEqual(results.map(\.id), ["dead_bug"])
    }

    func testSearchZoneAndDifficultyAreIntersectedWithoutChangingCatalogOrder() {
        let results = ExerciseLibraryQuery.filter(
            ExerciseCatalog.starter,
            query: "",
            zone: .obliques,
            difficulty: .intermediate
        )

        XCTAssertEqual(results.map(\.id), ["bicycle_twist", "russian_twist"])
    }

    func testFullZoneFilterIsExactAndDoesNotMeanAllExercises() {
        let results = ExerciseLibraryQuery.filter(
            ExerciseCatalog.starter,
            query: "",
            zone: .full,
            difficulty: nil
        )

        XCTAssertEqual(
            results.map(\.id),
            ["bicycle_twist", "plank", "mountain_climber", "dead_bug", "hollow_hold"]
        )
    }

    func testResetFilterRestoresAllStarterExercises() {
        var filter = ExerciseLibraryFilter(
            query: "нет совпадений",
            zone: .upper,
            difficulty: .beginner
        )

        filter.reset()

        XCTAssertEqual(filter, .default)
        XCTAssertEqual(filter.apply(to: ExerciseCatalog.starter), ExerciseCatalog.starter)
    }

    func testStarterMediaUsesValidatedRuntimeNamingContract() {
        XCTAssertTrue(ExerciseCatalog.starter.allSatisfy { exercise in
            exercise.mediaName == "exercise_\(exercise.id)_v1"
                && exercise.isPlaceholderMedia == false
        })
    }

    func testRuntimeManifestMakesEveryStarterExerciseAndMediaPairAvailable() {
        XCTAssertEqual(ExerciseMediaRepository.availableExercises(), ExerciseCatalog.starter)
        for exercise in ExerciseCatalog.starter {
            XCTAssertNotNil(ExerciseMediaRepository.videoURL(for: exercise), exercise.id)
            XCTAssertNotNil(ExerciseMediaRepository.posterURL(for: exercise), exercise.id)
        }
    }
}
