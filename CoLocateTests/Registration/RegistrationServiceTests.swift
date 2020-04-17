//
//  RegistrationServiceTests.swift
//  CoLocateTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import CoLocate

class RegistrationServiceTests: TestCase {

    let id = UUID()
    let secretKey = "a secret key".data(using: .utf8)!

    func testRegistration_withPreExistingPushToken() throws {
        let session = SessionDouble()
        let persistence = PersistenceDouble(partialPostcode: "AB90")
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: QueueDouble()
        )
    
        remoteNotificationDispatcher.pushToken = "the current push token"
        
        let completedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationCompletedNotification)
        _ = registrationService.register()
        
        // Verify the first request
        let registrationRequestData = (session.requestSent as! RegistrationRequest).body!
        let registrationResponse = try JSONDecoder().decode(ExpectedRegistrationRequestBody.self, from: registrationRequestData)
        XCTAssertEqual(registrationResponse.pushToken, "the current push token")
        
        // Respond to the first request
        session.requestSent = nil
        session.executeCompletion!(Result<(), Error>.success(()))
        
        // Simulate the notification containing the activationCode.
        // This should trigger the second request.
        let activationCode = "a3d2c477-45f5-4609-8676-c24558094600"
        
        var remoteNotificatonCallbackCalled = false
        remoteNotificationDispatcher.handleNotification(userInfo: ["activationCode": activationCode]) { _ in
            remoteNotificatonCallbackCalled = true
        }
        
        // Verify the second request
        let confirmRegistrationRequest = (session.requestSent as! ConfirmRegistrationRequest).body!
        let confirmRegistrationPayload = try JSONDecoder().decode(ExpectedConfirmRegistrationRequestBody.self, from: confirmRegistrationRequest)
        XCTAssertEqual(confirmRegistrationPayload.activationCode, UUID(uuidString: activationCode))
        XCTAssertEqual(confirmRegistrationPayload.pushToken, "the current push token")
        XCTAssertEqual(confirmRegistrationPayload.postalCode, "AB90")
        
        XCTAssertNil(completedObserver.lastNotification)
        
        // Respond to the second request
        let confirmationResponse = ConfirmRegistrationResponse(id: id, secretKey: secretKey)
        session.executeCompletion!(Result<ConfirmRegistrationResponse, Error>.success(confirmationResponse))
        
        XCTAssertNotNil(completedObserver.lastNotification)

        let storedRegistration = persistence.registration
        XCTAssertNotNil(storedRegistration)
        XCTAssertEqual(id, storedRegistration?.id)
        XCTAssertEqual(secretKey, storedRegistration?.secretKey)
        
        // Make sure we cleaned up after ourselves
        XCTAssertTrue(remoteNotificatonCallbackCalled)
        XCTAssertFalse(remoteNotificationDispatcher.hasHandler(forType: .registrationActivationCode))
    }
    
    func testRegistration_withoutPreExistingPushToken() throws {
        let session = SessionDouble()
        let persistence = PersistenceDouble(partialPostcode: "AB90")
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: QueueDouble()
        )

        let completedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationCompletedNotification)

        _ = registrationService.register()
        
        XCTAssertNil(session.requestSent)

        // Simulate receiving the push token
        remoteNotificationDispatcher.receiveRegistrationToken(fcmToken: "a push token")
        // Verify the first request
        let registrationBody = (session.requestSent as! RegistrationRequest).body!
        let registrationPayload = try JSONDecoder().decode(ExpectedRegistrationRequestBody.self, from: registrationBody)
        XCTAssertEqual(registrationPayload.pushToken, "a push token")

        // Respond to the first request
        session.requestSent = nil
        session.executeCompletion!(Result<(), Error>.success(()))

        // Simulate the notification containing the activationCode.
        // This should trigger the second request.
        let activationCode = "a3d2c477-45f5-4609-8676-c24558094600"
        var remoteNotificatonCallbackCalled = false
        remoteNotificationDispatcher.handleNotification(userInfo: ["activationCode": activationCode]) { _ in
            remoteNotificatonCallbackCalled = true
        }

        // Verify the second request
        let confirmRegistrationBody = (session.requestSent as! ConfirmRegistrationRequest).body!
        let confirmRegistrationPayload = try JSONDecoder().decode(ExpectedConfirmRegistrationRequestBody.self, from: confirmRegistrationBody)
        XCTAssertEqual(confirmRegistrationPayload.activationCode, UUID(uuidString: activationCode))
        XCTAssertEqual(confirmRegistrationPayload.pushToken, "a push token")
        XCTAssertEqual(confirmRegistrationPayload.postalCode, "AB90")

        XCTAssertNil(completedObserver.lastNotification)

        // Respond to the second request
        let confirmationResponse = ConfirmRegistrationResponse(id: id, secretKey: secretKey)
        session.executeCompletion!(Result<ConfirmRegistrationResponse, Error>.success(confirmationResponse))

        XCTAssertNotNil(completedObserver.lastNotification)

        let storedRegistration = persistence.registration
        XCTAssertNotNil(storedRegistration)
        XCTAssertEqual(id, storedRegistration?.id)
        XCTAssertEqual(secretKey, storedRegistration?.secretKey)

        // Make sure we cleaned up after ourselves
        XCTAssertTrue(remoteNotificatonCallbackCalled)
        XCTAssertFalse(remoteNotificationDispatcher.hasHandler(forType: .registrationActivationCode))
    }
    
    func testRegistration_notifiesOnInitialRequestFailure() throws {
        let session = SessionDouble()
        let persistence = PersistenceDouble()
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        remoteNotificationDispatcher.pushToken = "the current push token"
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter, timeoutQueue: QueueDouble()
        )
        let failedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationFailedNotification)

        _ = registrationService.register()
        
        session.requestSent = nil
        session.executeCompletion!(Result<(), Error>.failure(ErrorForTest()))

        XCTAssertNotNil(failedObserver.lastNotification)
    }
    
    func testRegistration_notifiesOnSecondRequestFailure() throws {
        let session = SessionDouble()
        let persistence = PersistenceDouble(partialPostcode: "AB90")
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        remoteNotificationDispatcher.pushToken = "the current push token"
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: QueueDouble()
        )
        let failedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationFailedNotification)

        _ = registrationService.register()
        
        // Respond to the first request
        session.executeCompletion!(Result<(), Error>.success(()))

        // Simulate the notification containing the activationCode.
        // This should trigger the second request.
        let activationCode = "a3d2c477-45f5-4609-8676-c24558094600"
        remoteNotificationDispatcher.handleNotification(userInfo: ["activationCode": activationCode]) { _ in }

        // Respond to the second request
        session.executeCompletion!(Result<ConfirmRegistrationResponse, Error>.failure(ErrorForTest()))

        XCTAssertNotNil(failedObserver.lastNotification)
    }
    
    func testRegistration_cleansUpAfterInitialRequestFailure() throws {
        let session = SessionDouble()
        let persistence = PersistenceDouble()
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        remoteNotificationDispatcher.pushToken = "the current push token"
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: QueueDouble()
        )

        _ = registrationService.register()
        
        session.requestSent = nil
        session.executeCompletion!(Result<(), Error>.failure(ErrorForTest()))

        // We should not have unsusbscribed from push notifications.
        XCTAssertTrue(remoteNotificationDispatcher.hasHandler(forType: .registrationActivationCode))
        
        // We should also have unsubscribe from the PushTokenReceivedNotification. We can't test that directly but we can observe its effects.
        notificationCenter.post(name: PushTokenReceivedNotification, object: nil, userInfo: nil)
        XCTAssertNil(session.requestSent)
    }
    
    func testRegistration_timesOutAfter20Seconds() {
        let session = SessionDouble()
        let persistence = PersistenceDouble()
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        remoteNotificationDispatcher.pushToken = "the current push token"
        let queueDouble = QueueDouble()
        let failedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationFailedNotification)
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: queueDouble
        )

        _ = registrationService.register()

        queueDouble.scheduledBlock?()
        
        XCTAssertNotNil(failedObserver.lastNotification)
    }
    
    func testRegistration_canSucceedAfterTimeout() {
        let session = SessionDouble()
        let persistence = PersistenceDouble(partialPostcode: "AB90")
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        let queueDouble = QueueDouble()
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: queueDouble
        )
    
        remoteNotificationDispatcher.pushToken = "the current push token"
        let completedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationCompletedNotification)
        let failedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationFailedNotification)

        registrationService.register()
        
        // Respond to the first request
        session.executeCompletion!(Result<(), Error>.success(()))
                
        queueDouble.scheduledBlock?()
        failedObserver.lastNotification = nil
        
        // Simulate the notification containing the activationCode.
        // This should trigger the second request.
        remoteNotificationDispatcher.handleNotification(userInfo: ["activationCode": "arbitrary"]) { _ in }
                        
        // Respond to the second request
        let confirmationResponse = ConfirmRegistrationResponse(id: id, secretKey: secretKey)
        session.executeCompletion!(Result<ConfirmRegistrationResponse, Error>.success(confirmationResponse))
        
        XCTAssertNotNil(completedObserver.lastNotification)
        XCTAssertNil(failedObserver.lastNotification)
        XCTAssertNotNil(persistence.registration)
        
        // We should have unsusbscribed from push notifications.
        XCTAssertFalse(remoteNotificationDispatcher.hasHandler(forType: .registrationActivationCode))
        
        // We should also have unsubscribed from the PushTokenReceivedNotification. We can't test that directly but we can observe its effects.
        session.requestSent = nil
        notificationCenter.post(name: PushTokenReceivedNotification, object: nil, userInfo: nil)
        XCTAssertNil(session.requestSent)
    }
    
    func testRegistration_canFailAfterTimeout() {
        let session = SessionDouble()
        let persistence = PersistenceDouble(partialPostcode: "AB90")
        let notificationCenter = NotificationCenter()
        let remoteNotificationDispatcher = RemoteNotificationDispatcher(
            notificationCenter: notificationCenter,
            userNotificationCenter: UserNotificationCenterDouble()
        )
        let queueDouble = QueueDouble()
        let registrationService = ConcreteRegistrationService(
            session: session,
            persistence: persistence,
            remoteNotificationDispatcher: remoteNotificationDispatcher,
            notificationCenter: notificationCenter,
            timeoutQueue: queueDouble
        )
    
        remoteNotificationDispatcher.pushToken = "the current push token"
        let completedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationCompletedNotification)
        let failedObserver = NotificationObserverDouble(notificationCenter: notificationCenter, notificationName: RegistrationFailedNotification)

        registrationService.register()
        
        // Respond to the first request
        session.executeCompletion!(Result<(), Error>.success(()))
                
        queueDouble.scheduledBlock?()
        failedObserver.lastNotification = nil
        
        // Simulate the notification containing the activationCode.
        // This should trigger the second request.
        remoteNotificationDispatcher.handleNotification(userInfo: ["activationCode": "arbitrary"]) { _ in }
                        
        // Respond to the second request
        session.executeCompletion!(Result<ConfirmRegistrationResponse, Error>.failure(ErrorForTest()))
        
        XCTAssertNil(completedObserver.lastNotification)
        XCTAssertNotNil(failedObserver.lastNotification)
        XCTAssertNil(persistence.registration)
    }
}

class SessionDouble: Session {
    let delegateQueue = OperationQueue.current!
    
    var requestSent: Any?
    var executeCompletion: ((Any) -> Void)?
    
    func execute<R: Request>(_ request: R, queue: OperationQueue, completion: @escaping (Result<R.ResponseType, Error>) -> Void) {
        requestSent = request
        executeCompletion = { result in
            guard let castedResult = result as? Result<R.ResponseType, Error> else {
                print("SessionDouble: got the wrong result type. Expected \(Result<R.ResponseType, Error>.self) but got \(type(of: result))")
                return
            }
            
            completion(castedResult)
        }
    }
}

private struct ExpectedRegistrationRequestBody: Codable {
    let pushToken: String
}

private struct ExpectedConfirmRegistrationRequestBody: Codable {
    let activationCode: UUID
    let pushToken: String
    let postalCode: String
}
