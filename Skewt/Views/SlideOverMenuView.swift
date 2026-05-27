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
                    .font(.title)
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
            .padding(.vertical)
            .padding(.horizontal, 25)
            .background(
                LinearGradient(
                    colors: [.menuSectionHeaderGradient1, .menuSectionHeaderGradient2],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            List {
                Section {
                    Button("Privacy policy") {
                        showingPrivacyPolicy = true
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: URL(string: "https://github.com/jasonn85/Skewt")!) {
                        HStack(alignment: .center) {
                            Text("Skew-T² on GitHub")
                            Image(systemName: "safari")
                        }
                        .foregroundStyle(.blue)
                    }
                } header: {
                    Text("About")
                        .foregroundStyle(.primary)
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

#Preview {
    SlideOverMenuView(onClose: {})
        .frame(width: 420)
        .padding(28)
        .background(Gradient(colors: [.menuBackgroundGradient1, .menuBackgroundGradient2]))
        .colorScheme(.dark)
        .fontDesign(.monospaced)
}

