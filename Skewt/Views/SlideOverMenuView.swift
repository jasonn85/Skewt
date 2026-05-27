//
//  SlideOverMenuView.swift
//  Skewt
//
//  Created by Jason Neel on 5/27/26.
//

import SwiftUI

struct SlideOverMenuView: View {
    let onClose: () -> Void
    
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Menu")
                    .foregroundStyle(.menuTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .shadow(color: .black, radius: 1, x: 1, y: 1)
                
                Spacer()
                
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .padding(5)
                }
                .foregroundStyle(.menuTitle)
                .buttonStyle(.glass)
                .accessibilityLabel("Close menu")
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.menuSectionHeaderGradient1, .menuSectionHeaderGradient2],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            List {
                Section("About") {
                    Button("Privacy policy") {
                        showingPrivacyPolicy = true
                    }
                    
                    Link(destination: URL(string: "https://github.com/jasonn85/Skewt")!) {
                        HStack(alignment: .center) {
                            Text("Skew-T² on GitHub")
                            Image(systemName: "safari")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Gradient(colors: [.menuBackgroundGradient1, .menuBackgroundGradient2]))
        }
        .frame(maxHeight: .infinity)
        .background(Gradient(colors: [.menuBackgroundGradient1, .menuBackgroundGradient2]))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.45), radius: 20, x: 4, y: 0)
        .sheet(isPresented: $showingPrivacyPolicy) {
            NavigationStack {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingPrivacyPolicy = false
                            }
                        }
                    }
            }
            .colorScheme(.dark)
        }
    }
}
