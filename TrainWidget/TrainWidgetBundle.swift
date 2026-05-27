//
//  TrainWidgetBundle.swift
//  TrainWidget
//
//  Created by Carlo ‎Porta on 05/05/2026.
//

import WidgetKit
import SwiftUI

@main
struct TrainWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrainWidget()
        TrainWidgetControl()
        TrainWidgetLiveActivity()
    }
}
