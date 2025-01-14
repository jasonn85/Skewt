//
//  PrivacyPolicyView.swift
//  Skewt
//
//  Created by Jason Neel on 8/21/23.
//

import SwiftUI

struct PrivacyPolicyView: View {
    private struct Section: Hashable {
        let heading: String
        let paragraphs: [String]
    }
    
    var body: some View {
        List() {
            ForEach(sections, id: \.self) { section in
                SwiftUI.Section(header: Text(section.heading).font(.title2)) {
                    ForEach(section.paragraphs, id: \.self) {
                        Text($0)
                            .padding(.leading, 12)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Privacy Policy")
    }
    
    private var sections: [Section] {
        [
            userData,
            locationInformation,
            thirdParty
        ]
    }
    
    private var userData = Section(
        heading: "No User Data is Stored",
        paragraphs: [
            "Skew-T² does not store any user data and does not collect any user data aside from Location Information as described below."
        ]
    )
    
    private var locationInformation = Section(
        heading: "Location Information",
        paragraphs: [
            "If the user opts to share their location with the Skew-T² app to list nearby sounding or forecast locations, the user's location is not sent off device.",
            "If the user opts to share their location and view a forecast for that location, that location is partially obscured before being sent to any third party weather data provider and includes no other user information."
        ]
    )
    
    private var thirdParty = Section(
        heading: "Third Party Data Providers",
        paragraphs: [
            "• Open-Meteo",
            "Please refer to the privacy policies of these third-party data providers for information regarding their data practices."
        ]
    )
    
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}
