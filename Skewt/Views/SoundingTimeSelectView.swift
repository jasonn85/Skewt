//
//  SoundingTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 7/26/23.
//

import SwiftUI

struct SoundingTimeSelectView: View, Equatable {
    @Binding var value: TimeInterval
    let daysRange = 7
    var date: Date = Date()
    
    // Since the time intervals we show are computed based on current time, SwiftUI thinks
    //  our Picker constantly needs to be reloaded. By instead making our view equatable based on
    //  the most recent sounding time, the Picker will only be reloaded if we cross 0000Z/1200Z time.
    static func == (lhs: SoundingTimeSelectView, rhs: SoundingTimeSelectView) -> Bool {
        Date.mostRecentSoundingTime(toDate: lhs.date) == Date.mostRecentSoundingTime(toDate: rhs.date)
    }
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    private var gmtTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = .gmt
        formatter.dateFormat = "EEEE HH:mm'Z'"
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
