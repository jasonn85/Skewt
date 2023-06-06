//
//  TimeSelectView.swift
//  Skewt
//
//  Created by Jason Neel on 5/23/23.
//

import SwiftUI

struct TimeSelectView: View {
    @Binding var value: TimeInterval
    @State var range: ClosedRange<TimeInterval>
    var maximumRange: ClosedRange<TimeInterval>
    @State var stepSize: TimeInterval = .hours(1)
    
    private var formatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.formattingContext = .standalone
        formatter.dateTimeStyle = .named
        return formatter
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 20) {
                Button("<") {
                    if (range.lowerBound - stepSize) >= maximumRange.lowerBound {
                        range = (range.lowerBound - stepSize)...range.upperBound
                    }
                }
                
                Slider(
                    value: $value,
                    in: range,
                    step: stepSize
                ) {
                    Text("Time")
                }
                
                Button(">") {
                    if (range.upperBound + stepSize) <= maximumRange.upperBound {
                        range = range.lowerBound...(range.upperBound + stepSize)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Text(formatter.localizedString(fromTimeInterval: value))
                .font(.footnote)
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
        var time = TimeInterval(0)

        TimeSelectView(
            value: Binding<TimeInterval>(get: { time }, set: { time = $0 }),
            range: .hours(-2)...TimeInterval.hours(12),
            maximumRange: .hours(-12)...TimeInterval.hours(24)
        )
    }
}
