//
//  WhatIsSkewtView.swift
//  Skewt
//
//  Created by Jason Neel on 5/27/26.
//

import SwiftUI

struct WhatIsSkewtView: View {
    private struct Section: Hashable {
        let heading: String?
        let content: [Content]
        
        init(
            heading: String?,
            content: [Content]
        ) {
            self.heading = heading
            self.content = content
        }
    }
    
    private enum Content: Hashable {
        case paragraph(Paragraph)
        case image(AssetImage)
        case link(ReferenceLink)
    }
    
    private enum Paragraph: Hashable {
        case plain(String)
        case inline([InlineText])
    }
    
    private struct InlineText: Hashable {
        let text: String
        let style: InlineTextStyle?
        
        init(_ text: String, style: InlineTextStyle? = nil) {
            self.text = text
            self.style = style
        }
    }
    
    private enum InlineTextStyle: Hashable {
        case temperature
        case dewPoint
        
        var color: Color {
            switch self {
            case .temperature:
                .red
            case .dewPoint:
                .blue
            }
        }
    }
    
    private struct AssetImage: Hashable {
        let name: String
        let description: String
    }
    
    private struct ReferenceLink: Hashable {
        let title: String
        let subtitle: String?
        let url: URL
    }
    
    var body: some View {
        List {
            ForEach(sections, id: \.self) { section in
                if let heading = section.heading {
                    SwiftUI.Section(header: sectionHeader(heading)) {
                        sectionContent(section.content)
                    }
                } else {
                    SwiftUI.Section {
                        sectionContent(section.content)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Gradient(colors: [.menuBackgroundGradient1, .menuBackgroundGradient2]))
        .navigationTitle("What is Skew‑T Log‑P?")
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
                    
                    Text("What is Skew‑T Log‑P?")
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
    
    @ViewBuilder
    private func sectionContent(_ contentItems: [Content]) -> some View {
        ForEach(contentItems, id: \.self) { content in
            switch content {
            case .paragraph(let paragraph):
                paragraphView(paragraph)
            case .image(let image):
                assetImage(image)
            case .link(let link):
                referenceLink(link)
            }
        }
    }
    
    private func sectionHeader(_ heading: String) -> some View {
        Text(heading)
            .font(.title2)
            .foregroundStyle(.menuTitle)
            .shadow(color: .black, radius: 1, x: 1, y: 1)
    }
    
    private func paragraphView(_ paragraph: Paragraph) -> some View {
        paragraphText(paragraph)
            .foregroundStyle(.white)
            .padding(.leading, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    
    private func paragraphText(_ paragraph: Paragraph) -> Text {
        switch paragraph {
        case .plain(let text):
            Text(text)
        case .inline(let spans):
            Text(attributedString(for: spans))
        }
    }
    
    private func attributedString(for spans: [InlineText]) -> AttributedString {
        var result = AttributedString()
        
        for span in spans {
            var attributedSpan = AttributedString(span.text)
            if let style = span.style {
                attributedSpan.foregroundColor = style.color
            }
            result.append(attributedSpan)
        }
        
        return result
    }
    
    private func assetImage(_ image: AssetImage) -> some View {
        Image(image.name)
            .resizable()
            .scaledToFit()
            .accessibilityLabel(image.description)
            .padding(.leading, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    
    private func referenceLink(_ link: ReferenceLink) -> some View {
        Link(destination: link.url) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(link.title)
                    Image(systemName: "safari")
                }
                .foregroundStyle(.blue)
                
                if let subtitle = link.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.leading, 12)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private var sections: [Section] {
        [
            skewTLogP,
            lines,
            clouds,
            otherLines,
            soundings,
            forecasts,
            references
        ]
    }
    
    private var skewTLogP = Section(
        heading: nil,
        content: [
            .paragraph(.plain("If weather is the Matrix, reading a Skew‑T Log‑P chart is reading the green text. Meteorologists and glider pilots understand. All pilots should!"))
        ]
    )
    
    private var lines = Section(
        heading: "📈 The lines",
        content: [
            .paragraph(.inline([
                InlineText("The two plotted lines are "),
                InlineText("temperature", style: .temperature),
                InlineText(" and "),
                InlineText("moisture/dew point", style: .dewPoint),
                InlineText(". Height is height. (Pressure altitude is plotted logarithmically, hence Log‑P). Left is cold; right is hot. Temperature is skewed so that a constant temperature atmosphere would slope up and to the right, hence Skew‑T.")
            ])),
            .image(AssetImage(
                name: "WhatIsSkewtTemperatureLine",
                description: "Temperature line example"
            ))
        ]
    )
    
    private var clouds = Section(
        heading: "☁️ Lines touch = clouds",
        content: [
            .paragraph(.plain("The temperature falling to the dew point makes clouds/dew/precipitation. This would be shown as the temperature plot touching or nearly touching the dew point plot.")),
            .paragraph(.plain("Here is a low marine layer of clouds:")),
            .image(AssetImage(
                name: "WhatIsSkewtMarineLayer",
                description: "Marine layer example"
            )),
            .paragraph(.plain("And a thick layer of rain:")),
            .image(AssetImage(
                name: "WhatIsSkewtRain",
                description: "Rain example"
            ))
        ]
    )
    
    private var otherLines = Section(
        heading: "📐 The other lines",
        content: [
            .paragraph(.plain("All sorts of other weather characteristics are easily identifiable on a Skew‑T Log‑P plot. The plot often includes guidelines that show how temperature tends to fall with altitude for dry and moist air. These can be used to predict icing, convective activity/thunderstorms, and wind shear, to start.")),
            .image(AssetImage(
                name: "WhatIsSkewtGuidelines",
                description: "Guidelines"
            ))
        ]
    )
    
    private var soundings = Section(
        heading: "🎈 Soundings",
        content: [
            .paragraph(.plain("Weather balloons are released twice a day from dozens of locations around the US and hundreds around the world."))
        ]
    )
    
    private var forecasts = Section(
        heading: "🧮 Forecasts",
        content: [
            .paragraph(.plain("Forecasts provide predicted sounding data on a grid. The default model used for the US is hourly on a 3-25 km grid for up to 16 days in the future. Specifics for other locations vary."))
        ]
    )
    
    private var references = Section(
        heading: "Further Skew‑T Log‑P references",
        content: [
            .link(ReferenceLink(
                title: "Return of Skew‑T",
                subtitle: "An explanation of Skew‑T Log‑P for pilots",
                url: URL(string: "https://www.flyingmag.com/return-of-skew-t/")!
            )),
            .link(ReferenceLink(
                title: "Skew‑T tutorials",
                subtitle: "An overview of information that can be divined from a plot",
                url: URL(string: "https://www.weather.gov/source/zhu/ZHU_Training_Page/convective_parameters/skewt/skewtinfo.html")!
            )),
            .link(ReferenceLink(
                title: "Typical Skew‑T patterns",
                subtitle: "Examples of some typical patterns",
                url: URL(string: "https://www.weather.gov/source/zhu/ZHU_Training_Page/convective_parameters/skewt/skewtinfo.html#SKEW3")!
            )),
            .link(ReferenceLink(
                title: "Weather Explained: Intro to Reading Skew‑T Graphs",
                subtitle: "A five minute video, explaining weather balloons, Skew‑T plots, and how to read them",
                url: URL(string: "https://youtu.be/1lJ9Kaieoco")!
            ))
        ]
    )
}

#Preview {
    NavigationStack {
        WhatIsSkewtView()
    }
    .colorScheme(.dark)
    .fontDesign(.monospaced)
}
