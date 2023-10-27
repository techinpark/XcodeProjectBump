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
        if let specificPath = path {
            if !FileManager.default.fileExists(atPath: specificPath) {
                print("\u{001B}[31m No Info.plist file found at specified path.\u{001B}[0m")
                throw ExitCode.failure
            }
            updateVersion(inFile: specificPath, major: major, minor: minor, hotfix: hotfix, build: build)
        } else {
            let allPlistPaths = try findAllPlistPaths()
            let selectedPaths = promptUserToSelectPlist(plistPaths: allPlistPaths)
            for plistPath in selectedPaths {
                updateVersion(inFile: plistPath, major: major, minor: minor, hotfix: hotfix, build: build)
            }
        }
    }
    
    
    private func findDefaultPlistPath() throws -> String {
        if let projectPath = try? FileManager.default.contentsOfDirectory(atPath: FileManager.default.currentDirectoryPath).first(where: { $0.hasSuffix(".xcodeproj") }) {
            print("🔍 \u{001B}[32m\(projectPath)\u{001B}[0m found")
            let xcodeProject = try XcodeProj(pathString: projectPath)
            
            for conf in xcodeProject.pbxproj.buildConfigurations where conf.buildSettings[Keys.infoPlistFile] != nil {
                if let plistPath = conf.buildSettings[Keys.infoPlistFile] as? String {
                    print("🎉 \u{001B}[32m\(plistPath)\u{001B}[0m found")
                    return plistPath
                }
            }
        }
        
        throw NSError(domain: "XcodeProjectBump", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to locate Info.plist in the current directory."])
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
    
    func printUpdateMessage(previousVersion: String, previousBuild: String, updatedVersion: String, updatedBuild: String) {
        let versionOutput = "[+] updated version : \u{001B}[31m\(previousVersion)(\(previousBuild))\u{001B}[0m ➡️  \u{001B}[32m\(updatedVersion)(\(updatedBuild))\u{001B}[0m"
        print(versionOutput)
    }
    
    func updateVersion(inFile filename: String, major: Bool, minor: Bool, hotfix: Bool, build: Bool) {
        guard let plistData = FileManager.default.contents(atPath: filename) else {
            print("Failed to read the plist file.")
            return
        }
        
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var plist = try? PropertyListSerialization.propertyList(from: plistData, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] else {
            print("Failed to read the plist data.")
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
           let updatedVersion = updatedVersion,
           let updatedBuild = updatedBuild {
            
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
