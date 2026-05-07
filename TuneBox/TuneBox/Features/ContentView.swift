//
//  ContentView.swift
//  TuneBox
//
//  Created by Vadim Sorokolit on 06.05.2026.
//

import SwiftUI
import Resolver

struct ContentView: View {

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .modifier(LoadViewModifier())
    }

    struct LoadViewModifier: ViewModifier {
        @Injected var networkService: NetworkServicing

        func body(content: Content) -> some View {
            content
                .onAppear {
                    Task {
                        do {
                            let size = try await networkService.getTrackSize(id: 62319213)
                            print(size)
                        } catch {
                            print(APIError.from(error).localizedDescription)
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
