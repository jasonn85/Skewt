# <img alt="Skew-T logo" align="top" src="https://github.com/jasonn85/Skewt/assets/1328743/cf0a415c-214d-4c3b-847b-41530bbec41e">&nbsp; Skew-T²
An open-source, iOS app for viewing sounding data and forecasts from NOAA

# What's a Skew-T Log-P?
If weather is the Matrix, reading a Skew-T Log-P chart is reading the green text. Metereologists and glider pilots understand. All pilots should!

## 📈 The lines
The two plotted lines are temperature (red) and moisture/dew point (blue). Height is height. (Pressure altitude is plotted logarithmically, hence Log-P). Left is cold; right is hot. Temperature is skewed so that a constant temperature atmosphere would slope up and to the right, hence Skew-T.

![Temperature line example](https://github.com/jasonn85/Skewt/assets/1328743/a8de626d-3a9e-4129-8153-b1dec61b286b)

## ☁️ Lines touch = clouds
The temperature falling to the dew point makes clouds/dew/precipitation. This would be shown as the temperature plot touching or nearly touching the dew point plot.

Here is a low marine layer of clouds:

![Marine layer example](https://github.com/jasonn85/Skewt/assets/1328743/dfd3408b-1f67-4744-8ea8-ccd1bdbc08ac)

And a thick layer of rain:

![Rain example](https://github.com/jasonn85/Skewt/assets/1328743/3a764043-3b45-4701-ac04-4e4a1d7595a4)


## 📐 The other lines
All sorts of other weather characteristics are easily identifiable on a Skew-T Log-P plot. The plot often includes guidelines that show how temperature tends to fall with altitude for dry and moist air. These can be used to predict icing, convective activity/thunderstorms, and wind shear, to start.

<img width="335" alt="Guidelines" src="https://github.com/jasonn85/Skewt/assets/1328743/df9ceb27-a238-4f28-b29f-68123bbaf5fc">

# What is this data?
## 🎈 Soundings
Weather balloons are released twice a day from dozens of locations around the US and hundreds around the world.

## 🧮 Forecasts
NOAA forecasts provide predicted sounding data on a grid. The default model (Op40) is hourly on a 40km grid for up to 18 hours in the future.

## 🇺🇸 US only?
The sole data source is the US's NOAA. Forecast data is only available for the US, but 12 hour soundings _are_ available from US military bases all over the world.

# Further Skew-T Log-P references
- [NOAA's sounding web API](https://rucsoundings.noaa.gov/)
- [Return of Skew-T](https://www.ifr-magazine.com/training-sims/return-of-skew-t/)
    - An explanation of Skew-T Log-P for pilots
- [Skew-T tutorials](https://www.weather.gov/source/zhu/ZHU_Training_Page/convective_parameters/skewt/skewtinfo.html)
    - An overview of information that can be divined from a plot
        - [Examples of some typical patterns](https://www.weather.gov/source/zhu/ZHU_Training_Page/convective_parameters/skewt/skewtinfo.html#SKEW3)
- [Weather Explained: Intro to Reading Skew-T Graphs](https://youtu.be/1lJ9Kaieoco)
    - A five minute video, explaining weather balloons, Skew-T plots, and how to read them
	

# How was this app built?
## SwiftUI
- Fully declarative UI
- Immutable state managed via...

## Redux
- A dirt simple implementation of Redux, following this article: [Redux architecture and mind-blowing features](https://wojciechkulik.pl/ios/redux-architecture-and-mind-blowing-features)
- Every view uses a `@EnvironmentObject var store: Store<SkewtState>` with `@Published private(set) var state: State`
- Each UI action dispatches an `Action` to the store's `dispatch`
- Every state struct has a `Reducer` pure function to turn a `State` and an `Action` into a new `State`
- `Middleware`s handle remote data, saving state, logging, and handling location data

## Combine
- Network requests are all performed via `URLSession.shared.dataTaskPublisher`, mapping responses and failures to Redux actions
- Debounced UI is handled via bindings and Combine

# What's in the works?
- [Wind barbs](https://github.com/jasonn85/Skewt/issues/32)
- [Interactive details](https://github.com/jasonn85/Skewt/issues/24) (touch a specific point to see temp/dew point/wind)
- [Parcel analysis/CAPE](https://github.com/jasonn85/Skewt/issues/44)
- [Lots](https://github.com/jasonn85/Skewt/issues/33) of [background](https://github.com/jasonn85/Skewt/issues/34) [animations](https://github.com/jasonn85/Skewt/issues/35) for predicted weather
- [Pinch zooming](https://github.com/jasonn85/Skewt/issues/7)
- [Tutorials](https://github.com/jasonn85/Skewt/issues/37)

# Privacy
- No user data is collected, period. This may be revisted later for anonymous analytics.
- User location, if granted, is anonymized before being sent to any external API.

# Free?
Skew-T Log-P plots will stay free as long as a free API exists. Future interactive lessons, quizzes, integrations with external tools, and more advanced visualizations may appear with a cost.

# Hire me to build your app
[Itsa me](https://github.com/jasonn85)
