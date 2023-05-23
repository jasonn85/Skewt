//
//  ContentView.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store<SkewtState>
    @State var selectingTime = false
    
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
        VStack (alignment: .center) {
            header
            
            AnnotatedSkewtPlotView().environmentObject(store).onAppear() {
                store.dispatch(LocationState.Action.requestLocation)
            }
            
            footer
            
            if selectingTime {
                timeSelection
            }
            
            Spacer()
        }
    }
    
    private var header: some View {
        HStack {
            if store.state.currentSoundingState.selection.requiresLocation {
                Image("locationIcon")
                    .offset(y: 1)
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
            }
        }
        .font(.footnote)
        .onTapGesture {
            selectingTime = !selectingTime
        }
    }
    
    private var timeSelection: some View {
        // TODO:
        Text("doing stuff")
    }
    
    private var statusText: String? {
        switch store.state.currentSoundingState.status {
        case .done(let sounding), .refreshing(let sounding):
            let timeAgo = timeAgoFormatter.string(for: sounding.timestamp)!
            let dateString = dateFormatter.string(for: sounding.timestamp)!
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

extension SoundingSelection.ModelType {
    var description: String {
        switch self {
        case .op40:
            return "Op40 forecast"
        case .raob:
            return "Sounding"
        }
    }
}
