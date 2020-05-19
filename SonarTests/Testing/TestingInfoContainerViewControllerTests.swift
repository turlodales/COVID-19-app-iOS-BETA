//
//  TestingInfoContainerViewControllerTests.swift
//  SonarTests
//
//  Created by NHSX on 5/18/20
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import Sonar

class TestingInfoContainerViewControllerTests: XCTestCase {
    
    func testLoadsLinkingId() throws {
        let linkingIdMgr = LinkingIdManagerDouble()
        let vc = TestingInfoContainerViewController.instantiate()
        vc.inject(linkingIdManager: linkingIdMgr, uiQueue: QueueDouble())
        
        XCTAssertNotNil(vc.view)
        
        XCTAssertNotNil(linkingIdMgr.fetchCompletion)
        XCTAssertEqual(vc.children.count, 1)
        XCTAssertNotNil(vc.children.first as? ReferenceCodeLoadingViewController)
    }

    func testShowsTestingInfoOnSuccess() throws {
        let linkingIdMgr = LinkingIdManagerDouble()
        let vc = TestingInfoContainerViewController.instantiate()
        vc.inject(linkingIdManager: linkingIdMgr, uiQueue: QueueDouble())
        
        XCTAssertNotNil(vc.view)
        linkingIdMgr.fetchCompletion?("1234-abcd")
        
        XCTAssertNotNil(linkingIdMgr.fetchCompletion)
        XCTAssertEqual(vc.children.count, 1)
        let testingInfoVc = try XCTUnwrap(vc.children.first as? TestingInfoViewController)
        let refCodeVc = try XCTUnwrap(testingInfoVc.children.first as? ReferenceCodeViewController)
        XCTAssertFalse(refCodeVc.referenceCodeWrapper.isHidden)
        XCTAssertTrue(refCodeVc.errorWrapper.isHidden)
        XCTAssertEqual(refCodeVc.referenceCodeLabel.text, "1234-abcd")
    }
    
    func testShowsTestingInfoOnFailure() throws {
        let linkingIdMgr = LinkingIdManagerDouble()
        let vc = TestingInfoContainerViewController.instantiate()
        vc.inject(linkingIdManager: linkingIdMgr, uiQueue: QueueDouble())
        
        XCTAssertNotNil(vc.view)
        linkingIdMgr.fetchCompletion?(nil)
        
        XCTAssertNotNil(linkingIdMgr.fetchCompletion)
        XCTAssertEqual(vc.children.count, 1)
        let testingInfoVc = try XCTUnwrap(vc.children.first as? TestingInfoViewController)
        let refCodeVc = try XCTUnwrap(testingInfoVc.children.first as? ReferenceCodeViewController)
        XCTAssertTrue(refCodeVc.referenceCodeWrapper.isHidden)
        XCTAssertFalse(refCodeVc.errorWrapper.isHidden)
    }
}