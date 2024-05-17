//
//  ContentView.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI
import Combine

class TimeSelectDebouncer: ObservableObject {
    @Published var time = SoundingSelection.Time.now
    private var debouncer: AnyCancellable?
    var store: Store<SkewtState>? = nil
    
    init() {
        debouncer = $time
            .debounce(for: .seconds(0.2), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink(receiveValue: { [weak self] in
                self?.store?.dispatch(SoundingState.Action.changeAndLoadSelection(.selectTime($0)))
            })
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store<SkewtState>
    @StateObject var timeSelectDebouncer = TimeSelectDebouncer()
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.scenePhase) var scenePhase
    
    @State private var selectingTime = false
    
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
        let vertical = verticalSizeClass != .compact
        
        Group {
            if isPhone {
                if vertical {
                    VStack {
                        plotView
                            .layoutPriority(1.0)
                        
                        optionsView(includeSettings: true)
                            .frame(minHeight: 300.0)
                    }
                } else {
                    HStack {
                        optionsView(includeSettings: true)
                            .environment(\.horizontalSizeClass, .regular)

                        plotView
                    }
                }
            } else {
                NavigationSplitView {
                    optionsView(includeSettings: true)
                } detail: {
                    plotView
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .onAppear {
            timeSelectDebouncer.store = store
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.dispatch(SoundingState.Action.doRefresh)
            }
        }
    }
    
    private var plotView: some View {
        VStack (alignment: .center) {
            header
            
            AnnotatedSkewtPlotView(soundingState: store.state.currentSoundingState, plotOptions: store.state.plotOptions)
                .onAppear() {
                    store.dispatch(LocationState.Action.requestLocation)
                    store.dispatch(RecentSoundingsState.Action.refresh)
                    store.dispatch(SoundingState.Action.doRefresh)
                }
            
            footer
            
            if selectingTime {
                timeSelection
            }
        }
    }
    
    @ViewBuilder
    private func optionsView(includeSettings: Bool = true) -> some View {
        TabView(selection: Binding<DisplayState.DialogSelection>(
            get: { store.state.displayState.dialogSelection ?? .locationSelection(store.state.displayState.lastLocationDialogSelection) },
            set: { store.dispatch(DisplayState.Action.showDialog($0)) }
        )) {
            ForecastSelectionView()
                .environmentObject(store)
                .tabItem {
                    Label("Forecasts", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(DisplayState.DialogSelection.locationSelection(.forecast))
            
            SoundingSelectionView()
                .environmentObject(store)
                .tabItem {
                    Label("Soundings", systemImage: "balloon")
                }
                .tag(DisplayState.DialogSelection.locationSelection(.sounding))
            
            RecentSelectionsView()
                .environmentObject(store)
                .tabItem {
                    Label("Recents", systemImage: "list.bullet")
                }
                .tag(DisplayState.DialogSelection.locationSelection(.recent))
            
            if includeSettings {
                DisplayOptionsView()
                    .environmentObject(store)
                    .tabItem {
                        Label("Options", systemImage: "slider.horizontal.3")
                    }
                    .tag(DisplayState.DialogSelection.displayOptions)
            }
        }
    }
    
    private var isShowingLocationSelection: Bool {
        switch store.state.displayState.dialogSelection {
        case .locationSelection(_):
            return true
        case .displayOptions, .none:
            return false
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
        .onTapGesture {
            withAnimation {
                store.dispatch(DisplayState.Action.showDialog(.locationSelection(store.state.displayState.lastLocationDialogSelection)))
            }
        }
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
    
    @ViewBuilder
    private var timeSelection: some View {
        switch store.state.currentSoundingState.selection.type {
        case .op40:
            HourlyTimeSelectView(
                value: $timeSelectDebouncer.time,
                range: .hours(-24)...TimeInterval.hours(24),
                stepSize: .hours(SoundingSelection.ModelType.op40.hourInterval),
                location: store.state.locationState.locationIfKnown
            )
        case .raob:
            SoundingTimeSelectView(
                value: $timeSelectDebouncer.time,
                hourInterval: SoundingSelection.ModelType.raob.hourInterval
            )
        }
    }
    
    private var statusText: String? {
        switch store.state.currentSoundingState.status {
        case .done(let sounding, _), .refreshing(let sounding):
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
            case .emptyResponse:
                return "No data is available"
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
