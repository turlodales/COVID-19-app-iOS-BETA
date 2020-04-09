//
//  SubmitSymptomsViewController.swift
//  CoLocate
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import UIKit
import Logging

typealias SendContactEvents = (Registration, [ContactEvent], @escaping (Result<Void, Error>) -> Void) -> Void

class SubmitSymptomsViewController: UIViewController, Storyboarded {
    static let storyboardName = "SelfDiagnosis"

    private var persistence: Persisting!
    private var contactEventRecorder: ContactEventRecorder!
    private var sendContactEvents: SendContactEvents!

    func _inject(persistence: Persisting, contactEventRecorder: ContactEventRecorder, sendContactEvents: @escaping SendContactEvents) {
        self.persistence = persistence
        self.contactEventRecorder = contactEventRecorder
        self.sendContactEvents = sendContactEvents
    }

    @IBOutlet weak var hasTemperatureLabel: UILabel!
    @IBOutlet weak var hasCoughLabel: UILabel!

    var hasHighTemperature: Bool!
    var hasNewCough: Bool!

    override func awakeFromNib() {
        super.awakeFromNib()

        persistence = Persistence.shared
        sendContactEvents = { registration, contactEvents, completion in
            let requestFactory = ConcreteSecureRequestFactory(registration: registration)
            let request = requestFactory.patchContactsRequest(contactEvents: contactEvents)
            URLSession.shared.execute(request, queue: .main, completion: completion)
        }
        contactEventRecorder = PlistContactEventRecorder.shared
    }

    @IBAction func submitTapped(_ sender: PrimaryButton) {
        guard let registration = persistence.registration else {
            fatalError("What do we do when we aren't registered?")
        }

        sender.isEnabled = false

        let contactEvents = contactEventRecorder.contactEvents
        sendContactEvents(registration, contactEvents, { [weak self] result in
            guard let self = self else { return }

            sender.isEnabled = true

            switch result {
            case .success(_):
                self.performSegue(withIdentifier: "unwindFromSelfDiagnosis", sender: self)
                self.contactEventRecorder.reset()
            case .failure(let error):
                self.alert(error: error)
            }
        })
    }

    private func alert(error: Error) {
        let alert = UIAlertController(
            title: nil,
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

}

fileprivate let logger = Logger(label: "SelfDiagnosis")
