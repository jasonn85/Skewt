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
        List {
            ForEach(sections, id: \.self) { section in
                SwiftUI.Section(header: sectionHeader(section.heading)) {
                    ForEach(section.paragraphs, id: \.self) {
                        Text($0)
                            .foregroundStyle(.white)
                            .padding(.leading, 12)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Gradient(colors: [.menuBackgroundGradient1, .menuBackgroundGradient2]))
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.menuSectionHeaderGradient1, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    Image("SkewtLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .shadow(color: .black, radius: 1, x: 1, y: 1)
                    
                    Text("Privacy Policy")
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.menuTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .shadow(color: .black, radius: 1, x: 1, y: 1)
                    
                    Image("SkewtLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .hidden()
                }
            }
        }
    }
    
    private func sectionHeader(_ heading: String) -> some View {
        Text(heading)
            .font(.title2)
            .foregroundStyle(.menuTitle)
            .shadow(color: .black, radius: 1, x: 1, y: 1)
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
            "• University Corporation for Atmospheric Research",
            "• University of Wyoming Atmospheric Science Radiosonde Archive",
            "Please refer to the privacy policies of these third-party data providers for information regarding their data practices."
        ]
    )
    
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView()
    }
}
