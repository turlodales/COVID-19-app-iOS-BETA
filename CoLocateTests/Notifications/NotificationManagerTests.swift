//
//  NotificationManagerTests.swift
//  CoLocateTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import Foundation

import XCTest
import Firebase
@testable import CoLocate

class NotificationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()

        FirebaseAppDouble.configureCalled = false
        DiagnosisService.clear()
    }

    func testConfigure() {
        let messaging = MessagingDouble()
        let notificationManager = ConcreteNotificationManager(
            uiQueue: .main,
            firebase: FirebaseAppDouble.self,
            messagingFactory: { messaging },
            userNotificationCenter: NotificationCenterDouble(),
            diagnosisService: DiagnosisService()
        )

        notificationManager.configure()

        XCTAssertTrue(FirebaseAppDouble.configureCalled)
    }
    
    func testPushTokenHandling() {
        let messaging = MessagingDouble()
        let notificationManager = ConcreteNotificationManager(
            uiQueue: .main,
            firebase: FirebaseAppDouble.self,
            messagingFactory: { messaging },
            userNotificationCenter: NotificationCenterDouble(),
            diagnosisService: DiagnosisService()
        )
        let delegate = NotificationManagerDelegateDouble()
        notificationManager.delegate = delegate

        notificationManager.configure()
        // Ugh, can't find a way to not pass a real Messaging here. Should be ok as long as the actual delegate method doesn't use it.
        messaging.delegate!.messaging?(Messaging.messaging(), didReceiveRegistrationToken: "12345")
        XCTAssertEqual("12345", notificationManager.pushToken)
        XCTAssertEqual("12345", delegate.pushToken)
    }

    func testRequestAuthorization_success() {
        let notificationCenterDouble = NotificationCenterDouble()
        let notificationManager = ConcreteNotificationManager(
            uiQueue: DispatchQueue.test,
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: notificationCenterDouble,
            diagnosisService: DiagnosisService()
        )

        let applicationDouble = ApplicationDouble()
        var granted: Bool?
        var error: Error?
        notificationManager.requestAuthorization(application: applicationDouble) { result in
            switch result {
            case .success(let g): granted = g
            case .failure(let e): error = e
            }
        }

        notificationCenterDouble.completionHandler!(true, nil)
        DispatchQueue.test.flush()

        XCTAssertTrue(applicationDouble.registeredForRemoteNotifications)
        XCTAssertTrue(granted!)
        XCTAssertNil(error)
    }
    
    func testHandleNotification_savesPotentialDiagnosis() {
        let diagnosisService = DiagnosisService()
        let notificationManager = ConcreteNotificationManager(
            uiQueue: DispatchQueue.test,
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: NotificationCenterDouble(),
            diagnosisService: diagnosisService
        )
        
        notificationManager.handleNotification(userInfo: ["diagnosis" : "potential"])
        
        XCTAssertEqual(diagnosisService.currentDiagnosis, .potential)
    }
    
    func testHandleNotification_doesNotSaveOtherDiagnosis() {
        let diagnosisService = DiagnosisService()
        let notificationManager = ConcreteNotificationManager(
            uiQueue: DispatchQueue.test,
            firebase: FirebaseAppDouble.self,
            messagingFactory: { MessagingDouble() },
            userNotificationCenter: NotificationCenterDouble(),
            diagnosisService: diagnosisService
        )
        
        notificationManager.handleNotification(userInfo: ["diagnosis" : "infected"])
        
        XCTAssertEqual(diagnosisService.currentDiagnosis, .unknown)
    }
}

class ApplicationDouble: Application {
    var registeredForRemoteNotifications = false
    func registerForRemoteNotifications() {
        registeredForRemoteNotifications = true
    }
}

class FirebaseAppDouble: TestableFirebaseApp {
    static var configureCalled = false
    static func configure() {
        configureCalled = true
    }
}

class MessagingDouble: TestableMessaging {
    weak var delegate: MessagingDelegate?
}

class NotificationCenterDouble: UserNotificationCenter {

    weak var delegate: UNUserNotificationCenterDelegate?

    var options: UNAuthorizationOptions?
    var completionHandler: ((Bool, Error?) -> Void)?
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        self.options = options
        self.completionHandler = completionHandler
    }

}

class NotificationManagerDelegateDouble: NotificationManagerDelegate {
    var pushToken: String?
    
    func notificationManager(_ notificationManager: NotificationManager, didObtainPushToken token: String) {
        self.pushToken = token
    }
    
    func notificationManager(_ notificationManager: NotificationManager, didReceiveNotificationWithInfo userInfo: [AnyHashable : Any]) {
    }
}
