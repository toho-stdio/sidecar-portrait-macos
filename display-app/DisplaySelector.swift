//
//  DisplaySelector.swift
//  display-app
//
//  Created by Codex on 31/12/25.
//

import AppKit

struct DisplayInfo {
    let id: CGDirectDisplayID
    let name: String
    let size: CGSize
    let isBuiltin: Bool
}

struct DisplaySelection {
    let sidecar: DisplayInfo
    let virtual: DisplayInfo
}

struct SelectionReport {
    let selection: DisplaySelection?
    let sidecar: DisplayInfo?
    let virtual: DisplayInfo?
    let reason: String?
}

enum DisplaySelector {
    static func selectionReport() -> SelectionReport {
        let displays = allDisplays()
        let screenDisplays = screensAsDisplays()
        guard !displays.isEmpty else {
            return SelectionReport(selection: nil, sidecar: nil, virtual: nil, reason: "No online displays")
        }

        let externalDisplays = displays.filter { !$0.isBuiltin }
        let sidecarIDOverride = UserDefaults.standard.integer(forKey: "sidecarDisplayID")
        let virtualIDOverride = UserDefaults.standard.integer(forKey: "virtualDisplayID")
        let virtualNameOverride = UserDefaults.standard.string(forKey: "virtualDisplayName")

        let sidecar = displayByOverride(id: sidecarIDOverride, displays: displays)
            ?? displayByNameMatch(displays: displays, keywords: ["sidecar", "ipad"])
            ?? displays.first(where: { !$0.isBuiltin && $0.size.width >= $0.size.height })

        let virtual = displayByOverride(id: virtualIDOverride, displays: displays)
            ?? displayByNameContains(displays: screenDisplays, name: virtualNameOverride)
            ?? displayByNameMatch(displays: screenDisplays, keywords: ["virtual", "portrait"])
            ?? displays.first(where: { !$0.isBuiltin && $0.size.height > $0.size.width && $0.id != sidecar?.id })
            ?? displays.first(where: { !$0.isBuiltin && $0.id != sidecar?.id })

        guard let sidecarFinal = sidecar else {
            return SelectionReport(selection: nil, sidecar: nil, virtual: virtual, reason: "Sidecar display not found")
        }

        guard let virtualFinal = virtual else {
            if externalDisplays.count == 1 {
                let onlyDisplay = externalDisplays[0]
                let selection = DisplaySelection(sidecar: onlyDisplay, virtual: onlyDisplay)
                return SelectionReport(selection: selection,
                                       sidecar: onlyDisplay,
                                       virtual: onlyDisplay,
                                       reason: "Only one external display detected; assuming it is both virtual and Sidecar")
            }
            return SelectionReport(selection: nil, sidecar: sidecarFinal, virtual: nil, reason: "Virtual display not found")
        }

        let selection = DisplaySelection(sidecar: sidecarFinal, virtual: virtualFinal)
        return SelectionReport(selection: selection, sidecar: sidecarFinal, virtual: virtualFinal, reason: nil)
    }

    static func debugSummary() -> String {
        let displays = allDisplays()
        let screenNames = screenNameMap()

        var lines: [String] = []
        lines.append("CGOnline: \(displays.count)")
        for info in displays {
            let builtin = info.isBuiltin ? "builtin" : "external"
            let name = screenNames[info.id] ?? info.name
            lines.append(" - \(name) id=\(info.id) \(Int(info.size.width))x\(Int(info.size.height)) \(builtin)")
        }

        lines.append("NSScreen: \(NSScreen.screens.count)")
        for screen in NSScreen.screens {
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let idText = number.map { String($0.uint32Value) } ?? "?"
            let size = screen.frame.size
            lines.append(" - \(screen.localizedName) id=\(idText) \(Int(size.width))x\(Int(size.height))")
        }

        return lines.joined(separator: "\n")
    }

    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first(where: {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return CGDirectDisplayID(number.uint32Value) == displayID
        })
    }

    private static func allDisplays() -> [DisplayInfo] {
        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        let status = CGGetOnlineDisplayList(UInt32(displayIDs.count), &displayIDs, &displayCount)
        guard status == .success else { return [] }

        let screensByID = screenNameMap()

        return displayIDs.prefix(Int(displayCount)).compactMap { displayID in
            guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
            let name = screensByID[displayID] ?? "Display \(displayID)"
            let size = CGSize(width: mode.pixelWidth, height: mode.pixelHeight)
            let isBuiltin = CGDisplayIsBuiltin(displayID) != 0
            return DisplayInfo(id: displayID, name: name, size: size, isBuiltin: isBuiltin)
        }
    }

    private static func screensAsDisplays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let id = CGDirectDisplayID(number.uint32Value)
            let size = screen.frame.size
            let isBuiltin = CGDisplayIsBuiltin(id) != 0
            return DisplayInfo(id: id,
                               name: screen.localizedName,
                               size: size,
                               isBuiltin: isBuiltin)
        }
    }

    private static func screenNameMap() -> [CGDirectDisplayID: String] {
        var map: [CGDirectDisplayID: String] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            map[CGDirectDisplayID(number.uint32Value)] = screen.localizedName
        }
        return map
    }

    private static func displayByOverride(id: Int, displays: [DisplayInfo]) -> DisplayInfo? {
        guard id != 0 else { return nil }
        return displays.first(where: { $0.id == CGDirectDisplayID(id) })
    }

    private static func displayByNameMatch(displays: [DisplayInfo], keywords: [String]) -> DisplayInfo? {
        let lowered = keywords.map { $0.lowercased() }
        return displays.first(where: { info in
            let name = info.name.lowercased()
            return lowered.contains(where: { name.contains($0) })
        })
    }

    private static func displayByNameContains(displays: [DisplayInfo], name: String?) -> DisplayInfo? {
        guard let name, !name.isEmpty else { return nil }
        let needle = name.lowercased()
        return displays.first(where: { $0.name.lowercased().contains(needle) })
    }
}
