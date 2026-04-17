// set-default-input.swift
// macOS audio INPUT device helper using CoreAudio.
//
// Usage:
//   set-default-input --list           → prints JSON array of input devices
//   set-default-input "Device Name"    → sets the default input to that device
//
// Exit codes: 0 = success, 1 = bad args, 2 = device not found, 3 = CoreAudio error
import CoreAudio
import Foundation

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: set-default-input --list | \"Device Name\"\n".data(using: .utf8)!)
    exit(1)
}
let cmdArg = CommandLine.arguments[1]
let listMode = cmdArg == "--list"
let target = cmdArg

// Get all audio device IDs
var listAddr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
var size: UInt32 = 0
var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &size)
if status != 0 { exit(3) }
let count = Int(size) / MemoryLayout<AudioDeviceID>.size
var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &listAddr, 0, nil, &size, &deviceIDs)
if status != 0 { exit(3) }

// Iterate all devices, collect input-capable ones
struct DevInfo { let id: AudioDeviceID; let name: String }
var inputDevices: [DevInfo] = []
for id in deviceIDs {
    var streamAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )
    var streamSize: UInt32 = 0
    AudioObjectGetPropertyDataSize(id, &streamAddr, 0, nil, &streamSize)
    if streamSize == 0 { continue }

    var nameAddr = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var cfName: Unmanaged<CFString>?
    var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let nStatus = AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &cfName)
    if nStatus != 0 { continue }
    let deviceName = cfName?.takeRetainedValue() as String? ?? ""
    inputDevices.append(DevInfo(id: id, name: deviceName))
}

if listMode {
    // Emit JSON array: [{"name":"Built-in Microphone","id":123},...]
    let parts = inputDevices.map { "{\"name\":\"\($0.name.replacingOccurrences(of: "\"", with: "\\\""))\",\"id\":\($0.id)}" }
    print("[" + parts.joined(separator: ",") + "]")
    exit(0)
}

// Set mode: find by case-insensitive equality, then contains
let tLow = target.lowercased()
var match: DevInfo? = inputDevices.first { $0.name.lowercased() == tLow }
if match == nil { match = inputDevices.first { $0.name.lowercased().contains(tLow) } }
if match == nil { match = inputDevices.first { tLow.contains($0.name.lowercased()) } }

guard let found = match else {
    FileHandle.standardError.write("Device not found: \(target)\n".data(using: .utf8)!)
    FileHandle.standardError.write("Available: \(inputDevices.map{$0.name}.joined(separator: ", "))\n".data(using: .utf8)!)
    exit(2)
}

var setAddr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)
var newID = found.id
let sStatus = AudioObjectSetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &setAddr, 0, nil,
    UInt32(MemoryLayout<AudioDeviceID>.size), &newID
)
if sStatus == 0 {
    print("OK: \(found.name)")
    exit(0)
}
FileHandle.standardError.write("CoreAudio set error: \(sStatus)\n".data(using: .utf8)!)
exit(3)
