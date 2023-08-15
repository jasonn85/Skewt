# Skew-T²
An open-source, iOS app for viewing sounding data and forecasts from NOAA

## What is a Skew-T Log-P plot?
If weather is the Matrix, reading a Skew-T Log-P chart is reading the green text. Metereologists and glider pilots understand. Pilots all should!

### The lines
The two plotted lines are temperature and moisture (dew point). Height is height. (Pressure is plotted logarithmically, hence Log-P). Left is cold; right is hot. Temperature is skewed so that a constant temperature atmosphere would slope up and to the right, hence Skew-T.

### Lines touch = clouds
The temperature falling to the dew point makes clouds/dew/precipitation. This would be shown as the temperature plot touching the dew point plot:

Low clouds:
_TODO: sample plot_

High clouds:
_TODO: sample plot_

Rain:
_TODO: sample plot_

### The other lines
All sorts of other weather characteristics are easily identifiable on a Skew-T Log-P plot. The plot often includes guidelines that show how temperature tends to fall with altitude for dry and moist air. These can be used to predict icing, convective activity/thunderstorms, and wind shear, to start.

### What is this data?
#### Soundings
Weather balloons are released twice a day from dozens of locations around the US and hundreds around the world.

#### Forecasts
NOAA forecasts provide predicted sounding data on a grid. The default model (Op40) is hourly on a 40km grid for up to 18 hours in the future.

### Skew-T Log-P references
- [NOAA's sounding web API](https://rucsoundings.noaa.gov/)
- An explanation of Skew-T Log-P for pilots: [Return of Skew-T](https://www.ifr-magazine.com/training-sims/return-of-skew-t/)
- An overview of information that can be divined from a plot: [Skew-T tutorials](https://www.weather.gov/source/zhu/ZHU_Training_Page/convective_parameters/skewt/skewtinfo.html)
	- Example Skew-Ts for specific types of weather: [Different Weather Soundings](https://www.weather.gov/source/zhu/ZHU_Training_Page/convective_parameters/skewt/skewtinfo.html#SKEW3)
- A five minute video, explaining weather balloons, Skew-T plots, and how to read them: [Weather Explained: Intro to Reading Skew-T Graphs](https://youtu.be/1lJ9Kaieoco)
	

## How was this app built?
### SwiftUI

### Redux
- A custom implementation of Redux was built, following this article: [Redux architecture and mind-blowing features](https://wojciechkulik.pl/ios/redux-architecture-and-mind-blowing-features)
- Every view uses a `Store` `@EnvironmentObject` with one immutable state
- Each UI action dispatches an `Action` to the store
- Every state struct has a `Reducer` pure function to turn a `State` and an `Action` into a new `State`
- `Middleware`s handle remote data, saving state, logging, and handling location data

### Combine
- Network requests are all performed via `URLSession.shared.dataTaskPublisher`, mapping responses and failures to Redux actions
- Debounced UI is handled via bindings and Combine, e.g.
```swift     
debouncer = $timeInterval
	.debounce(for: .seconds(0.2), scheduler: RunLoop.main)
	.removeDuplicates()
	.sink(receiveValue: { [weak self] in
	    self?.store?.dispatch(SoundingState.Action.changeAndLoadSelection(.selectTime(.relative($0))))
	})
```

