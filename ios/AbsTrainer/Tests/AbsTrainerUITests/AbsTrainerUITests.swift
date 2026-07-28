import UIKit
import XCTest

final class AbsTrainerUITests: XCTestCase {
    private let tolerance: CGFloat = 2
    private let maximumFinishPrimaryHeight: CGFloat = 96

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

            let next = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Далее'")).firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            next.tap()
        }

        XCTAssertTrue(capturedRest)
        XCTAssertTrue(app.staticTexts["Темп\nвыдержан."].waitForExistence(timeout: 5))
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

        upper.tap()
        lower.tap()
        XCTAssertEqual(full.value as? String, "Не выбрано")
        XCTAssertEqual(upper.value as? String, "Выбрано")
        XCTAssertEqual(lower.value as? String, "Выбрано")

        let visibleFrame = visibleFrame(above: setup, in: app.windows.firstMatch)
        scrollIntoView([high], in: app, visibleFrame: visibleFrame)
        high.tap()
        XCTAssertEqual(high.value as? String, "Выбрано")
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
    func testCriticalStatesFitCompact320By700And393By852() throws {
        for size in [CGSize(width: 320, height: 700), CGSize(width: 393, height: 852)] {
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
        let app = launchApp(
            viewport: CGSize(width: 393, height: 852),
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        let viewport = app.descendants(matching: .any)["validation.viewport"].firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        assertFiveStateGeometry(in: app, container: viewport, screenshotPrefix: "ax3-portrait")

        app.terminate()
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscapeApp = launchApp(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )
        let window = landscapeApp.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(window.frame.width, window.frame.height)
        assertFiveStateGeometry(in: landscapeApp, container: window, screenshotPrefix: "ax3-landscape")
        landscapeApp.terminate()
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
        XCTAssertEqual(dial.value as? String, "15 минут")
        XCTAssertFalse(increment.isEnabled)

        decrement.tap()
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "5 минут")
        XCTAssertFalse(decrement.isEnabled)
        XCTAssertTrue(increment.isEnabled)
        attachScreenshot(named: "duration-dial-minimum")
    }

    @MainActor
    func testDurationDialTapAndDragSnapToAllowedValues() throws {
        let app = launchApp(viewport: CGSize(width: 440, height: 956))
        let dial = app.descendants(matching: .any)["setup.durationDial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 5))

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
        XCTAssertEqual(dial.value as? String, "15 минут")
        increment.tap()
        XCTAssertEqual(dial.value as? String, "15 минут")
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "10 минут")
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "5 минут")
        decrement.tap()
        XCTAssertEqual(dial.value as? String, "5 минут")
        attachScreenshot(named: "duration-dial-adjustable-minimum")
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
    private func launchApp(
        viewport: CGSize? = nil,
        contentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-ValidationMode", "YES", "-AppleInterfaceStyle", "Dark"]
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
        screenshotPrefix: String
    ) {
        let setup = setupButton(in: app)
        XCTAssertTrue(setup.waitForExistence(timeout: 5))
        assertCriticalControls([setup], in: container)
        let durationDial = app.descendants(matching: .any)["setup.durationDial"]
        let decrement = app.buttons["setup.durationDial.decrement"]
        let increment = app.buttons["setup.durationDial.increment"]
        let setupVisibleFrame = visibleFrame(above: setup, in: container)
        scrollIntoView([durationDial, decrement, increment], in: app, visibleFrame: setupVisibleFrame)
        assertCriticalControls([durationDial, decrement, increment], in: setupVisibleFrame)
        assertNonOverlapping(decrement.frame, increment.frame)
        attachScreenshot(named: "\(screenshotPrefix)-01-setup")

        let start = app.buttons["Начать тренировку"]
        let back = app.buttons["Назад к настройке"]
        tapForStateTransition(from: setup, to: start)
        assertCriticalControls([back, start], in: container)
        assertNonOverlapping(back.frame, start.frame)
        attachScreenshot(named: "\(screenshotPrefix)-02-plan")
        start.tap()

        var capturedActive = false
        var capturedRest = false
        for _ in 0..<100 {
            let restTitle = app.staticTexts["session.rest.nextTitle"]
            if restTitle.waitForExistence(timeout: 1) {
                let skipRest = app.buttons["Пропустить отдых"]
                XCTAssertTrue(skipRest.waitForExistence(timeout: 2))
                assertCriticalControls([skipRest], in: container)
                let restElements = [
                    app.staticTexts["session.rest.nextEyebrow"],
                    restTitle,
                    app.staticTexts["session.rest.nextDuration"]
                ]
                for element in restElements {
                    XCTAssertTrue(element.waitForExistence(timeout: 2))
                    XCTAssertFalse(element.frame.isEmpty)
                    assertContained(element.frame, in: container.frame)
                }
                assertPairwiseNonOverlapping((restElements + [skipRest]).map(\.frame))
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
                NSPredicate(format: "label BEGINSWITH 'Далее' OR label == 'Завершить'")
            ).firstMatch
            XCTAssertTrue(next.waitForExistence(timeout: 2))
            assertCriticalControls([pause, next], in: container)
            assertNonOverlapping(pause.frame, next.frame)
            let countdown = app.staticTexts["session.active.timer"]
            let countdownContext = app.staticTexts["session.active.timerContext"]
            XCTAssertTrue(countdown.waitForExistence(timeout: 2))
            XCTAssertTrue(countdownContext.waitForExistence(timeout: 2))
            let activeVisibleFrame = visibleFrame(above: pause, in: container)
            scrollIntoView([countdown, countdownContext], in: app, visibleFrame: activeVisibleFrame)
            assertContained(countdown.frame, in: activeVisibleFrame)
            assertContained(countdownContext.frame, in: activeVisibleFrame)
            assertCountdownComposition(countdown.frame, countdownContext.frame)
            if !capturedActive {
                attachScreenshot(named: "\(screenshotPrefix)-03-active")
                capturedActive = true
            }

            next.tap()
            let confirmation = app.descendants(matching: .any)["session.confirmation.finishEarly"]
            if confirmation.waitForExistence(timeout: 0.5) {
                let finishConfirmation = app.buttons["session.confirmation.finishEarly.destructive"]
                XCTAssertTrue(finishConfirmation.isHittable)
                finishConfirmation.tap()
                break
            }
        }

        XCTAssertTrue(capturedActive)
        XCTAssertTrue(capturedRest)
        let repeatWorkout = app.buttons["Повторить тренировку"]
        let newWorkout = app.buttons["Настроить новую"]
        XCTAssertTrue(repeatWorkout.waitForExistence(timeout: 5))
        XCTAssertTrue(newWorkout.waitForExistence(timeout: 5))
        assertCriticalControls([repeatWorkout, newWorkout], in: container)
        XCTAssertGreaterThanOrEqual(repeatWorkout.frame.height, 58)
        XCTAssertLessThanOrEqual(
            repeatWorkout.frame.height,
            maximumFinishPrimaryHeight,
            "Finish primary action must remain compact when the balanced symbol layout is used"
        )
        XCTAssertEqual(repeatWorkout.frame.minX, newWorkout.frame.minX, accuracy: tolerance)
        XCTAssertEqual(repeatWorkout.frame.maxX, newWorkout.frame.maxX, accuracy: tolerance)
        XCTAssertEqual(repeatWorkout.frame.midX, newWorkout.frame.midX, accuracy: tolerance)
        assertNonOverlapping(repeatWorkout.frame, newWorkout.frame)

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
            scrollIntoView([element], in: app, visibleFrame: finishVisibleFrame)
            XCTAssertTrue(element.isHittable, "Required Finish content must be visible and reachable")
            XCTAssertFalse(element.frame.isEmpty, "Required Finish content must have a non-empty frame")
            XCTAssertGreaterThan(element.frame.intersection(finishVisibleFrame).height, 0)
            XCTAssertGreaterThanOrEqual(element.frame.minX, finishVisibleFrame.minX - tolerance)
            XCTAssertLessThanOrEqual(element.frame.maxX, finishVisibleFrame.maxX + tolerance)
        }
        attachScreenshot(named: "\(screenshotPrefix)-05-finish")
    }

    private func assertCriticalControls(_ controls: [XCUIElement], in container: XCUIElement) {
        assertCriticalControls(controls, in: container.frame)
    }

    private func assertCriticalControls(_ controls: [XCUIElement], in containerFrame: CGRect) {
        for control in controls {
            XCTAssertTrue(control.exists, "Critical control must exist")
            XCTAssertTrue(control.isHittable, "Critical control \(control) must be hittable")
            XCTAssertFalse(control.frame.isEmpty, "Critical control \(control) must have a non-empty frame")
            assertContained(control.frame, in: containerFrame)
        }
    }

    private func scrollIntoView(
        _ controls: [XCUIElement],
        in app: XCUIApplication,
        visibleFrame: CGRect
    ) {
        for _ in 0..<8 {
            let frames = controls.map(\.frame)
            if controls.allSatisfy({ $0.isHittable }),
               frames.allSatisfy({ frame in
                   frame.minY >= visibleFrame.minY - tolerance
                       && frame.maxY <= visibleFrame.maxY + tolerance
               }) {
                return
            }

            let shouldRevealTop = frames.contains { $0.minY < visibleFrame.minY - tolerance }
            let startY: CGFloat = shouldRevealTop ? 0.42 : 0.62
            let endY: CGFloat = shouldRevealTop ? 0.57 : 0.47
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
                .press(
                    forDuration: 0.05,
                    thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
                )
        }
    }

    private func tapForStateTransition(from source: XCUIElement, to destination: XCUIElement) {
        XCTAssertTrue(source.exists, "Transition source must exist before tapping")
        XCTAssertTrue(source.isHittable, "Transition source must be hittable before tapping")
        source.tap()

        if destination.waitForExistence(timeout: 2) { return }

        XCTAssertTrue(
            source.waitForExistence(timeout: 2),
            "Transition reached neither the source nor destination state"
        )
        XCTAssertTrue(source.isHittable, "Transition source must remain hittable before a state-aware retry")
        source.tap()
        XCTAssertTrue(destination.waitForExistence(timeout: 5), "Transition destination must appear after tapping")
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

    private func croppedCGImage(_ image: UIImage, to points: CGRect) -> CGImage? {
        guard let cgImage = image.cgImage else { return nil }
        let scaleX = CGFloat(cgImage.width) / image.size.width
        let scaleY = CGFloat(cgImage.height) / image.size.height
        let pixels = CGRect(
            x: points.minX * scaleX,
            y: points.minY * scaleY,
            width: points.width * scaleX,
            height: points.height * scaleY
        ).integral
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
