//
//  AppDelegate.swift
//  CoLocate
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import UIKit
import CoreData
import Firebase
import FirebaseInstanceID

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, DiagnosisServiceDelegate {

    var window: UIWindow?

    var broadcaster: BTLEBroadcaster?
    var listener: BTLEListener?

    let notificationManager = NotificationManager()
    let diagnosisService = DiagnosisService.shared
    let appCoordinator = AppCoordinator(diagnosisService: DiagnosisService.shared)
    
    override init() {
        super.init()
        diagnosisService.delegate = self
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        initNotifications()
        initUi()

        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // This fires when we tap on the notification

        print("didReceiveRemoteNotification")

        notificationManager.handleNotification(userInfo: userInfo)

        // TODO make this correct
        completionHandler(UIBackgroundFetchResult.noData)
    }
    
    func diagnosisService(_ diagnosisService: DiagnosisService, didRecordDiagnosis diagnosis: Diagnosis) {
        if diagnosis == .potential {
            window?.rootViewController = appCoordinator.potentialVC
        }
        
    }

    // MARK: - Private

    private func initNotifications() {
        notificationManager.configure()
        notificationManager.requestAuthorization(application: UIApplication.shared) { (result) in
            // TODO
            if case .failure(let error) = result {
                print(error)
            }
        }
    }

    private func initUi() {
        appCoordinator.start()
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = appCoordinator.navigationController
        window?.makeKeyAndVisible()
    }
    
}
