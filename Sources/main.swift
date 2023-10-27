import Foundation
import ArgumentParser
import XcodeProj

struct Keys {
    static let infoPlistFile = "INFOPLIST_FILE"
    static let bundleShortVersion = "CFBundleShortVersionString"
    static let bundleVersion = "CFBundleVersion"
}

struct VersionUpdater: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A Swift command-line tool to update the version in Info.plist"
    )
    
    @Flag(help: "Update the major version.")
    var major: Bool = false
    
    @Flag(help: "Update the minor version.")
    var minor: Bool = false
    
    @Flag(help: "Update the hotfix version.")
    var hotfix: Bool = false
    
    @Flag(help: "Update the build version.")
    var build: Bool = false
    
    @Option(name: .shortAndLong, help: "Path to the Info.plist.")
    var path: String?
    
    func run() throws {
        let foundPlistPaths = try findDefaultPlistPaths()
        
        print("\nSelect the Info.plist files you want to update by entering their numbers (comma-separated for multiple):")
        for (index, path) in foundPlistPaths.enumerated() {
            print("[\(index)] \(path)")
        }
        
        guard let userInput = readLine() else {
            print("\u{001B}[31mInvalid selection.\u{001B}[0m")
            throw ExitCode.failure
        }

        let selectedIndices = userInput.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        for index in selectedIndices {
            if index >= 0 && index < foundPlistPaths.count {
                updateVersion(
                    inFile: foundPlistPaths[index],
                    major: major,
                    minor: minor,
                    hotfix: hotfix,
                    build: build
                )
            } else {
                print("\u{001B}[31mInvalid index: \(index). Skipping...\u{001B}[0m")
            }
        }
    }
    
    private func findDefaultPlistPaths() throws -> [String] {
        var foundPlistPaths: [String] = []
        
        if let projectPath = try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath).first(where: { $0.hasSuffix(".xcodeproj") }) {
            print("🔍 \u{001B}[32m\(projectPath)\u{001B}[0m found")
            let xcodeProject = try XcodeProj(pathString: projectPath)
            
            for conf in xcodeProject.pbxproj.buildConfigurations where conf.buildSettings[Keys.infoPlistFile] != nil {
                if let plistPath = conf.buildSettings[Keys.infoPlistFile] as? String, !foundPlistPaths.contains(plistPath) {
                    foundPlistPaths.append(plistPath)
                    print("🎉 \u{001B}[32m\(plistPath)\u{001B}[0m found")
                }
            }
        }
        
        if foundPlistPaths.isEmpty {
            throw NSError(domain: "XcodeProjectBump", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to locate any Info.plist in the current directory."])
        }
        
        return foundPlistPaths
    }
    
    private func findAllPlistPaths() throws -> [String] {
        guard let projectPath = try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath).first(where: { $0.hasSuffix(".xcodeproj") }) else {
            throw NSError(domain: "XcodeProjectBump", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to locate an Xcode project in the current directory."])
        }
        
        let xcodeProject = try XcodeProj(pathString: projectPath)
        var plistPaths: [String] = []
        
        for conf in xcodeProject.pbxproj.buildConfigurations {
            if let plistPath = conf.buildSettings[Keys.infoPlistFile] as? String {
                print("🎉 \u{001B}[32m\(plistPath)\u{001B}[0m found")
                plistPaths.append(plistPath)
            }
        }
        return plistPaths
    }
    
    // 2. 사용자에게 선택 가능한 목록 표시
    private func promptUserToSelectPlist(plistPaths: [String]) -> [String] {
        print("Multiple Info.plist files found:")
        for (index, path) in plistPaths.enumerated() {
            print("[\(index + 1)] \(path)")
        }
        print("Enter the numbers of the Info.plist files you want to update (comma separated):")
        guard let input = readLine() else { return [] }
        let selectedIndices = input.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return selectedIndices.compactMap { index in
            guard index > 0 && index <= plistPaths.count else { return nil }
            return plistPaths[index - 1]
        }
    }
    
    func printUpdateMessage(previousVersion: String, previousBuild: String, updatedVersion: String, updatedBuild: String?) {
        
        if let updatedBuild {
            let versionOutput = "[+] updated version : \u{001B}[31m\(previousVersion)(\(previousBuild))\u{001B}[0m ➡️  \u{001B}[32m\(updatedVersion)(\(updatedBuild))\u{001B}[0m"
            print(versionOutput)
        } else {
            let versionOutput = "[+] updated version : \u{001B}[31m\(previousVersion)\u{001B}[0m ➡️  \u{001B}[32m\(updatedVersion)\u{001B}[0m"
            print(versionOutput)
        }
    }
    
    func updateVersion(inFile filename: String, major: Bool, minor: Bool, hotfix: Bool, build: Bool) {
        guard let plistData = FileManager.default.contents(atPath: filename) else {
            print("Failed to read the plist file at \(filename).")
            return
        }
        
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var plist = try? PropertyListSerialization.propertyList(from: plistData, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
            print("Failed to read the plist data at \(filename).")
            return
        }
        
        var previousVersion: String?
        var previousBuild: String?
        var updatedVersion: String?
        var updatedBuild: String?
        
        if let versionString = plist[Keys.bundleShortVersion] as? String {
            previousVersion = versionString
            
            var components = versionString.split(separator: ".").map { Int($0) ?? 0 }
            
            if major {
                components[0] += 1
                components[1] = 0
                components[2] = 0
            } else if minor {
                components[1] += 1
                components[2] = 0
            } else if hotfix {
                components[2] += 1
            }
            
            updatedVersion = components.map { "\($0)" }.joined(separator: ".")
            plist[Keys.bundleShortVersion] = updatedVersion
        }
        
        if let buildNumberString = plist[Keys.bundleVersion] as? String {
            previousBuild = buildNumberString
            
            if let buildNumber = Int(buildNumberString) {
                updatedBuild = "\(buildNumber + 1)"
                plist[Keys.bundleVersion] = updatedBuild
            }
        }
        
        let newData = try? PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        try? newData?.write(to: URL(fileURLWithPath: filename))
        
        if let prevVersion = previousVersion,
           let prevBuild = previousBuild,
           let updatedVersion = updatedVersion {
            
            printUpdateMessage(
                previousVersion: prevVersion,
                previousBuild: prevBuild,
                updatedVersion: updatedVersion,
                updatedBuild: updatedBuild
            )
        }
    }

}

VersionUpdater.main()
