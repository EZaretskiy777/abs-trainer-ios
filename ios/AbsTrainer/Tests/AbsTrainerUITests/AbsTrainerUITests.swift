import UIKit
import XCTest

final class AbsTrainerUITests: XCTestCase {
    private let tolerance: CGFloat = 2
    private let maximumFinishPrimaryHeight: CGFloat = 96
    private let maximumAX3FinishPrimaryHeight: CGFloat = 120

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testFiveStateFlowCapturesReferenceScreens() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))

        attachScreenshot(named: "01-setup")
        navigateToSession(in: app, planScreenshotName: "plan-transition")

        XCTAssertTrue(app.buttons["Поставить тренировку на паузу"].waitForExistence(timeout: 5))
        attachScreenshot(named: "02-active")
        app.buttons["session.exit"].tap()
        let exitConfirmation = app.descendants(matching: .any)["session.confirmation.exit"]
        XCTAssertTrue(exitConfirmation.waitForExistence(timeout: 3))
        attachScreenshot(named: "05-confirmation")
        app.buttons["session.confirmation.exit.cancel"].tap()

        var capturedRest = false
        for _ in 0..<100 {
            let skipRest = app.buttons["Пропустить отдых"]
            if skipRest.waitForExistence(timeout: 1) {
                if !capturedRest {
                    attachScreenshot(named: "03-rest")
                    capturedRest = true
                }
                skipRest.tap()
                continue
            }

            let finish = app.buttons["Завершить"]
            if finish.exists {
                finish.tap()
                let confirmation = app.descendants(matching: .any)["session.confirmation.finishEarly"]
                XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
                app.buttons["session.confirmation.finishEarly.destructive"].tap()
                break
            }

            let finishSet = app.buttons["Завершить набор"]
            if finishSet.exists {
                finishSet.tap()
                let confirmation = app.descendants(matching: .any)["session.confirmation.finishSetEarly"]
                XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
                app.buttons["session.confirmation.finishSetEarly.destructive"].tap()
                if app.descendants(matching: .any)["finish.title"].waitForExistence(timeout: 0.5) { break }
                continue
            }

            let confirmSet = app.buttons["Подтвердить набор"]
            if confirmSet.exists {
                confirmSet.tap()
                if app.descendants(matching: .any)["finish.title"].waitForExistence(timeout: 0.5) { break }
                continue
            }

            let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Далее'")).firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            next.tap()
        }

        XCTAssertTrue(capturedRest)
        XCTAssertTrue(app.descendants(matching: .any)["finish.title"].waitForExistence(timeout: 5))
        attachScreenshot(named: "04-finish")
    }

    @MainActor
    func testSetupFocusIntensityAndPlanSnapshotContract() throws {
        let app = launchApp(viewport: CGSize(width: 440, height: 956))
        let full = app.buttons["setup.zone.full"]
        let upper = app.buttons["setup.zone.upper"]
        let lower = app.buttons["setup.zone.lower"]
        let light = app.buttons["setup.intensity.light"]
        let balanced = app.buttons["setup.intensity.balanced"]
        let high = app.buttons["setup.intensity.high"]
        let setup = app.buttons["Собрать тренировку"]

        XCTAssertTrue(full.waitForExistence(timeout: 5))
        XCTAssertEqual(full.value as? String, "Выбрано")
        XCTAssertTrue(balanced.waitForExistence(timeout: 5))
        XCTAssertEqual(balanced.value as? String, "Выбрано")
        XCTAssertEqual(light.value as? String, "Не выбрано")

        let visibleFrame = visibleFrame(above: setup, in: app.windows.firstMatch)
        let setupScroll = app.scrollViews["setup.scroll"]
        XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
        scrollIntoView([upper, lower], in: app, visibleFrame: visibleFrame, scrollSurface: setupScroll)
        tapAndWaitForValue(upper, value: "Выбрано")
        tapAndWaitForValue(lower, value: "Выбрано")
        XCTAssertEqual(full.value as? String, "Не выбрано")
        XCTAssertEqual(upper.value as? String, "Выбрано")
        XCTAssertEqual(lower.value as? String, "Выбрано")

        scrollIntoView([high], in: app, visibleFrame: visibleFrame, scrollSurface: setupScroll)
        XCTAssertTrue(high.isHittable)
        assertContained(high.frame, in: visibleFrame)
        tapAndWaitForValue(high, value: "Выбрано")
        XCTAssertEqual(balanced.value as? String, "Не выбрано")
        attachScreenshot(named: "01-setup-intensity-selection")
        setup.tap()

        let summary = app.descendants(matching: .any)["plan.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("10 минут"))
        XCTAssertTrue(summary.label.contains("верхний"))
        XCTAssertTrue(summary.label.contains("нижний"))
        XCTAssertTrue(summary.label.contains("высокая интенсивность"))

        app.buttons["Назад к настройке"].tap()
        XCTAssertTrue(high.waitForExistence(timeout: 3))
        XCTAssertEqual(high.value as? String, "Выбрано")
        XCTAssertEqual(upper.value as? String, "Выбрано")
        XCTAssertEqual(lower.value as? String, "Выбрано")
    }

    @MainActor
    func testPauseResumeAccessibilityOrderAndFocusReturn() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))
        navigateToSession(in: app)

        let pause = app.buttons["session.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertTrue(pause.isHittable)
        pause.tap()

        let title = app.staticTexts["pause.dialog.title"]
        let message = app.staticTexts["pause.dialog.message"]
        let resume = app.buttons["pause.resume"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertTrue(message.exists)
        XCTAssertTrue(resume.exists)
        XCTAssertTrue(resume.isHittable)
        XCTAssertLessThan(title.frame.maxY, message.frame.minY)
        XCTAssertLessThan(message.frame.maxY, resume.frame.minY)
        XCTAssertFalse(app.buttons["session.pause"].isHittable, "Modal state must prevent interaction with background controls")

        let pausedFocusProbe = app.descendants(matching: .any)["validation.ax.focus.pauseDialog"].firstMatch
        XCTAssertTrue(pausedFocusProbe.waitForExistence(timeout: 3))
        let hierarchy = app.debugDescription
        assertOrder(["pause.dialog.title", "pause.dialog.message", "pause.resume"], in: hierarchy)
        attachScreenshot(named: "08-pause-modal-ax-order")

        resume.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        XCTAssertTrue(pause.isHittable)
        let resumedFocusProbe = app.descendants(matching: .any)["validation.ax.focus.pauseButton"].firstMatch
        XCTAssertTrue(resumedFocusProbe.waitForExistence(timeout: 3))
    }

    @MainActor
    func testCriticalStatesFitCompact320By568And393By852() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852)] {
            let app = launchApp(viewport: size)
            let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch
            XCTAssertTrue(viewport.waitForExistence(timeout: 5))
            XCTAssertEqual(viewport.frame.width, size.width, accuracy: tolerance)
            XCTAssertEqual(viewport.frame.height, size.height, accuracy: tolerance)
            assertFiveStateGeometry(
                in: app,
                container: viewport,
                screenshotPrefix: "viewport-\(Int(size.width))x\(Int(size.height))"
            )
            app.terminate()
        }
    }

    @MainActor
    func testCriticalStatesFitIPhone17ProMaxPortraitEquivalent() throws {
        let size = CGSize(width: 440, height: 956)
        let app = launchApp(viewport: size)
        let window = app.windows.firstMatch
        let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch

        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertEqual(window.frame.width, size.width, accuracy: tolerance)
        XCTAssertEqual(window.frame.height, size.height, accuracy: tolerance)
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        XCTAssertEqual(viewport.frame.width, size.width, accuracy: tolerance)
        XCTAssertEqual(viewport.frame.height, size.height, accuracy: tolerance)
        assertFiveStateGeometry(in: app, container: viewport, screenshotPrefix: "iphone-17-pro-max-portrait")
    }

    @MainActor
    func testAccessibility3PortraitAndLandscapeGeometry() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 320, height: 568)] {
            let app = launchApp(
                viewport: size,
                contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
            )
            let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch
            let dynamicType = app.descendants(matching: .any)["validation.dynamicType"].firstMatch
            XCTAssertTrue(viewport.waitForExistence(timeout: 5))
            XCTAssertEqual(viewport.frame.width, size.width, accuracy: tolerance)
            XCTAssertEqual(viewport.frame.height, size.height, accuracy: tolerance)
            XCTAssertTrue(dynamicType.waitForExistence(timeout: 3))
            XCTAssertEqual(dynamicType.value as? String, "accessibility3")
            assertFiveStateGeometry(
                in: app,
                container: viewport,
                screenshotPrefix: "ax3-portrait-\(Int(size.width))x\(Int(size.height))"
            )
            app.terminate()
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscapeApp = launchApp(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        let window = landscapeApp.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(window.frame.width, window.frame.height)
        assertFiveStateGeometry(
            in: landscapeApp,
            container: window,
            screenshotPrefix: "ax3-landscape",
            setupControlScrollDragStartY: 0.65,
            setupControlScrollDragEndY: 0.35,
            setupControlScrollDragVelocity: .slow
        )
        landscapeApp.terminate()
    }

    @MainActor
    func testAccessibility3ChangesRenderedSetupPixelsAndReflowsTitle() throws {
        let size = CGSize(width: 393, height: 852)
        let defaultApp = launchApp(viewport: size)
        let defaultTitle = defaultApp.staticTexts["setup.title"]
        let defaultViewport = defaultApp.descendants(matching: .any)["validation.viewport"].firstMatch
        XCTAssertTrue(defaultTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(defaultViewport.waitForExistence(timeout: 3))
        waitForVisualStability()
        let defaultFrame = defaultTitle.frame
        let defaultViewportFrame = defaultViewport.frame
        let defaultScreenshot = XCUIScreen.main.screenshot()
        defaultApp.terminate()

        let ax3App = launchApp(
            viewport: size,
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        let ax3Title = ax3App.staticTexts["setup.title"]
        let dynamicType = ax3App.descendants(matching: .any)["validation.dynamicType"].firstMatch
        XCTAssertTrue(ax3Title.waitForExistence(timeout: 5))
        XCTAssertTrue(dynamicType.waitForExistence(timeout: 3))
        XCTAssertEqual(dynamicType.value as? String, "accessibility3")
        waitForVisualStability()
        let ax3Screenshot = XCUIScreen.main.screenshot()
        let ratio = pixelMismatchRatio(
            baseline: defaultScreenshot,
            candidate: ax3Screenshot,
            crop: defaultViewportFrame.insetBy(dx: 8, dy: 48),
            channelThreshold: 12
        )
        XCTAssertGreaterThan(
            ax3Title.frame.height,
            defaultFrame.height,
            "AX3 must visibly enlarge or reflow the rendered setup title"
        )
        XCTAssertGreaterThan(ratio, 0.01, "AX3 rendered pixels must differ from the default category")
        attach(defaultScreenshot, named: "dynamic-type-default-393x852")
        attach(ax3Screenshot, named: "dynamic-type-ax3-393x852-ratio-\(String(format: "%.5f", ratio))")
    }

    @MainActor
    func testDeterministicSetupSnapshotWithinPixelThreshold() throws {
        let size = CGSize(width: 393, height: 852)
        let app = launchApp(viewport: size)
        XCTAssertTrue(app.buttons["Собрать тренировку"].waitForExistence(timeout: 5))
        waitForVisualStability()
        let baseline = XCUIScreen.main.screenshot()
        let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 3))
        let viewportFrame = viewport.frame
        app.terminate()

        let replay = launchApp(viewport: size)
        XCTAssertTrue(replay.buttons["Собрать тренировку"].waitForExistence(timeout: 5))
        waitForVisualStability()
        let candidate = XCUIScreen.main.screenshot()
        let ratio = pixelMismatchRatio(
            baseline: baseline,
            candidate: candidate,
            crop: viewportFrame.insetBy(dx: 8, dy: 48),
            channelThreshold: 12
        )
        XCTAssertLessThanOrEqual(ratio, 0.015, "Deterministic snapshot mismatch ratio \(ratio) exceeds 1.5%")
        attach(baseline, named: "snapshot-baseline-393x852")
        attach(candidate, named: "snapshot-candidate-393x852-ratio-\(String(format: "%.5f", ratio))")
    }

    @MainActor
    func testDurationDialStepControlsPreserveAllowedValuesAndEndpointStates() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))
        let dial = app.descendants(matching: .any)["setup.durationDial"]
        let decrement = app.buttons["setup.durationDial.decrement"]
        let increment = app.buttons["setup.durationDial.increment"]

        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        XCTAssertEqual(dial.value as? String, "10 минут")
        XCTAssertTrue(decrement.isEnabled)
        XCTAssertTrue(increment.isEnabled)

        increment.tap()
        XCTAssertEqual(dial.value as? String, "11 минут")
        XCTAssertTrue(increment.isEnabled)

        decrement.tap()
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "9 минут")
        XCTAssertTrue(decrement.isEnabled)
        XCTAssertTrue(increment.isEnabled)
        attachScreenshot(named: "duration-dial-one-minute-step")
    }

    @MainActor
    func testDurationDialTapAndDragSnapToAllowedValues() throws {
        let app = launchApp(viewport: CGSize(width: 440, height: 956))
        let dial = app.descendants(matching: .any)["setup.durationDial"]
        let setup = app.buttons["Собрать тренировку"]
        let setupScroll = app.scrollViews["setup.scroll"]
        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
        scrollIntoView(
            [dial],
            in: app,
            visibleFrame: visibleFrame(above: setup, in: app.windows.firstMatch),
            scrollSurface: setupScroll
        )
        XCTAssertTrue(dial.isHittable)

        dialPoint(.minimum, in: dial).tap()
        XCTAssertEqual(dial.value as? String, "5 минут")
        dialPoint(.midpoint, in: dial).tap()
        XCTAssertEqual(dial.value as? String, "10 минут")
        dialPoint(.maximum, in: dial).tap()
        XCTAssertEqual(dial.value as? String, "15 минут")
        attachScreenshot(named: "duration-dial-tap-maximum")

        dialPoint(.maximum, in: dial).press(
            forDuration: 0.1,
            thenDragTo: dialPoint(.minimum, in: dial)
        )
        XCTAssertEqual(dial.value as? String, "5 минут")
        attachScreenshot(named: "duration-dial-drag-minimum")
    }

    @MainActor
    func testSetupZoneHitTargetsRemainInteractiveAtCompactAndStandardWidths() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852)] {
            let app = launchApp(viewport: size)
            let upper = app.buttons["setup.zone.upper"]
            let setup = app.buttons["Собрать тренировку"]
            let setupScroll = app.scrollViews["setup.scroll"]

            XCTAssertTrue(upper.waitForExistence(timeout: 5))
            XCTAssertTrue(setup.waitForExistence(timeout: 5))
            XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
            let visible = visibleFrame(above: setup, in: app.windows.firstMatch)
            scrollIntoView([upper], in: app, visibleFrame: visible, scrollSurface: setupScroll)
            XCTAssertTrue(upper.isHittable)
            assertContained(upper.frame, in: visible)
            XCTAssertGreaterThanOrEqual(upper.frame.width, 44)
            XCTAssertGreaterThanOrEqual(upper.frame.height, 44)

            upper.tap()
            XCTAssertTrue(wait(for: NSPredicate(format: "value == %@", "Выбрано"), object: upper, timeout: 2))
            attachScreenshot(named: "setup-zone-hit-target-\(Int(size.width))x\(Int(size.height))")
            app.terminate()
        }
    }

    @MainActor
    func testDurationDialAdjustableIncrementAndDecrementPreserveContract() throws {
        let app = launchApp(viewport: CGSize(width: 440, height: 956))
        let dial = app.descendants(matching: .any)["setup.durationDial"]
        let increment = app.buttons["validation.durationDial.adjustable.increment"]
        let decrement = app.buttons["validation.durationDial.adjustable.decrement"]

        XCTAssertTrue(dial.waitForExistence(timeout: 5))
        XCTAssertTrue(increment.waitForExistence(timeout: 2))
        XCTAssertTrue(decrement.waitForExistence(timeout: 2))
        XCTAssertTrue(increment.isHittable)
        XCTAssertTrue(decrement.isHittable)
        XCTAssertEqual(dial.value as? String, "10 минут")

        increment.tap()
        XCTAssertEqual(dial.value as? String, "11 минут")
        increment.tap()
        XCTAssertEqual(dial.value as? String, "12 минут")
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "11 минут")
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "10 минут")
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "9 минут")
        attachScreenshot(named: "duration-dial-adjustable-one-minute-step")
    }

    @MainActor
    func testExitConfirmationUsesSafeDefaultAndRestoresOpenerFocus() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))
        navigateToSession(in: app)

        let exit = app.buttons["session.exit"]
        XCTAssertTrue(exit.waitForExistence(timeout: 5))
        exit.tap()

        let modal = app.descendants(matching: .any)["session.confirmation.exit"]
        let title = app.staticTexts["session.confirmation.exit.title"]
        let message = app.staticTexts["session.confirmation.exit.message"]
        let cancel = app.buttons["session.confirmation.exit.cancel"]
        let destructive = app.buttons["session.confirmation.exit.destructive"]
        XCTAssertTrue(modal.waitForExistence(timeout: 3))
        XCTAssertTrue(cancel.isHittable)
        XCTAssertTrue(destructive.isHittable)
        XCTAssertLessThan(title.frame.maxY, message.frame.minY)
        XCTAssertLessThan(message.frame.maxY, cancel.frame.minY)
        XCTAssertLessThan(cancel.frame.maxY, destructive.frame.minY)
        XCTAssertFalse(app.buttons["session.pause"].isHittable)
        attachScreenshot(named: "session-exit-confirmation")

        cancel.tap()
        XCTAssertTrue(exit.waitForExistence(timeout: 3))
        XCTAssertTrue(exit.isHittable)
        let focusProbe = app.descendants(matching: .any)["validation.ax.focus.exitButton"].firstMatch
        XCTAssertTrue(focusProbe.waitForExistence(timeout: 3))
    }

    @MainActor
    func testExerciseLibrarySearchFiltersDetailAndSetupState() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))
        let upperSetup = app.buttons["setup.zone.upper"]
        let setup = app.buttons["Собрать тренировку"]
        let setupScroll = app.scrollViews["setup.scroll"]
        XCTAssertTrue(upperSetup.waitForExistence(timeout: 5))
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
        scrollIntoView(
            [upperSetup],
            in: app,
            visibleFrame: visibleFrame(above: setup, in: app.windows.firstMatch),
            scrollSurface: setupScroll
        )
        tapAndWaitForValue(upperSetup, value: "Выбрано")

        openExerciseLibrary(in: app)
        let count = app.staticTexts["exerciseLibrary.resultCount"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "10 упражнений")

        app.buttons["exerciseLibrary.zone.upper"].tap()
        app.buttons["exerciseLibrary.difficulty.beginner"].tap()
        XCTAssertEqual(count.label, "2 упражнения")

        let search = app.searchFields["Найти упражнение"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("Касания")
        XCTAssertEqual(count.label, "1 упражнение")
        attachScreenshot(named: "exercise-library-filtered")
        dismissKeyboard(in: app)

        let row = app.buttons["exerciseLibrary.row.toe_touch"]
        reveal(row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["exerciseDetail.screen.toe_touch"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["exerciseDetail.title"].exists)
        XCTAssertTrue(app.staticTexts["exerciseDetail.metadata"].label.contains("Начальный"))
        XCTAssertTrue(app.descendants(matching: .any)["exerciseDetail.phases"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["exerciseDetail.cues"].exists)
        let playbackProbe = app.descendants(matching: .any)["validation.exercisePlayback"]
        XCTAssertTrue(playbackProbe.waitForExistence(timeout: 3))
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "value BEGINSWITH %@", "state=playing;"),
                object: playbackProbe,
                timeout: 5
            ),
            "Local AVPlayer never reached actual playing state: \(String(describing: playbackProbe.value))"
        )
        let playingEvidence = try XCTUnwrap(playbackProbe.value as? String)
        XCTAssertTrue(
            playingEvidence.contains("states=poster,loading,ready,playing;"),
            "Playback probe did not observe the required local loading → ready → playing sequence: \(playingEvidence)"
        )
        attachScreenshot(named: "exercise-detail-playing")

        let backButton = app.buttons["BackButton"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
        XCTAssertEqual(count.label, "1 упражнение", "Live navigation stack must preserve library query and filters")
        closeSearch(in: app)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()
        XCTAssertTrue(upperSetup.waitForExistence(timeout: 3))
        XCTAssertEqual(upperSetup.value as? String, "Выбрано")
    }

    @MainActor
    func testExerciseDetailActualPlaybackCompletesLoopAndMeasuresStartupAt320By568() throws {
        let size = CGSize(width: 320, height: 568)
        let app = launchApp(viewport: size)
        let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        XCTAssertEqual(viewport.frame.width, size.width, accuracy: tolerance)
        XCTAssertEqual(viewport.frame.height, size.height, accuracy: tolerance)

        openExerciseLibrary(in: app)
        let row = app.buttons["exerciseLibrary.row.crunch"]
        reveal(row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()

        let playbackProbe = app.descendants(matching: .any)["validation.exercisePlayback"]
        XCTAssertTrue(playbackProbe.waitForExistence(timeout: 3))
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "value BEGINSWITH %@", "state=playing;"),
                object: playbackProbe,
                timeout: 5
            ),
            "Local AVPlayer never reached actual playing state: \(String(describing: playbackProbe.value))"
        )
        let playingEvidence = try XCTUnwrap(playbackProbe.value as? String)
        XCTAssertTrue(
            playingEvidence.contains("states=poster,loading,ready,playing;"),
            "Playback probe did not observe the required local loading → ready → playing sequence: \(playingEvidence)"
        )
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "value CONTAINS %@", "cover=video;"),
                object: playbackProbe,
                timeout: 3
            ),
            "Poster cover was removed before a real video frame became available: \(String(describing: playbackProbe.value))"
        )
        attachScreenshot(named: "exercise-detail-playing-320x568")

        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "value MATCHES %@", ".*loops=[1-9][0-9]*;.*"),
                object: playbackProbe,
                timeout: 7
            ),
            "AVPlayerLooper did not complete a full four-second loop: \(String(describing: playbackProbe.value))"
        )
        XCTAssertTrue(
            wait(
                for: NSPredicate(format: "value CONTAINS %@", "cover=video;covers=poster,video,poster,video"),
                object: playbackProbe,
                timeout: 3
            ),
            "Poster cover did not complete the first looper handoff: \(String(describing: playbackProbe.value))"
        )

        let evidence = try XCTUnwrap(playbackProbe.value as? String)
        let posterMilliseconds = try playbackMetric("posterMs", in: evidence)
        let videoMilliseconds = try playbackMetric("videoMs", in: evidence)
        let firstLoopMilliseconds = try playbackMetric("firstLoopMs", in: evidence)
        let interruptions = try playbackMetric("interruptions", in: evidence)
        XCTAssertTrue(
            evidence.contains("cover=video;covers=poster,video,poster,video"),
            "Poster cover did not protect the AVPlayerLooper handoff until its first real frame: \(evidence)"
        )
        XCTAssertGreaterThanOrEqual(posterMilliseconds, 0, "Poster timing was not measured: \(evidence)")
        XCTAssertGreaterThan(videoMilliseconds, 0, "Video timing was not measured: \(evidence)")
        XCTAssertGreaterThanOrEqual(videoMilliseconds, posterMilliseconds, "Video preceded poster: \(evidence)")
#if targetEnvironment(simulator)
        XCTAssertGreaterThanOrEqual(
            videoMilliseconds,
            posterMilliseconds,
            "Simulator must retain the measured video-start timestamp even though performance acceptance is device-only: \(evidence)"
        )
#else
        XCTAssertLessThanOrEqual(posterMilliseconds, 100, "Poster-first target exceeded: \(evidence)")
        XCTAssertLessThanOrEqual(videoMilliseconds, 500, "Local video-start target exceeded: \(evidence)")
#endif
        XCTAssertGreaterThanOrEqual(firstLoopMilliseconds, 3_500, "Observed loop was too short for the four-second asset: \(evidence)")
        XCTAssertLessThanOrEqual(firstLoopMilliseconds, 4_500, "Observed loop was too long for the four-second asset: \(evidence)")
        XCTAssertEqual(interruptions, 0, "Playback left actual playing state during the first loop: \(evidence)")
        attachScreenshot(named: "exercise-detail-loop-complete-320x568")
        let metrics = XCTAttachment(string: evidence)
        metrics.name = "exercise-detail-runtime-metrics-320x568"
        metrics.lifetime = .keepAlways
        add(metrics)
    }

    @MainActor
    func testExerciseLibraryNoResultsResetAndVideoFallback() throws {
        let app = launchApp(
            viewport: CGSize(width: 320, height: 700),
            extraArguments: ["-ExerciseMediaFailure", "-ExercisePosterFailure"]
        )
        openExerciseLibrary(in: app)

        let search = app.searchFields["Найти упражнение"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("нет такого упражнения")
        XCTAssertTrue(app.descendants(matching: .any)["exerciseLibrary.noResults"].waitForExistence(timeout: 3))
        attachScreenshot(named: "exercise-library-no-results-320x700")
        app.buttons["Сбросить фильтры"].tap()

        let row = app.buttons["exerciseLibrary.row.crunch"]
        reveal(row, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        let motion = app.descendants(matching: .any)["exerciseDetail.motion"]
        XCTAssertTrue(motion.waitForExistence(timeout: 3))
        XCTAssertEqual(motion.value as? String, "Анимация недоступна, показана резервная иллюстрация")
        let playbackProbe = app.descendants(matching: .any)["validation.exercisePlayback"]
        XCTAssertTrue(playbackProbe.waitForExistence(timeout: 3))
        let failureEvidence = try XCTUnwrap(playbackProbe.value as? String)
        XCTAssertTrue(failureEvidence.hasPrefix("state=failed;"), "Playback failure was not exposed: \(failureEvidence)")
        XCTAssertTrue(
            failureEvidence.contains("states=poster,failed;"),
            "Playback failure history was not deterministic: \(failureEvidence)"
        )
        XCTAssertTrue(app.descendants(matching: .any)["exerciseDetail.disclaimer"].exists)
        attachScreenshot(named: "exercise-detail-video-fallback-320x700")
    }

    @MainActor
    func testExerciseDetailReduceMotionAndAX3LandscapeRemainScrollable() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchApp(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            extraArguments: ["-ValidationReduceMotion", "YES"]
        )
        openExerciseLibrary(in: app)
        let row = app.buttons["exerciseLibrary.row.crunch"]
        let libraryScroll = app.scrollViews["exerciseLibrary.screen"]
        let search = app.searchFields["Найти упражнение"]
        XCTAssertTrue(libraryScroll.waitForExistence(timeout: 5))
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        let visibleLibraryFrame = visibleFrame(above: search, in: app.windows.firstMatch)
        scrollIntoSubstantialView(
            row,
            in: app,
            visibleFrame: visibleLibraryFrame,
            scrollSurface: libraryScroll,
            scrollDragX: 0.5
        )
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        assertScrollableContentVisible(row.frame, in: visibleLibraryFrame)
        // In AX3 landscape the row's center can sit under the navigation bar
        // even while XCTest reports the combined row as hittable. Tap the
        // visible lower portion so the assertion exercises the row itself.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()

        let detail = app.scrollViews["exerciseDetail.screen.crunch"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        let motion = app.descendants(matching: .any)["exerciseDetail.motion"]
        XCTAssertTrue(motion.waitForExistence(timeout: 3))
        XCTAssertEqual(motion.value as? String, "Статичная демонстрация")
        let detailScroll = app.scrollViews["exerciseDetail.screen.crunch"]
        XCTAssertTrue(detailScroll.waitForExistence(timeout: 3))
        let disclaimer = app.descendants(matching: .any)["exerciseDetail.disclaimer"]
        for _ in 0..<8 where !disclaimer.isHittable {
            detailScroll.swipeUp()
        }
        XCTAssertTrue(disclaimer.exists)
        XCTAssertTrue(disclaimer.isHittable)
        attachScreenshot(named: "exercise-detail-ax3-landscape-reduce-motion")
    }

    @MainActor
    func testAudioSettingsSummaryAndSessionMuteControl() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))
        let setupScroll = app.scrollViews["setup.scroll"]
        let setup = app.buttons["Собрать тренировку"]
        let music = app.switches["setup.audio.musicToggle"]
        let voice = app.switches["setup.audio.voiceToggle"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
        scrollIntoView(
            [music, voice],
            in: app,
            visibleFrame: visibleFrame(above: setup, in: app.windows.firstMatch),
            scrollSurface: setupScroll
        )
        XCTAssertTrue(music.isHittable)
        XCTAssertTrue(voice.exists)
        let initialMusicValue = music.value as? String
        music.tap()
        XCTAssertNotEqual(music.value as? String, initialMusicValue)

        setup.tap()
        XCTAssertTrue(app.descendants(matching: .any)["plan.audio.summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Изменить настройки звука тренировки"].waitForExistence(timeout: 3))
        app.buttons["Начать тренировку"].tap()

        let sessionAudio = app.buttons["session.audio.toggle"]
        XCTAssertTrue(sessionAudio.waitForExistence(timeout: 5))
        let initialSessionValue = sessionAudio.value as? String
        sessionAudio.tap()
        XCTAssertNotEqual(sessionAudio.value as? String, initialSessionValue)
    }

    @MainActor
    func testMusicTrackSelectionRemainsReachableAtCompactAndDynamicTypeViewports() throws {
        let configurations: [(CGSize, String?)] = [
            (CGSize(width: 393, height: 852), nil),
            (CGSize(width: 320, height: 568), "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        ]

        for (viewport, contentSizeCategory) in configurations {
            let app = launchApp(
                viewport: viewport,
                contentSizeCategory: contentSizeCategory,
                extraArguments: ["-ResetAudioPreferences"]
            )
            let setup = setupButton(in: app)
            let setupScroll = app.scrollViews["setup.scroll"]
            let trackChoices = [
                app.buttons["setup.audio.track.auto"],
                app.buttons["setup.audio.track.pulseGrid"],
                app.buttons["setup.audio.track.forwardArc"],
                app.buttons["setup.audio.track.groundedOrbit"]
            ]
            XCTAssertTrue(setup.waitForExistence(timeout: 5))
            XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
            let visible = visibleFrame(above: setup, in: app.windows.firstMatch)
            for choice in trackChoices {
                scrollIntoView([choice], in: app, visibleFrame: visible, scrollSurface: setupScroll)
                XCTAssertTrue(choice.exists)
                XCTAssertTrue(choice.isHittable)
                XCTAssertGreaterThanOrEqual(choice.frame.height, 44)
                assertContained(choice.frame, in: visible)
            }

            scrollIntoView([trackChoices[2]], in: app, visibleFrame: visible, scrollSurface: setupScroll)
            tapAndWaitForValue(trackChoices[2], value: "Выбрано")
            setup.tap()
            let summary = app.descendants(matching: .any)["plan.audio.summary"]
            XCTAssertTrue(summary.waitForExistence(timeout: 5))
            XCTAssertTrue(summary.label.contains("Forward Arc"))
            attachScreenshot(named: "music-forward-\(Int(viewport.width))x\(Int(viewport.height))")
            app.terminate()
        }
    }

    @MainActor
    func testAutoMusicAdvancesWithoutImmediateRepeatAcrossGeneratedWorkouts() throws {
        let app = launchApp(
            viewport: CGSize(width: 393, height: 852),
            extraArguments: ["-ResetAudioPreferences"]
        )
        let setup = setupButton(in: app)
        let setupScroll = app.scrollViews["setup.scroll"]
        let auto = app.buttons["setup.audio.track.auto"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        scrollIntoView(
            [auto],
            in: app,
            visibleFrame: visibleFrame(above: setup, in: app.windows.firstMatch),
            scrollSurface: setupScroll
        )
        tapAndWaitForValue(auto, value: "Выбрано")

        setup.tap()
        let firstSummary = app.descendants(matching: .any)["plan.audio.summary"]
        XCTAssertTrue(firstSummary.waitForExistence(timeout: 5))
        let firstTrack = firstSummary.label
        XCTAssertTrue(firstTrack.contains("Авто"))
        app.buttons["plan.audio.edit"].tap()

        let regeneratedSetup = setupButton(in: app)
        XCTAssertTrue(regeneratedSetup.waitForExistence(timeout: 5))
        regeneratedSetup.tap()
        let secondSummary = app.descendants(matching: .any)["plan.audio.summary"]
        XCTAssertTrue(secondSummary.waitForExistence(timeout: 5))
        XCTAssertTrue(secondSummary.label.contains("Авто"))
        XCTAssertNotEqual(secondSummary.label, firstTrack)
        attachScreenshot(named: "music-auto-second-workout-393x852")
    }

    @MainActor
    func testAllThreeTracksReachActualSimulatorPlaybackRuntime() throws {
        let tracks = [
            ("pulseGrid", "Pulse Grid"),
            ("forwardArc", "Forward Arc"),
            ("groundedOrbit", "Grounded Orbit")
        ]

        for (identifier, title) in tracks {
            let app = launchApp(
                viewport: CGSize(width: 393, height: 852),
                extraArguments: ["-ResetAudioPreferences", "-AudioRuntimeProbe"]
            )
            let setup = setupButton(in: app)
            let setupScroll = app.scrollViews["setup.scroll"]
            let music = app.switches["setup.audio.musicToggle"]
            let track = app.buttons["setup.audio.track.\(identifier)"]
            XCTAssertTrue(setup.waitForExistence(timeout: 5))
            let visible = visibleFrame(above: setup, in: app.windows.firstMatch)
            scrollIntoView([music, track], in: app, visibleFrame: visible, scrollSurface: setupScroll)
            if music.value as? String != "1" { music.tap() }
            tapAndWaitForValue(track, value: "Выбрано")
            setup.tap()
            XCTAssertTrue(app.buttons["Начать тренировку"].waitForExistence(timeout: 5))
            app.buttons["Начать тренировку"].tap()

            let runtimeTrack = app.descendants(matching: .any)["session.audio.track"]
            XCTAssertTrue(runtimeTrack.waitForExistence(timeout: 5))
            XCTAssertEqual(runtimeTrack.label, "Музыка · \(title)")
            XCTAssertEqual(runtimeTrack.value as? String, "Воспроизводится")
            attachScreenshot(named: "music-runtime-\(identifier)-393x852")
            app.terminate()
        }
    }

    @MainActor
    func testMobbinAuditSetupPlanAndActiveContracts() throws {
        let app = launchApp(viewport: CGSize(width: 393, height: 852))

        let preset = app.descendants(matching: .any)["setup.presetSummary"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        XCTAssertTrue(preset.label.contains("Pulse Grid готов"))

        app.buttons["Собрать тренировку"].tap()
        let firstExercise = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'plan.row.exercise.'")
        ).firstMatch
        let firstRest = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'plan.row.rest.'")
        ).firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 5))
        XCTAssertTrue(firstRest.waitForExistence(timeout: 3))
        XCTAssertTrue(firstRest.label.localizedCaseInsensitiveContains("отдых"))

        firstExercise.tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH 'exerciseDetail.screen.'")
            ).firstMatch.waitForExistence(timeout: 3)
        )
        app.buttons["BackButton"].tap()

        app.buttons["Начать тренировку"].tap()
        let progress = app.descendants(matching: .any)["session.active.progress"]
        let nextCard = app.descendants(matching: .any)["session.active.nextCard"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("из"))
        XCTAssertTrue(nextCard.waitForExistence(timeout: 3))
        XCTAssertTrue(nextCard.label.localizedCaseInsensitiveContains("дальше"))
        attachScreenshot(named: "mobbin-audit-active-393x852")
    }

    @MainActor
    func testPlanCanonicalTitlesRemainCompleteAtStandardAndCompactViewports() throws {
        let configurations: [(name: String, size: CGSize, category: String?)] = [
            ("default", CGSize(width: 393, height: 852), nil),
            ("default", CGSize(width: 320, height: 568), nil),
            ("ax3", CGSize(width: 393, height: 852), "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"),
            ("ax3", CGSize(width: 320, height: 568), "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        ]
        for configuration in configurations {
            let size = configuration.size
            let app = launchApp(viewport: size, contentSizeCategory: configuration.category)
            let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch
            let setup = setupButton(in: app)
            XCTAssertTrue(viewport.waitForExistence(timeout: 5))
            XCTAssertTrue(setup.waitForExistence(timeout: 5))
            setup.tap()

            let row = app.buttons["plan.row.exercise.bicycle_twist"]
            let planScroll = app.scrollViews["plan.scroll"]
            XCTAssertTrue(planScroll.waitForExistence(timeout: 5))
            for _ in 0..<8 where !row.exists {
                planScroll.swipeUp()
            }
            XCTAssertTrue(row.waitForExistence(timeout: 3))
            scrollIntoSubstantialView(
                row,
                in: app,
                visibleFrame: viewport.frame,
                scrollSurface: planScroll,
                scrollDragX: 0.5
            )
            XCTAssertTrue(row.exists)
            XCTAssertTrue(row.label.contains("Велосипед с поворотом"), "Canonical title must not be abbreviated")
            XCTAssertGreaterThanOrEqual(
                row.frame.height,
                44,
                "Canonical-title row must retain the minimum interactive height"
            )
            assertScrollableContentVisible(row.frame, in: viewport.frame)
            assertPlanTitleFitsTwoLines(
                "Велосипед с поворотом",
                renderedWidth: max(1, row.frame.width - (configuration.category == nil ? 96 : 32)),
                contentSizeCategory: configuration.category == nil
                    ? .large
                    : .accessibilityExtraExtraExtraLarge,
                minimumScaleFactor: 0.68
            )
            if configuration.category != nil {
                let dynamicType = app.descendants(matching: .any)["validation.dynamicType"].firstMatch
                XCTAssertTrue(dynamicType.waitForExistence(timeout: 3))
                XCTAssertEqual(dynamicType.value as? String, "accessibility3")
            }
            waitForVisualStability()
            attachScreenshot(
                named: "plan-canonical-titles-\(configuration.name)-\(Int(size.width))x\(Int(size.height))"
            )
            app.terminate()
        }
    }

    @MainActor
    func testSetupGenerationCancellationAndFailureRetainParameters() throws {
        let size = CGSize(width: 393, height: 852)
        let app = launchApp(
            viewport: size,
            extraArguments: ["-PlanGenerationDelayMilliseconds", "3000"]
        )
        let setup = setupButton(in: app)
        let setupScroll = app.scrollViews["setup.scroll"]
        let increment = app.buttons["setup.durationDial.increment"]
        let upper = app.buttons["setup.zone.upper"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
        let setupVisibleFrame = visibleFrame(above: setup, in: app.windows.firstMatch)
        scrollIntoView([increment], in: app, visibleFrame: setupVisibleFrame, scrollSurface: setupScroll)
        increment.tap()
        XCTAssertEqual(app.descendants(matching: .any)["setup.durationDial"].value as? String, "11 минут")
        scrollIntoView([upper], in: app, visibleFrame: setupVisibleFrame, scrollSurface: setupScroll)
        tapAndWaitForValue(upper, value: "Выбрано")

        setup.tap()
        let cancel = app.buttons["setup.generation.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 2))
        XCTAssertTrue(cancel.isHittable)
        attachScreenshot(named: "setup-generation-loading-cancellable-393x852")
        cancel.tap()
        XCTAssertTrue(setupButton(in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(app.descendants(matching: .any)["setup.durationDial"].value as? String, "11 минут")
        XCTAssertEqual(upper.value as? String, "Выбрано")
        let cancelled = app.staticTexts["setup.generationError"]
        scrollIntoView([cancelled], in: app, visibleFrame: setupVisibleFrame, scrollSurface: setupScroll)
        XCTAssertTrue(cancelled.waitForExistence(timeout: 3))
        XCTAssertTrue(cancelled.label.contains("Параметры сохранены"))
        attachScreenshot(named: "setup-generation-cancelled-parameters-retained-393x852")
        app.terminate()

        let failureApp = launchApp(
            viewport: size,
            extraArguments: ["-PlanGenerationFailure"]
        )
        let failureSetup = setupButton(in: failureApp)
        let failureScroll = failureApp.scrollViews["setup.scroll"]
        let failureIncrement = failureApp.buttons["setup.durationDial.increment"]
        let failureUpper = failureApp.buttons["setup.zone.upper"]
        XCTAssertTrue(failureSetup.waitForExistence(timeout: 5))
        XCTAssertTrue(failureScroll.waitForExistence(timeout: 3))
        let failureVisibleFrame = visibleFrame(above: failureSetup, in: failureApp.windows.firstMatch)
        scrollIntoView([failureIncrement], in: failureApp, visibleFrame: failureVisibleFrame, scrollSurface: failureScroll)
        failureIncrement.tap()
        scrollIntoView([failureUpper], in: failureApp, visibleFrame: failureVisibleFrame, scrollSurface: failureScroll)
        tapAndWaitForValue(failureUpper, value: "Выбрано")
        failureSetup.tap()

        let failure = failureApp.staticTexts["setup.generationError"]
        XCTAssertTrue(failure.waitForExistence(timeout: 3))
        scrollIntoView([failure], in: failureApp, visibleFrame: failureVisibleFrame, scrollSurface: failureScroll)
        XCTAssertTrue(failure.label.contains("Параметры сохранены"))
        XCTAssertEqual(failureApp.descendants(matching: .any)["setup.durationDial"].value as? String, "11 минут")
        XCTAssertEqual(failureUpper.value as? String, "Выбрано")
        XCTAssertTrue(failureSetup.isHittable)
        attachScreenshot(named: "setup-generation-failure-parameters-retained-393x852")
    }

    @MainActor
    func testActiveMediaErrorPreservesSessionControlsAndProgress() throws {
        let app = launchApp(
            viewport: CGSize(width: 393, height: 852),
            extraArguments: ["-ExerciseMediaFailure"]
        )
        navigateToSession(in: app)

        let mediaError = app.staticTexts["session.active.mediaError"]
        let stage = app.descendants(matching: .any)["session.active.athleteStage"].firstMatch
        let repetitionCount = app.staticTexts["session.active.repetitionCount"]
        let pause = app.buttons["session.pause"]
        let skip = app.buttons["session.exercise.skip"]
        let audio = app.buttons["session.audio.toggle"]
        let exit = app.buttons["session.exit"]
        let next = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Далее' OR label == 'Завершить набор'")
        ).firstMatch
        XCTAssertTrue(mediaError.waitForExistence(timeout: 5))
        XCTAssertTrue(stage.exists)
        XCTAssertTrue(
            (stage.value as? String)?.hasPrefix("state=failed;states=poster,failed;") == true,
            "Active playback probe must expose the deterministic media failure"
        )
        XCTAssertTrue(repetitionCount.exists)
        assertCriticalControls([pause, skip, audio, exit, next], in: app.windows.firstMatch)

        let activeScroll = app.scrollViews["session.active.scroll"]
        XCTAssertTrue(activeScroll.waitForExistence(timeout: 3))
        let visible = visibleFrame(above: pause, in: app.windows.firstMatch)
        scrollIntoView([mediaError, repetitionCount], in: app, visibleFrame: visible, scrollSurface: activeScroll)
        assertContained(mediaError.frame, in: visible)
        assertContained(repetitionCount.frame, in: visible)
        XCTAssertTrue(pause.isHittable)
        XCTAssertTrue(next.isHittable)
        XCTAssertTrue(audio.isHittable)
        XCTAssertTrue(exit.isHittable)
        attachScreenshot(named: "active-media-error-controls-preserved-393x852")
    }

    @MainActor
    private func launchApp(
        viewport: CGSize? = nil,
        contentSizeCategory: String? = nil,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ValidationMode", "YES", "-AppleInterfaceStyle", "Dark"]
        if !extraArguments.contains("-ResetAudioPreferences") {
            app.launchArguments.append("-ResetAudioPreferences")
        }
        app.launchArguments += extraArguments
        if let viewport {
            app.launchArguments += [
                "-ValidationViewportWidth", String(Int(viewport.width)),
                "-ValidationViewportHeight", String(Int(viewport.height))
            ]
        }
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
        return app
    }

    @MainActor
    private func openExerciseLibrary(in app: XCUIApplication) {
        let opener = app.buttons["setup.openExercises"]
        XCTAssertTrue(opener.waitForExistence(timeout: 5))
        let setupScroll = app.scrollViews["setup.scroll"]
        for _ in 0..<8 where !opener.isHittable {
            setupScroll.swipeDown()
        }
        XCTAssertTrue(opener.isHittable)
        opener.tap()
        XCTAssertTrue(app.descendants(matching: .any)["exerciseLibrary.screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 where !element.exists || !element.isHittable {
            app.swipeUp()
        }
    }

    @MainActor
    private func tapAndWaitForValue(_ element: XCUIElement, value: String) {
        element.tap()
        let selected = NSPredicate(format: "value == %@", value)
        XCTAssertTrue(wait(for: selected, object: element, timeout: 3))
    }

    @MainActor
    private func dismissKeyboard(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        let searchKey = keyboard.buttons["Search"]
        XCTAssertTrue(searchKey.waitForExistence(timeout: 2))
        searchKey.tap()
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 2))
    }

    @MainActor
    private func closeSearch(in app: XCUIApplication) {
        let closeSearch = app.buttons["закрыть"]
        XCTAssertTrue(closeSearch.waitForExistence(timeout: 2))
        closeSearch.tap()
        XCTAssertTrue(closeSearch.waitForNonExistence(timeout: 2))
    }

    private func wait(for predicate: NSPredicate, object: Any, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: object)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }


    private func playbackMetric(_ key: String, in evidence: String) throws -> Int {
        let fields = Dictionary(
            uniqueKeysWithValues: evidence
                .split(separator: ";")
                .compactMap { field -> (String, String)? in
                    let components = field.split(separator: "=", maxSplits: 1).map(String.init)
                    guard components.count == 2 else { return nil }
                    return (components[0], components[1])
                }
        )
        return try XCTUnwrap(fields[key].flatMap(Int.init), "Missing integer metric \(key) in \(evidence)")
    }

    @MainActor
    private func navigateToSession(in app: XCUIApplication, planScreenshotName: String? = nil) {
        let setup = app.buttons["Собрать тренировку"]
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        setup.tap()
        let start = app.buttons["Начать тренировку"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        if let planScreenshotName { attachScreenshot(named: planScreenshotName) }
        start.tap()
        XCTAssertTrue(app.buttons["session.pause"].waitForExistence(timeout: 5))
    }

    private func setupButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Собрать тренировку"]
    }

    private enum DialStop {
        case minimum
        case midpoint
        case maximum

        var offset: CGVector {
            switch self {
            case .minimum: CGVector(dx: 0.20, dy: 0.80)
            case .midpoint: CGVector(dx: 0.50, dy: 0.08)
            case .maximum: CGVector(dx: 0.80, dy: 0.80)
            }
        }
    }

    private func dialPoint(_ stop: DialStop, in dial: XCUIElement) -> XCUICoordinate {
        dial.coordinate(withNormalizedOffset: stop.offset)
    }

    @MainActor
    private func assertFiveStateGeometry(
        in app: XCUIApplication,
        container: XCUIElement,
        screenshotPrefix: String,
        setupControlScrollDragStartY: CGFloat? = nil,
        setupControlScrollDragEndY: CGFloat? = nil,
        setupControlScrollDragVelocity: XCUIGestureVelocity? = nil
    ) {
        let setup = setupButton(in: app)
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        assertCriticalControls([setup], in: container)
        let durationDial = app.descendants(matching: .any)["setup.durationDial"]
        let decrement = app.buttons["setup.durationDial.decrement"]
        let increment = app.buttons["setup.durationDial.increment"]
        let setupScroll = app.scrollViews["setup.scroll"]
        let setupVisibleFrame = visibleFrame(above: setup, in: container)
        XCTAssertTrue(setupScroll.waitForExistence(timeout: 3))
        scrollIntoSubstantialView(
            durationDial,
            in: app,
            visibleFrame: setupVisibleFrame,
            scrollSurface: setupScroll,
            scrollDragX: 0.05
        )
        XCTAssertTrue(durationDial.exists)
        assertScrollableContentVisible(durationDial.frame, in: setupVisibleFrame)
        scrollIntoView(
            [decrement, increment],
            in: app,
            visibleFrame: setupVisibleFrame,
            scrollSurface: setupScroll,
            scrollDragX: 0.05,
            scrollDragStartY: setupControlScrollDragStartY,
            scrollDragEndY: setupControlScrollDragEndY,
            reverseExplicitDragWhenRevealingTop: setupControlScrollDragStartY != nil
                && setupControlScrollDragEndY != nil,
            scrollDragVelocity: setupControlScrollDragVelocity
        )
        let dialControlFrames = assertCriticalControls([decrement, increment], in: setupVisibleFrame)
        assertNonOverlapping(dialControlFrames[0], dialControlFrames[1])
        attachScreenshot(named: "\(screenshotPrefix)-01-setup")
        setup.tap()

        let start = app.buttons["Начать тренировку"]
        let back = app.buttons["Назад к настройке"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let planControlFrames = assertCriticalControls([back, start], in: container)
        assertNonOverlapping(planControlFrames[0], planControlFrames[1])
        attachScreenshot(named: "\(screenshotPrefix)-02-plan")
        start.tap()

        var capturedActive = false
        var capturedRest = false
        for _ in 0..<100 {
            let restTitle = app.staticTexts["session.rest.nextTitle"]
            if restTitle.waitForExistence(timeout: 1) {
                let skipRest = app.buttons["Пропустить отдых"]
                XCTAssertTrue(skipRest.waitForExistence(timeout: 2))
                let skipRestFrame = assertCriticalControls([skipRest], in: container)[0]
                let restElements = [
                    app.staticTexts["session.rest.nextEyebrow"],
                    restTitle,
                    app.staticTexts["session.rest.nextDuration"]
                ]
                let restFrames = restElements.map { element -> CGRect in
                    XCTAssertTrue(element.waitForExistence(timeout: 2))
                    let frame = element.frame
                    XCTAssertFalse(frame.isEmpty)
                    assertContained(frame, in: container.frame)
                    return frame
                }
                assertPairwiseNonOverlapping(restFrames + [skipRestFrame])
                if !capturedRest {
                    attachScreenshot(named: "\(screenshotPrefix)-04-rest")
                    capturedRest = true
                }
                skipRest.tap()
                continue
            }

            let pause = app.buttons["session.pause"]
            XCTAssertTrue(pause.waitForExistence(timeout: 2))
            let next = app.buttons.matching(
                NSPredicate(
                    format: "label BEGINSWITH 'Далее' OR label == 'Завершить' OR label == 'Завершить набор' OR label == 'Подтвердить набор'"
                )
            ).firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            let activeControlFrames = assertCriticalControls([pause, next], in: container)
            assertNonOverlapping(activeControlFrames[0], activeControlFrames[1])
            let activeVisibleFrame = visibleFrame(above: pause, in: container)
            let activeScroll = app.scrollViews["session.active.scroll"]
            XCTAssertTrue(activeScroll.waitForExistence(timeout: 2))
            let repetitionCount = app.staticTexts["session.active.repetitionCount"]
            if repetitionCount.waitForExistence(timeout: 0.5) {
                scrollIntoSubstantialView(
                    repetitionCount,
                    in: app,
                    visibleFrame: activeVisibleFrame,
                    scrollSurface: activeScroll,
                    scrollDragX: 0.5,
                    scrollDragStartY: 0.25,
                    scrollDragEndY: 0.05
                )
                assertScrollableContentVisible(repetitionCount.frame, in: activeVisibleFrame)
            } else {
                let countdown = app.staticTexts["session.active.timer"]
                let countdownContext = app.staticTexts["session.active.timerContext"]
                XCTAssertTrue(countdown.waitForExistence(timeout: 2))
                XCTAssertTrue(countdownContext.waitForExistence(timeout: 2))
                scrollIntoView(
                    [countdown, countdownContext],
                    in: app,
                    visibleFrame: activeVisibleFrame,
                    scrollSurface: activeScroll,
                    scrollDragX: 0.5,
                    scrollDragStartY: 0.25,
                    scrollDragEndY: 0.05
                )
                assertContained(countdown.frame, in: activeVisibleFrame)
                assertContained(countdownContext.frame, in: activeVisibleFrame)
                assertCountdownComposition(countdown.frame, countdownContext.frame)
            }
            if !capturedActive {
                attachScreenshot(named: "\(screenshotPrefix)-03-active")
                capturedActive = true
            }

            let nextActionLabel = next.label
            next.tap()
            if nextActionLabel == "Завершить" {
                let confirmation = app.descendants(matching: .any)["session.confirmation.finishEarly"]
                if confirmation.waitForExistence(timeout: 0.5) {
                    let finishConfirmation = app.buttons["session.confirmation.finishEarly.destructive"]
                    revealModalAction(finishConfirmation, in: app, container: container)
                    XCTAssertTrue(finishConfirmation.isHittable)
                    finishConfirmation.tap()
                    break
                }
                if app.buttons["Повторить тренировку"].waitForExistence(timeout: 0.5) { break }
            }
            if nextActionLabel == "Завершить набор" {
                let setConfirmation = app.descendants(matching: .any)["session.confirmation.finishSetEarly"]
                if setConfirmation.waitForExistence(timeout: 0.5) {
                    let finishSetConfirmation = app.buttons["session.confirmation.finishSetEarly.destructive"]
                    revealModalAction(finishSetConfirmation, in: app, container: container)
                    XCTAssertTrue(finishSetConfirmation.isHittable)
                    finishSetConfirmation.tap()
                    if app.buttons["Повторить тренировку"].waitForExistence(timeout: 0.5) { break }
                }
            }
        }

        XCTAssertTrue(capturedActive)
        XCTAssertTrue(capturedRest)
        let repeatWorkout = app.buttons["Повторить тренировку"]
        let newWorkout = app.buttons["Настроить новую"]
        XCTAssertTrue(repeatWorkout.waitForExistence(timeout: 5))
        XCTAssertTrue(newWorkout.waitForExistence(timeout: 5))
        let finishControlFrames = assertCriticalControls([repeatWorkout, newWorkout], in: container)
        let repeatWorkoutFrame = finishControlFrames[0]
        let newWorkoutFrame = finishControlFrames[1]
        XCTAssertGreaterThanOrEqual(repeatWorkoutFrame.height, 58)
        let dynamicType = app.descendants(matching: .any)["validation.dynamicType"].firstMatch
        let isAccessibility3 = dynamicType.exists && (dynamicType.value as? String) == "accessibility3"
        let maximumPrimaryHeight = isAccessibility3
            ? maximumAX3FinishPrimaryHeight
            : maximumFinishPrimaryHeight
        XCTAssertLessThanOrEqual(
            repeatWorkoutFrame.height,
            maximumPrimaryHeight,
            "Finish primary action must remain bounded for the active Dynamic Type category"
        )
        XCTAssertEqual(repeatWorkoutFrame.minX, newWorkoutFrame.minX, accuracy: tolerance)
        XCTAssertEqual(repeatWorkoutFrame.maxX, newWorkoutFrame.maxX, accuracy: tolerance)
        XCTAssertEqual(repeatWorkoutFrame.midX, newWorkoutFrame.midX, accuracy: tolerance)
        assertNonOverlapping(repeatWorkoutFrame, newWorkoutFrame)

        let finishScroll = app.scrollViews.firstMatch
        XCTAssertTrue(finishScroll.waitForExistence(timeout: 2))
        let finishVisibleFrame = visibleFrame(above: repeatWorkout, in: container)
        let finishHierarchy = [
            app.descendants(matching: .any)["finish.eyebrow"],
            app.descendants(matching: .any)["finish.title"],
            app.descendants(matching: .any)["finish.body"],
            app.descendants(matching: .any)["finish.elapsedResult"],
            app.descendants(matching: .any)["finish.completedResult"]
        ]
        for element in finishHierarchy {
            XCTAssertTrue(element.waitForExistence(timeout: 2), "Required Finish content must exist")
            scrollIntoView(
                [element],
                in: app,
                visibleFrame: finishVisibleFrame,
                scrollSurface: finishScroll,
                scrollDragX: 0.5,
                scrollDragStartY: 0.25,
                scrollDragEndY: 0.05
            )
            XCTAssertTrue(element.isHittable, "Required Finish content must be visible and reachable")
            let frame = element.frame
            XCTAssertFalse(frame.isEmpty, "Required Finish content must have a non-empty frame")
            XCTAssertGreaterThan(frame.intersection(finishVisibleFrame).height, 0)
            XCTAssertGreaterThanOrEqual(frame.minX, finishVisibleFrame.minX - tolerance)
            XCTAssertLessThanOrEqual(frame.maxX, finishVisibleFrame.maxX + tolerance)
        }
        attachScreenshot(named: "\(screenshotPrefix)-05-finish")
    }

    private func revealModalAction(
        _ action: XCUIElement,
        in app: XCUIApplication,
        container: XCUIElement
    ) {
        let scrollViews = app.scrollViews
        guard scrollViews.count > 0 else { return }
        let modalScroll = scrollViews.element(boundBy: scrollViews.count - 1)
        scrollIntoView(
            [action],
            in: app,
            visibleFrame: container.frame,
            scrollSurface: modalScroll
        )
    }

    @discardableResult
    private func assertCriticalControls(_ controls: [XCUIElement], in container: XCUIElement) -> [CGRect] {
        return assertCriticalControls(controls, in: container.frame)
    }

    @discardableResult
    private func assertCriticalControls(_ controls: [XCUIElement], in containerFrame: CGRect) -> [CGRect] {
        return controls.map { control in
            XCTAssertTrue(control.exists, "Critical control must exist")
            XCTAssertTrue(control.isHittable, "Critical control \(control) must be hittable")
            let frame = control.frame
            XCTAssertFalse(frame.isEmpty, "Critical control \(control) must have a non-empty frame")
            assertContained(frame, in: containerFrame)
            return frame
        }
    }

    private func scrollIntoView(
        _ controls: [XCUIElement],
        in app: XCUIApplication,
        visibleFrame: CGRect,
        scrollSurface: XCUIElement? = nil,
        scrollDragX: CGFloat? = nil,
        scrollDragStartY: CGFloat? = nil,
        scrollDragEndY: CGFloat? = nil,
        reverseExplicitDragWhenRevealingTop: Bool = false,
        scrollDragVelocity: XCUIGestureVelocity? = nil
    ) {
        let surface: XCUIElement = scrollSurface ?? app
        for _ in 0..<8 {
            let frames = controls.map(\.frame)
            if frames.allSatisfy({ frame in
                   frame.minY >= visibleFrame.minY - tolerance
                       && frame.maxY <= visibleFrame.maxY + tolerance
               }),
               controls.allSatisfy({ $0.isHittable }) {
                return
            }

            let shouldRevealTop = frames.contains { $0.minY < visibleFrame.minY - tolerance }
            let usesGutterDrag = scrollSurface != nil
            let defaultStartY: CGFloat = usesGutterDrag
                ? (shouldRevealTop ? 0.25 : 0.75)
                : (shouldRevealTop ? 0.42 : 0.62)
            let defaultEndY: CGFloat = usesGutterDrag
                ? (shouldRevealTop ? 0.75 : 0.25)
                : (shouldRevealTop ? 0.57 : 0.47)
            let reversesExplicitDrag = reverseExplicitDragWhenRevealingTop && shouldRevealTop
            let startY: CGFloat = (reversesExplicitDrag ? scrollDragEndY : scrollDragStartY) ?? defaultStartY
            let endY: CGFloat = (reversesExplicitDrag ? scrollDragStartY : scrollDragEndY) ?? defaultEndY
            let dragX: CGFloat = scrollDragX ?? (usesGutterDrag ? 0.05 : 0.5)
            let startCoordinate = surface.coordinate(withNormalizedOffset: CGVector(dx: dragX, dy: startY))
            let endCoordinate = surface.coordinate(withNormalizedOffset: CGVector(dx: dragX, dy: endY))
            if let scrollDragVelocity {
                startCoordinate.press(
                    forDuration: 0.05,
                    thenDragTo: endCoordinate,
                    withVelocity: scrollDragVelocity,
                    thenHoldForDuration: 0
                )
            } else {
                startCoordinate.press(forDuration: 0.05, thenDragTo: endCoordinate)
            }
            if controls.map(\.frame) == frames {
                if shouldRevealTop {
                    surface.swipeDown()
                } else {
                    surface.swipeUp()
                }
            }
        }
    }

    private func scrollIntoSubstantialView(
        _ control: XCUIElement,
        in app: XCUIApplication,
        visibleFrame: CGRect,
        scrollSurface: XCUIElement? = nil,
        scrollDragX: CGFloat? = nil,
        scrollDragStartY: CGFloat? = nil,
        scrollDragEndY: CGFloat? = nil
    ) {
        let surface: XCUIElement = scrollSurface ?? app
        for _ in 0..<8 {
            let frame = control.frame
            let visible = frame.intersection(visibleFrame)
            if !visible.isNull,
               visible.height >= min(frame.height, visibleFrame.height) * 0.35,
               control.isHittable {
                return
            }

            let shouldRevealTop = frame.minY < visibleFrame.minY - tolerance
            let usesGutterDrag = scrollSurface != nil
            let startY: CGFloat = scrollDragStartY
                ?? (usesGutterDrag ? (shouldRevealTop ? 0.25 : 0.75) : (shouldRevealTop ? 0.42 : 0.62))
            let endY: CGFloat = scrollDragEndY
                ?? (usesGutterDrag ? (shouldRevealTop ? 0.75 : 0.25) : (shouldRevealTop ? 0.57 : 0.47))
            let dragX: CGFloat = scrollDragX ?? (usesGutterDrag ? 0.05 : 0.5)
            surface.coordinate(withNormalizedOffset: CGVector(dx: dragX, dy: startY))
                .press(
                    forDuration: 0.05,
                    thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: dragX, dy: endY))
                )
            if control.frame.equalTo(frame) {
                if shouldRevealTop {
                    surface.swipeDown()
                } else {
                    surface.swipeUp()
                }
            }
        }
    }

    private func visibleFrame(above obstruction: XCUIElement, in container: XCUIElement) -> CGRect {
        let containerFrame = container.frame
        return CGRect(
            x: containerFrame.minX,
            y: containerFrame.minY,
            width: containerFrame.width,
            height: max(0, obstruction.frame.minY - containerFrame.minY)
        )
    }

    private func waitForVisualStability() {
        Thread.sleep(forTimeInterval: 1)
    }


    private func assertOrder(_ identifiers: [String], in hierarchy: String) {
        let positions = identifiers.compactMap { hierarchy.range(of: $0)?.lowerBound }
        XCTAssertEqual(positions.count, identifiers.count)
        for pair in zip(positions, positions.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
    }

    private func assertContained(_ frame: CGRect, in container: CGRect) {
        XCTAssertGreaterThanOrEqual(frame.minX, container.minX - tolerance)
        XCTAssertGreaterThanOrEqual(frame.minY, container.minY - tolerance)
        XCTAssertLessThanOrEqual(frame.maxX, container.maxX + tolerance)
        XCTAssertLessThanOrEqual(frame.maxY, container.maxY + tolerance)
    }

    private func assertScrollableContentVisible(_ frame: CGRect, in viewport: CGRect) {
        XCTAssertFalse(frame.isEmpty)
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - tolerance)
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + tolerance)
        let visible = frame.intersection(viewport)
        XCTAssertFalse(visible.isNull)
        XCTAssertGreaterThanOrEqual(
            visible.height,
            min(frame.height, viewport.height) * 0.35,
            "Scrollable AX3 content must be substantially visible after deterministic scrolling"
        )
    }

    private func assertNonOverlapping(_ lhs: CGRect, _ rhs: CGRect) {
        XCTAssertFalse(lhs.intersects(rhs), "Frames overlap: \(lhs) and \(rhs)")
    }

    private func assertPairwiseNonOverlapping(_ frames: [CGRect]) {
        for first in frames.indices {
            for second in frames.indices where second > first {
                assertNonOverlapping(frames[first], frames[second])
            }
        }
    }

    private func assertCountdownComposition(_ countdown: CGRect, _ context: CGRect) {
        XCTAssertFalse(countdown.isEmpty)
        XCTAssertFalse(context.isEmpty)
        XCTAssertFalse(countdown.intersects(context), "Countdown and context must not overlap")

        if context.minX >= countdown.maxX {
            XCTAssertEqual(
                countdown.midY,
                context.midY,
                accuracy: 4,
                "Horizontal countdown composition must be vertically centered"
            )
        } else {
            let verticalGap = context.minY - countdown.maxY
            XCTAssertGreaterThanOrEqual(verticalGap, 0)
            XCTAssertLessThanOrEqual(verticalGap, 12)
        }
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        attach(XCUIScreen.main.screenshot(), named: name)
    }

    private func attach(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func attachScreenshotCrop(named name: String, frame: CGRect) {
        let screenshot = XCUIScreen.main.screenshot()
        guard let image = UIImage(data: screenshot.pngRepresentation),
              let crop = croppedCGImage(
                image,
                to: frame,
                coordinateSpace: UIScreen.main.bounds.size
              ) else {
            XCTFail("Unable to crop screenshot evidence for \(name)")
            return
        }
        let attachment = XCTAttachment(image: UIImage(cgImage: crop))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func assertPlanTitleFitsTwoLines(
        _ title: String,
        renderedWidth: CGFloat,
        contentSizeCategory: UIContentSizeCategory,
        minimumScaleFactor: CGFloat
    ) {
        let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory)
        let preferred = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        let minimumFont = UIFont.systemFont(
            ofSize: preferred.pointSize * minimumScaleFactor,
            weight: .semibold
        )
        let bounds = (title as NSString).boundingRect(
            with: CGSize(width: renderedWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: minimumFont],
            context: nil
        )
        XCTAssertLessThanOrEqual(
            ceil(bounds.height),
            ceil(minimumFont.lineHeight * 2),
            "Canonical title cannot fit in two lines even at the declared minimum scale"
        )
    }

    @MainActor
    private func pixelMismatchRatio(
        baseline: XCUIScreenshot,
        candidate: XCUIScreenshot,
        crop: CGRect,
        channelThreshold: UInt8
    ) -> Double {
        guard let baselineImage = UIImage(data: baseline.pngRepresentation),
              let candidateImage = UIImage(data: candidate.pngRepresentation),
              let baselineCrop = croppedCGImage(baselineImage, to: crop),
              let candidateCrop = croppedCGImage(candidateImage, to: crop) else {
            XCTFail("Unable to decode deterministic snapshot images")
            return 1
        }

        let width = 98
        let height = 196
        let lhs = rgbaBytes(of: baselineCrop, width: width, height: height)
        let rhs = rgbaBytes(of: candidateCrop, width: width, height: height)
        guard lhs.count == rhs.count, !lhs.isEmpty else {
            XCTFail("Unable to normalize deterministic snapshot images")
            return 1
        }

        var mismatchedPixels = 0
        for pixel in stride(from: 0, to: lhs.count, by: 4) {
            let differs = (0..<3).contains { channel in
                abs(Int(lhs[pixel + channel]) - Int(rhs[pixel + channel])) > Int(channelThreshold)
            }
            if differs { mismatchedPixels += 1 }
        }
        return Double(mismatchedPixels) / Double(width * height)
    }

    @MainActor
    private func croppedCGImage(
        _ image: UIImage,
        to points: CGRect,
        coordinateSpace: CGSize = UIScreen.main.bounds.size
    ) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard coordinateSpace.width > 0, coordinateSpace.height > 0 else { return nil }
        let scaleX = CGFloat(cgImage.width) / coordinateSpace.width
        let scaleY = CGFloat(cgImage.height) / coordinateSpace.height
        let requestedPixels = CGRect(
            x: points.minX * scaleX,
            y: points.minY * scaleY,
            width: points.width * scaleX,
            height: points.height * scaleY
        ).integral
        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let pixels = requestedPixels.intersection(imageBounds)
        guard !pixels.isNull, !pixels.isEmpty else { return nil }
        return cgImage.cropping(to: pixels)
    }

    private func rgbaBytes(of image: CGImage, width: Int, height: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
