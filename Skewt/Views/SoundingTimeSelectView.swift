//
//  SoundingTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 7/26/23.
//

import SwiftUI

struct SoundingTimeSelectView: View, Equatable {
    @Binding var value: SoundingSelection.Time
    var hourInterval = SoundingSelection.ModelType.raob.hourInterval
    let daysRange = 7
    var date: Date = .now
    
    private var intervals: [TimeInterval]
    
    // Since the time intervals we show are computed based on current time, SwiftUI thinks
    //  our Picker constantly needs to be reloaded. By instead making our view equatable based on
    //  the most recent sounding time, the Picker will only be reloaded if we cross 0000Z/1200Z time.
    static func == (lhs: SoundingTimeSelectView, rhs: SoundingTimeSelectView) -> Bool {
        Date.mostRecentSoundingTime(toDate: lhs.date) == Date.mostRecentSoundingTime(toDate: rhs.date)
    }
    
    init(value: Binding<SoundingSelection.Time>, hourInterval: Int = SoundingSelection.ModelType.raob.hourInterval, date: Date = .now) {
        _value = value
        self.hourInterval = 12
        self.date = .now
        
        self.hourInterval = hourInterval
        self.date = date

        let soundingInterval = TimeInterval(Double(hourInterval) * 60.0 * 60.0)  // 12 hours
        let startDate = Date(timeIntervalSinceNow: -Double(daysRange) * 24.0 * 60.0 * 60.0)
        let mostRecentDate = Date.mostRecentSoundingTime()

        let mostRecentIntervalFromNow = mostRecentDate.timeIntervalSinceNow
        let startIntervalFromNow = startDate.timeIntervalSinceNow

        intervals = Array(stride(from: mostRecentIntervalFromNow, through: startIntervalFromNow, by: -soundingInterval))
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
    
    private var intervalIndex: Int {
        switch value {
        case .now:
            return 0
        case .numberOfSoundingsAgo(let soundingIndex):
            return soundingIndex - 1
        default:
            return 0
        }
    }

    var body: some View {
        Picker("Sounding time", selection: Binding<Int>(
            get: {
                switch value {
                case .numberOfSoundingsAgo(let soundingIndex):
                    return soundingIndex - 1
                default:
                    return 0
                }
            },
            set: {
                if $0 == 0 {
                    value = .now
                } else {
                    value = .numberOfSoundingsAgo($0 + 1)
                }
            })
        ) {
            ForEach(0..<(daysRange * 24 / hourInterval), id: \.self) {
                description(forInterval: intervals[$0])
            }
        }
        .pickerStyle(.wheel)
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
        var time = SoundingSelection.Time.now
        SoundingTimeSelectView(value: Binding<SoundingSelection.Time>(get: { time }, set: { time = $0 }))
    }
}
