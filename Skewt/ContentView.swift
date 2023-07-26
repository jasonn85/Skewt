//
//  ContentView.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store<SkewtState>
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @State private var selectingTime = false
    @State private var updateTimeTask: Task<(), Error>? = nil
    private let updateTimeDebounce: Duration = .milliseconds(100)
    @State private var selectedTimeInterval: TimeInterval = 0
    
    private var timeAgoFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .standalone
        
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        return formatter
    }
    
    var body: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let horizontal = isPhone && verticalSizeClass == .compact
        let layout = horizontal ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        
        layout {
            VStack (alignment: .center) {
                header
                
                AnnotatedSkewtPlotView().environmentObject(store).onAppear() {
                    store.dispatch(LocationState.Action.requestLocation)
                    store.dispatch(SoundingState.Action.doRefresh)
                }
                
                footer
                
                if selectingTime {
                    timeSelection
                }
            }
            
            TabView(selection: Binding<DisplayState.TabSelection>(
                get: { store.state.displayState.tabSelection },
                set: { store.dispatch(DisplayState.Action.selectTab($0)) }
            )) {
                ForecastSelectionView()
                    .environmentObject(store)
                    .tabItem {
                        Label("Forecasts", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(DisplayState.TabSelection.forecastSelection)
                
                SoundingSelectionView()
                    .environmentObject(store)
                    .tabItem {
                        Label("Soundings", systemImage: "balloon")
                    }
                    .tag(DisplayState.TabSelection.soundingSelection)
                
                RecentSelectionsView()
                    .environmentObject(store)
                    .tabItem {
                        Label("Recents", systemImage: "list.bullet")
                    }
                    .tag(DisplayState.TabSelection.recentSelections)
                
                DisplayOptionsView()
                    .environmentObject(store)
                    .tabItem {
                        Label("Options", systemImage: "slider.horizontal.3")
                    }
                    .tag(DisplayState.TabSelection.displayOptions)
            }
            .environment(\.horizontalSizeClass, isPhone && !horizontal ? .compact : .regular)
        }
    }
    
    private var header: some View {
        HStack {
            if store.state.currentSoundingState.selection.requiresLocation {
                Image(systemName: "location")
            }
            
            Text(store.state.currentSoundingState.selection.type.description)
                
            
            switch store.state.currentSoundingState.selection.location {
            case .named(let locationName):
                Text("(\(locationName))")
            case .point(_, _):
                Text("(selected location)")
            case .closest:
                EmptyView()
            }
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.blue)
    }
    
    private var footer: some View {
        HStack(spacing: 14) {
            if let text = statusText {
                Text(text)
            }
            
            if store.state.currentSoundingState.status.isLoading {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .rotationEffect(timeSelectionChevronRotation)
            }
        }
        .font(.footnote)
        .onTapGesture {
            withAnimation {
                selectingTime.toggle()
            }
        }
    }
    
    private var timeSelectionChevronRotation: Angle {
        selectingTime ? .degrees(90) : .zero
    }
    
    private var timeSelection: some View {
        TimeSelectView(
            value: Binding<TimeInterval>(
                get: { selectedTimeInterval },
                set: { setTimeInterval($0) }
            ),
            range: .hours(-24)...TimeInterval.hours(24)
        )
    }
    
    private func setTimeInterval(_ interval: TimeInterval) {
        selectedTimeInterval = interval
        
        updateTimeTask?.cancel()
        updateTimeTask = nil
        
        let time: SoundingSelection.Time = interval == 0 ? .now : .relative(interval)
        
        if time != store.state.currentSoundingState.selection.time {
            updateTimeTask = Task {
                try await Task.sleep(for: updateTimeDebounce)
                store.dispatch(SoundingState.Action.changeAndLoadSelection(.selectTime(time)))
            }
        }
    }
    
    private var statusText: String? {
        switch store.state.currentSoundingState.status {
        case .done(let sounding), .refreshing(let sounding):
            let timeAgo = timeAgoFormatter.string(for: sounding.timestamp)!
            let dateString = dateFormatter.string(for: sounding.timestamp)!
            return "\(timeAgo) (\(dateString))"
        case .idle:
            return nil
        case .loading, .awaitingSoundingLocationData:
            return "Loading..."
        case .failed(let error):
            switch error {
            case .lackingLocationPermission:
                return "Location is unavailable"
            case .requestFailed:
                return "Request failed"
            case .unableToGenerateRequestFromSelection:
                return "Error creating request"
            case .unparseableResponse:
                return "Data was not parseable"
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(Store<SkewtState>.previewStore)
    }
}

extension SoundingSelection.Time {
    var asTimeInterval: TimeInterval {
        switch self {
        case .now:
            return 0
        case .relative(let interval):
            return interval
        case .specific(let date):
            return date.timeIntervalSinceNow
        }
    }
}

extension SoundingSelection.ModelType: CustomStringConvertible {
    var description: String {
        switch self {
        case .op40:
            return "Op40 forecast"
        case .raob:
            return "Sounding"
        }
    }
}
