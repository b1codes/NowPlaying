//
//  iOS_WidgetBundle.swift
//  iOS Widget
//
//  Created by Brandon Lamer-Connolly on 8/30/25.
//

import WidgetKit
import SwiftUI

@main
struct IOSWidgetBundle: WidgetBundle {
    var body: some Widget {
        IOSWidget()
        IOSWidgetControl()
        IOSWidgetLiveActivity()
    }
}
