//
//  HourlyTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 5/23/23.
//

import SwiftUI

struct HourlyTimeSelectView: View {
    @Binding var value: SoundingSelection.Time
    @State var range: ClosedRange<TimeInterval>
    @State var stepSize: TimeInterval = .hours(1)
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter
    }
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .middleOfSentence
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    var body: some View {
        VStack {
            Slider(
                value: Binding<TimeInterval>(
                    get: {
                        switch value {
                        case .relative(let interval):
                            return interval
                        default:
                            return 0.0
                        }
                    },
                    set: { value = $0 == 0.0 ? .now : .relative($0) }
                ),
                in: range,
                step: stepSize
            ) {
                Text("Time")
            }
            
            let date = Date.nearestHour(
                withIntervalFromNow: value.asInterval,
                hoursPerInterval: Int(stepSize / (60.0 * 60.0))
            )
            let absoluteString = formatter.string(from: date)
            let relativeString = relativeFormatter.localizedString(fromTimeInterval: value.asInterval)
            
            Text("\(absoluteString) (\(relativeString))")
                .font(.footnote)
        }
        .scenePadding(.horizontal)
    }
}

extension SoundingSelection.Time {
    public var asInterval: TimeInterval {
        switch self {
        case .now:
            return 0.0
        case .relative(let interval):
            return interval
        case .specific(let date):
            return Date.now.timeIntervalSince(date)
        case .numberOfSoundingsAgo(_):
            return 0.0
        }
    }
}

extension TimeInterval {
    static func hours(_ hours: Int) -> TimeInterval {
        Double(hours) * 60.0 * 60.0
    }
}

struct TimeSelectView_Previews: PreviewProvider {
    static var previews: some View {
        var time = SoundingSelection.Time.now

        HourlyTimeSelectView(
            value: Binding<SoundingSelection.Time>(get: { time }, set: { time = $0 }),
            range: .hours(-24)...TimeInterval.hours(24)
        )
    }
}
