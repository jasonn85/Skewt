//
//  SoundingTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 7/26/23.
//

import SwiftUI

struct SoundingTimeSelectView: View {
    @Binding var value: TimeInterval
    var daysRange = 7
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    private var gmtTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = .gmt
        formatter.dateFormat = "HH:mm'Z'"
        return formatter
    }

    var body: some View {
        Picker("Sounding time", selection: $value) {
            ForEach(intervals, id: \.self) {
                description(forInterval: $0)
            }
        }
        .pickerStyle(.wheel)
    }
    
    private var intervals: [TimeInterval] {
        let soundingInterval = TimeInterval(12.0 * 60.0 * 60.0)  // 12 hours
        let startDate = Date(timeIntervalSinceNow: -Double(daysRange) * 24.0 * 60.0 * 60.0)
        let mostRecentDate = Date.mostRecentSoundingTime()
        
        let mostRecentIntervalFromNow = mostRecentDate.timeIntervalSinceNow
        let startIntervalFromNow = startDate.timeIntervalSinceNow
        
        return Array(stride(from: mostRecentIntervalFromNow, through: startIntervalFromNow, by: -soundingInterval))
    }
    
    @ViewBuilder
    private func description(forInterval interval: TimeInterval) -> some View {
        let date = Date(timeIntervalSinceNow: interval)
        
        HStack {
            Text(gmtTimeFormatter.string(from: date))
                .bold()
                .padding(8)
            
            Text(relativeFormatter.localizedString(fromTimeInterval: interval))
        }
    }
}

struct SoundingTimeSelectView_Previews: PreviewProvider {
    static var previews: some View {
        @State var value = TimeInterval(0)
        
        SoundingTimeSelectView(value: $value)
    }
}
