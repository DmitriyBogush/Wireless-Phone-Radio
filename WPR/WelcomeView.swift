//
//  WelcomeView.swift
//  WPR
//
//  Created by Dmitriy Bogush on 11/29/22.
//

import SwiftUI

struct WelcomeView: View {
    @State var isActive:Bool = false
    
    var body: some View {
        VStack {
            // 2.
            if self.isActive {
                // 3.
                ContentView()
            } else {
                // 4.
                Image("home")
                    .resizable()
                    .scaledToFit()
            }
        }
        // 5.
        .onAppear {
            // 6.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                // 7.
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
