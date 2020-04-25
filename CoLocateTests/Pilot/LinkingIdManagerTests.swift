//
//  LinkingIdManagerTests.swift
//  CoLocateTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import CoLocate

class LinkingIdManagerTests: XCTestCase {

    func testFetchingAfterRegistration() {
        let notificationCenter = NotificationCenter()
        let registration = Registration.fake
        let persisting = PersistenceDouble(registration: registration)
        let session = SessionDouble()
        let _ = LinkingIdManager(
            notificationCenter: notificationCenter,
            persisting: persisting,
            session: session
        )

        notificationCenter.post(name: RegistrationCompletedNotification, object: nil)
        session.executeCompletion?(Result<LinkingId, Error>.success("linking-id"))

        XCTAssertEqual(persisting.linkingId, "linking-id")
    }

    func testFetchLinkingId() {
        let notificationCenter = NotificationCenter()
        let registration = Registration.fake
        let persisting = PersistenceDouble(registration: registration)
        let session = SessionDouble()
        let manager = LinkingIdManager(
            notificationCenter: notificationCenter,
            persisting: persisting,
            session: session
        )

        var fetchedLinkingId: LinkingId?
        manager.fetchLinkingId { fetchedLinkingId = $0 }
        session.executeCompletion?(Result<LinkingId, Error>.success("linking-id"))

        XCTAssertEqual(persisting.linkingId, "linking-id")
        XCTAssertEqual(fetchedLinkingId, "linking-id")
    }

}
