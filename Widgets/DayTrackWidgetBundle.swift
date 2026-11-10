import SwiftUI
import WidgetKit

@main
struct DayTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        InstallCheckWidget()
        RestTimerLiveActivity()
    }
}
