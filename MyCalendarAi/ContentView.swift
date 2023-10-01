//
//  ContentView.swift
//  MyCalendarAi
//
//  Created by Randy Fong on 10/1/23.
//

import SwiftUI
import EventKit
import OpenAIKit

struct EventCalendar: Identifiable {
    let id = UUID()
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date
    let notes: String
    let url: URL?
}

struct ContentView: View {
    @State var event: String = ""
    @State var location: String = ""
    @State var store = EKEventStore()
    @State var source = EKSource()
    @State var calendarEvents = [EventCalendar]()
    @State var notes: String = ""
    var body: some View {
            Form {
            TextField("Event", text: $event)
            TextField("Location", text: $location, axis: .vertical)
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .padding()
            }
        .onAppear {
            Task {
                let isAuthorized = try await requestAccess()
                if isAuthorized {
                    await getEvents()
                }
            }
        }
    }
    
    func requestAccess(to: EKEntityType = .event) async throws -> Bool{
        return try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: to) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func getEvents() async {
        let calendars = store.calendars(for: .event)
        
        for calendar in calendars {
            if calendar.title == "Calendar" {
                let oneMonthAgo = Date(timeIntervalSinceNow: 0*20*3600)
                let oneMonthAfter = Date(timeIntervalSinceNow: 7*24*3600)
                let predicate =  store.predicateForEvents(withStart: oneMonthAgo, end: oneMonthAfter, calendars: [calendar])
                
                let events = store.events(matching: predicate)
                calendarEvents.removeAll()
                events.forEach {
                    if $0.title == "Lunch" {
                        let event = EventCalendar(title: $0.title, location: $0.location ?? "", startDate: $0.startDate, endDate: $0.endDate, notes: $0.notes ?? "", url: $0.url)
                        calendarEvents.append(event)
                        // print(calendarEvents.last)
                    }
                }
                if let lastCalendarEvent = calendarEvents.last {
                    event = lastCalendarEvent.title
                    location = lastCalendarEvent.location
                    try? await sendPrompt(lastCalendarEvent)
                }
 
            }
        }
    }
        
    func sendPrompt(_ event: EventCalendar) async throws {
        let openAI = OpenAIKit(apiToken: "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")
        
        
        let prompt = event.notes
        let result = await openAI.sendCompletion(prompt: prompt, model: .gptV3_5(.davinciText003), maxTokens: 2048)

        switch result {
        case .success(let aiResult):
            if let text = aiResult.choices.first?.text {
                notes = text
                // print("\(text)")
            }
        case .failure(let error):
            print(error.localizedDescription)
        }
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
