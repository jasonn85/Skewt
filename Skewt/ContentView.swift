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
                        
                        tabView
                            .frame(minHeight: 350.0)
                    }
                } else {
                    HStack {
                        locationNavigationStack

                        plotView
                    }
                }
            } else {
                NavigationSplitView(columnVisibility: splitViewVisibility) {
                    locationNavigationStack
                } detail: {
                    plotView
                        .navigationBarTitleDisplayMode(.inline)
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
    
    @ViewBuilder
    private var locationNavigationStack: some View {
        NavigationStack {
            LocationSelectionView(listType: .modelType(.op40))
                .environmentObject(store)
                .toolbar {
                    Button("Options", systemImage: "slider.horizontal.3") {
                        store.dispatch(DisplayState.Action.showDialog(.displayOptions))
                    }
                }
                .navigationDestination(isPresented: Binding<Bool>(get: {
                    store.state.displayState.dialogSelection == .displayOptions
                }, set: { _ in })) {
                    DisplayOptionsView()
                        .environmentObject(store)
                        .navigationTitle("Options")
                }
        }
        .navigationTitle("Locations")
    }
    
    private var splitViewVisibility: Binding<NavigationSplitViewVisibility> {
        Binding {
            switch store.state.displayState.dialogSelection {
            case .displayOptions, .locationSelection(_):
                return .doubleColumn
            default:
                return .detailOnly
            }
        } set: {
            if $0 == .detailOnly {
                store.dispatch(DisplayState.Action.hideDialog)
            } else {
                store.showLastLocationDialog()
            }
        }
    }
    
    private var plotView: some View {
        VStack (alignment: .center) {
            header
            
            AnnotatedSkewtPlotView(soundingState: store.state.currentSoundingState, plotOptions: store.state.plotOptions)
                .onAppear() {
                    store.dispatch(LocationState.Action.requestLocation)
                    store.dispatch(SoundingState.Action.doRefresh)
                }
            
            footer
            
            if selectingTime {
                timeSelection
            }
        }
    }
    
    @ViewBuilder
    private var tabView: some View {
        TabView(selection: Binding<DisplayState.DialogSelection>(
            get: { store.state.displayState.dialogSelection ?? .locationSelection(store.state.displayState.lastLocationDialogSelection) },
            set: { store.dispatch(DisplayState.Action.showDialog($0)) }
        )) {
            NavigationStack {
                LocationSelectionView(listType: .modelType(.op40))
                    .environmentObject(store)
            }
            .tabItem {
                Label("Forecasts", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(DisplayState.DialogSelection.locationSelection(.forecast))
            
            NavigationStack {
                LocationSelectionView(listType: .favoritesAndRecents)
                    .environmentObject(store)
            }
            .tabItem {
                Label("Recents", systemImage: "list.bullet")
            }
            .tag(DisplayState.DialogSelection.locationSelection(.recent))
            
            NavigationStack {
                DisplayOptionsView()
                    .environmentObject(store)
            }
            .tabItem {
                Label("Options", systemImage: "slider.horizontal.3")
            }
            .tag(DisplayState.DialogSelection.displayOptions)
        }
    }
    
    private var header: some View {
        HStack {
            if store.state.currentSoundingState.selection.requiresLocation {
                Image(systemName: "location")
            }
            
            Text(store.state.currentSoundingState.selection.type.description)
                
            
            switch store.state.currentSoundingState.selection.location {
            case .named(let locationName, _, _):
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
                store.showLastLocationDialog()
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
        case .op40, .automatic:
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
        case .done(_), .refreshing(_):
            let time = store.state.currentSoundingState.sounding?.data.time
            let timeAgo = timeAgoFormatter.string(for: time)!
            let dateString = dateFormatter.string(for: time)!
            return "\(timeAgo) (\(dateString))"
        case .idle:
            return nil
        case .loading:
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

extension Store<SkewtState> {
    func showLastLocationDialog() {
        dispatch(DisplayState.Action.showDialog(.locationSelection(state.displayState.lastLocationDialogSelection)))
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
        case .op40, .automatic:
            return "Forecast"
        case .raob:
            return "Sounding"
        }
    }
}
