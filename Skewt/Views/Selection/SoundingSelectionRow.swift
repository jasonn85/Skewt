//
//  SoundingSelectionRow.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/23.
//

import SwiftUI
import MapKit

struct SoundingSelectionRow: View {
    @EnvironmentObject var store: Store<SkewtState>
    var selection: SoundingSelection
    var titleComponents: [DescriptionComponent] = [.selectionDescription]
    var subtitleComponents: [DescriptionComponent]? = nil
    
    enum DescriptionComponent: Hashable, Identifiable {
        case selectionDescription
        case type
        case text(String)
        case bearingAndDistance(bearing: Double, distance: Double)
        case age(Date)
        
        var id: Self { self }
    }
    
    private var distanceFormatter: MKDistanceFormatter {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        
        return formatter
    }
    
    private var timeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .short
        
        return formatter
    }
    
    @ViewBuilder
    private var title: some View {
        view(forComponents: titleComponents)
    }
    
    @ViewBuilder
    private var subtitle: some View {
        if let subtitleComponents = subtitleComponents, !subtitleComponents.isEmpty {
            view(forComponents: subtitleComponents)
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func view(forComponents components: [DescriptionComponent]) -> some View {
        HStack {
            ForEach(components, id: \.id) {
                view(forComponent: $0)
            }
        }
    }
    
    @ViewBuilder
    private func view(forComponent component: DescriptionComponent) -> some View {
        switch component {
        case .selectionDescription:
            Text(selection.description)
        case .type:
            typeView
        case .text(let name):
            Text(name)
        case .bearingAndDistance(bearing: let bearing, distance: let distance):
            let distanceString = distanceFormatter.string(fromDistance: distance)
            let bearingString = OrdinalDirection.closest(toBearing: bearing)
            
            HStack {
                Text("\(distanceString) \(bearingString.abbreviation)")
                
                Image(systemName: "location.north.fill")
                    .foregroundColor(Color("DirectionalArrow"))
                    .rotationEffect(Angle(degrees: bearing))
            }
        case .age(let timestamp):
            Text(timeFormatter.localizedString(fromTimeInterval: timestamp.timeIntervalSinceNow))
                .foregroundColor(color(forTimestamp: timestamp))
        }
    }
    
    private var typeView: some View {
        var iconName: String
        var description: String
        
        switch selection.type {
        case .op40:
            iconName = "chart.line.uptrend.xyaxis"
            description = "Forecast"
        case .raob:
            iconName = "balloon"
            description = "Sounding"
        }
        
        return HStack {
            Image(systemName: iconName)
            Text(description)
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark")
                .foregroundColor(.blue)
                .opacity(
                    selection.isEqualIgnoringTime(to: store.state.currentSoundingState.selection) ? 1.0 : 0.0
                )
                .padding(.trailing)
            
            VStack(alignment: .leading) {
                title
                subtitle
                    .font(.footnote)
            }
            
            Spacer()
            
            Toggle(
                isOn: Binding<Bool>(
                    get: { selectionIsPinned(selection) },
                    set: { isPinned in
                        withAnimation {
                            if isPinned {
                                store.dispatch(SkewtState.Action.pinSelection(selection))
                            } else {
                                store.dispatch(SkewtState.Action.unpinSelection(selection))
                            }
                        }
                    }
                )) {
                    Image(systemName: selectionIsPinned(selection) ? "pin.fill" : "pin")
                }
                .toggleStyle(.button)
        }
        .onTapGesture {
            withAnimation {
                store.dispatch(SoundingState.Action.changeAndLoadSelection(
                    .selectModelTypeAndLocation(
                        selection.type,
                        selection.location
                    )
                ))
            }
        }
    }
    
    private func selectionIsPinned(_ selection: SoundingSelection) -> Bool {
        store.state.pinnedSelections.contains(selection)
    }
    
    private func color(forTimestamp time: Date) -> Color {
        let age = -time.timeIntervalSinceNow
        
        if age >= redAge {
            return Color("Old Sounding")
        }
        
        return Color("Recent Sounding")
    }
    
    private var redAge: TimeInterval {
        switch selection.type {
        case .op40:
            let twoHours = 2.0 * 60.0 * 60.0
            return twoHours
        case .raob:
            let tenHours = 10.0 * 60.0 * 60.0
            return tenHours
        }
    }
}

struct SoundingSelectionRow_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore
        let currentForecast = SoundingSelection(type: .op40, location: .closest, time: .now)
        let mostRecentSounding = SoundingSelection(type: .raob, location: .closest, time: .now)
        let anHourAgo = Date(timeIntervalSinceNow: -1.0 * 60.0 * 60.0)
        let sixteenHoursAgo = Date(timeIntervalSinceNow: -16.0 * 60.0 * 60.0)
        
        List {
            SoundingSelectionRow(selection: currentForecast)
                .environmentObject(store)
            
            SoundingSelectionRow(
                selection: mostRecentSounding,
                titleComponents: [.text("SAN"), .text("Lindbergh Field")],
                subtitleComponents: [.bearingAndDistance(bearing: 220, distance: 50_000)]
            )
                .environmentObject(store)
            
            SoundingSelectionRow(
                selection: mostRecentSounding,
                titleComponents: [.text("NKX"), .text("MCAS Miramar")],
                subtitleComponents: [.age(anHourAgo), .bearingAndDistance(bearing: 220, distance: 50_000)]
            )
                .environmentObject(store)
            
            SoundingSelectionRow(
                selection: mostRecentSounding,
                titleComponents: [.text("NKX"), .text("MCAS Miramar")],
                subtitleComponents: [.age(sixteenHoursAgo), .bearingAndDistance(bearing: 220, distance: 50_000)]
            )
                .environmentObject(store)
            
            SoundingSelectionRow(
                selection: mostRecentSounding,
                titleComponents: [.text("A recent sounding")],
                subtitleComponents: [.type]
            )
                .environmentObject(store)
            
            SoundingSelectionRow(
                selection: currentForecast,
                titleComponents: [.text("A forecast")],
                subtitleComponents: [.type]
            )
                .environmentObject(store)
        }
    }
}
