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
                self?.store?.dispatch(SoundingState.Action.selection(.selectTime($0)))
            })
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store<SkewtState>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject var timeSelectDebouncer = TimeSelectDebouncer()
    
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.appEnvironment) private var appEnvironment
    
    @State private var selectingTime = false
    @State private var preferredCompactColumn: NavigationSplitViewColumn = .detail
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .automatic
    
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
        NavigationSplitView(columnVisibility: $splitViewVisibility,
                            preferredCompactColumn: $preferredCompactColumn) {
            // If we're a compact UI, we'll set an action which will make a -> button appear
            let dismissCompactMenuAction: (() -> Void)? = {
                guard horizontalSizeClass == .compact else {
                    return nil
                }
                
                return {
                    showDetailForCurrentSelection()
                }
            }()
            
            MenuView(onReturnToSelection: dismissCompactMenuAction)
                .environmentObject(store)
        } detail: {
            plotView
                .toolbar(.hidden, for: .navigationBar)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) {
                    Button {
                        preferredCompactColumn = .content
                        splitViewVisibility = .doubleColumn
                    } label: {
                        header
                            .padding([.all], 14)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                }
        }
        .fontDesign(.monospaced)
        .onAppear {
            guard appEnvironment.isLive else {
                return
            }
            
            timeSelectDebouncer.store = store
            requestLocationIfNeeded()
            
            if case .idle = store.state.recentSoundings.status {
                store.dispatch(RecentSoundingsState.Action.load)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard appEnvironment.isLive else {
                return
            }
            
            if newPhase == .active {
                requestLocationIfNeeded()
                store.dispatch(SoundingState.Action.refreshTapped)
            }
        }
        .onChange(of: store.state.currentSoundingState.selection.location) { _, _ in
            guard appEnvironment.isLive else {
                return
            }
            
            requestLocationIfNeeded()
        }
        .onChange(of: store.state.currentSoundingState.selection) { _, _ in
            guard horizontalSizeClass == .compact else {
                // Keep the content/left panel open on iPad
                return
            }
            
            showDetailForCurrentSelection()
        }
    }
    
    private var plotView: some View {
        VStack (alignment: .center) {            
            AnnotatedSkewtPlotView(
                soundingState: store.state.currentSoundingState,
                plotOptions: store.state.plotOptions,
                location: store.state.locationState.locationIfKnown,
                time: store.state.currentSoundingState.selection.timeAsConcreteDate
            )
            
            footer
            
            if selectingTime {
                timeSelection
            }
        }
    }
    
    @ViewBuilder
    private var header: some View {
        let selection = store.state.currentSoundingState.selection
        
        VStack {
            HStack {
                if selection.location == .closest {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                
                let title: String = {
                    if let longDescription = longerDescription(for: selection) {
                        return "\(longDescription) (\(selection.location.briefDescription))"
                    } else {
                        return selection.location.briefDescription
                    }
                }()
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(selection.type.subtitle)
                .font(.footnote)
                .opacity(0.7)
        }
    }
    
    private var footer: some View {
        HStack(spacing: 14) {
            if let text = statusText {
                Text(text)
            }
            
            if store.state.currentSoundingState.isLoading {
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
        case .forecast(_):
            HourlyTimeSelectView(
                value: $timeSelectDebouncer.time,
                range: .hours(-24)...TimeInterval.hours(24),
                stepSize: .hours(SoundingSelection.ModelType.forecast(.automatic).hourInterval),
                location: store.state.locationState.locationIfKnown
            )
        case .sounding:
            SoundingTimeSelectView(
                value: $timeSelectDebouncer.time,
                hourInterval: SoundingSelection.ModelType.sounding.hourInterval
            )
        }
    }
    
    private var statusText: String? {
        if let error = store.state.currentSoundingState.lastError {
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

        if let time = store.state.currentSoundingState.resolvedSounding?.data.time {
            let timeAgo = timeAgoFormatter.string(for: time)!
            let dateString = dateFormatter.string(for: time)!
            return "\(timeAgo) (\(dateString))"
        }

        if store.state.currentSoundingState.isLoading {
            return "Loading..."
        }

        return nil
    }

    private func requestLocationIfNeeded() {
        guard store.state.currentSoundingState.selection.requiresLocation else {
            return
        }

        guard store.state.locationState.locationIfKnown == nil else {
            return
        }

        store.dispatch(LocationState.Action.requestLocation)
    }
    
    private func longerDescription(for selection: SoundingSelection) -> String? {
        guard case .named(let name, let latitude, let longitude) = selection.location,
              let list = try? LocationList.forType(selection.type),
              let location = list.locationNamed(name, latitude: latitude, longitude: longitude) else {
            return nil
        }
        
        return location.description
    }

    private func showDetailForCurrentSelection() {
        preferredCompactColumn = .detail
        splitViewVisibility = .automatic
    }
}

fileprivate extension SoundingSelection.ModelType {
    var subtitle: String {
        switch self {
        case .sounding:
            "Sounding"
        case .forecast(let model):
            "Model: \(model.description)"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Store<SkewtState>.previewStore)
            .environment(\.appEnvironment, AppEnvironment(isLive: false))
    }
}
