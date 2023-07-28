//
//  HourlyTimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 5/23/23.
//

import SwiftUI

struct HourlyTimeSelectView: View {
    @Binding var value: TimeInterval
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
                value: $value,
                in: range,
                step: stepSize
            ) {
                Text("Time")
            }
            
            let absoluteString = formatter.string(from: Date(timeIntervalSinceNow: value))
            let relativeString = relativeFormatter.localizedString(fromTimeInterval: value)
            
            Text("\(absoluteString) (\(relativeString))")
                .font(.footnote)
        }
        .scenePadding(.horizontal)
    }
}

extension TimeInterval {
    static func hours(_ hours: Int) -> TimeInterval {
        Double(hours) * 60.0 * 60.0
    }
}

struct TimeSelectView_Previews: PreviewProvider {
    static var previews: some View {
        var time = TimeInterval(0)

        HourlyTimeSelectView(
            value: Binding<TimeInterval>(get: { time }, set: { time = $0 }),
            range: .hours(-24)...TimeInterval.hours(24)
        )
    }
}
