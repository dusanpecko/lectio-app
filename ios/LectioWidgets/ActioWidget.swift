// Actio — domovský widget (iOS WidgetKit).
//
// NASADENIE (v Xcode):
//  1. File → New → Target → Widget Extension  (názov napr. „LectioWidgets",
//     odškrtni „Include Configuration Intent").
//  2. Obsah auto-vygenerovaného .swift súboru NAHRAĎ týmto (nech je @main len raz).
//  3. Pridaj capability „App Groups" na target Runner AJ na widget target a
//     zaškrtni group "group.sk.dpapp.app.ios604688a889d93" (musí sa zhodovať
//     s HomeWidgetService._appGroupId v Dart).
//  4. Build number widget targetu musí byť rovnaký ako Runner.
//
// Dáta zapisuje appka cez balík home_widget; ťuknutie otvorí dnešné Lectio
// (deep-link "lectio-divina://actio" — scheme už je registrovaný v Info.plist).

import WidgetKit
import SwiftUI
import UIKit

private let appGroupId = "group.sk.dpapp.app.ios604688a889d93"

/// Jemný odtieň pozadia widgetu — svetlá levanduľová / tmavá navy podľa režimu.
private func widgetTint() -> Color {
    Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0x1C / 255.0, green: 0x20 / 255.0, blue: 0x30 / 255.0, alpha: 1)
            : UIColor(red: 0xEE / 255.0, green: 0xF0 / 255.0, blue: 0xF7 / 255.0, alpha: 1)
    })
}

struct ActioEntry: TimelineEntry {
    let date: Date
    let text: String
    let reference: String
}

struct ActioProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActioEntry {
        ActioEntry(date: Date(), text: "Dnešný duchovný impulz…", reference: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (ActioEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ActioEntry>) -> Void) {
        // Obnov po najbližšej polnoci (nové actio na ďalší deň).
        let nextMidnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        completion(Timeline(entries: [readEntry()], policy: .after(nextMidnight)))
    }

    private func readEntry() -> ActioEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        return ActioEntry(
            date: Date(),
            text: defaults?.string(forKey: "actio_text") ?? "Otvor dnešné Lectio",
            reference: defaults?.string(forKey: "actio_ref") ?? "")
    }
}

struct ActioWidgetEntryView: View {
    var entry: ActioEntry
    // Brand deep purple #4A5085
    private let brand = Color(red: 0x4A / 255.0, green: 0x50 / 255.0, blue: 0x85 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACTIO")
                .font(.caption2).bold()
                .tracking(1.5)
                .foregroundColor(brand)
            Text(entry.text)
                .font(.system(.callout, design: .serif))
                .italic()
                .lineLimit(5)
                .minimumScaleFactor(0.7)
                .foregroundColor(.primary)
            Spacer(minLength: 0)
            if !entry.reference.isEmpty {
                Text(entry.reference)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "lectio-divina://actio"))
    }
}

@main
struct ActioWidget: Widget {
    let kind: String = "ActioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ActioProvider()) { entry in
            if #available(iOS 17.0, *) {
                ActioWidgetEntryView(entry: entry)
                    .padding()
                    .containerBackground(widgetTint(), for: .widget)
            } else {
                ActioWidgetEntryView(entry: entry)
                    .padding()
                    .background(widgetTint())
            }
        }
        .configurationDisplayName("Actio")
        .description("Dnešný duchovný impulz z Lectio Divina.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
