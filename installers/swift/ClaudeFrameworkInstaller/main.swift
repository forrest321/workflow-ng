#!/usr/bin/env swift

import Foundation
import AppKit

class ClaudeFrameworkInstaller {
    let frameworkPath: String
    let fileManager = FileManager.default
    var logOutput: String = ""
    
    init() {
        self.frameworkPath = Self.detectFrameworkPath() ?? ""
    }
    
    static func detectFrameworkPath() -> String? {
        let fm = FileManager.default
        let currentPath = fm.currentDirectoryPath
        
        // Check common locations
        let searchPaths = [
            currentPath,
            NSString(string: "~/Documents/code/workflow-ng").expandingTildeInPath,
            NSString(string: "~/claude-workflow-framework").expandingTildeInPath,
            NSString(string: "~/workflow-ng").expandingTildeInPath
        ]
        
        for path in searchPaths {
            let claudeMd = "\(path)/CLAUDE.md"
            let concurrencyDir = "\(path)/concurrency"
            
            if fm.fileExists(atPath: claudeMd) && fm.fileExists(atPath: concurrencyDir) {
                return path
            }
        }
        
        // Search parent directories
        var searchDir = currentPath
        while searchDir != "/" {
            let claudeMd = "\(searchDir)/CLAUDE.md"
            let concurrencyDir = "\(searchDir)/concurrency"
            
            if fm.fileExists(atPath: claudeMd) && fm.fileExists(atPath: concurrencyDir) {
                return searchDir
            }
            searchDir = NSString(string: searchDir).deletingLastPathComponent
        }
        
        return nil
    }
    
    func log(_ message: String) {
        logOutput += message + "\n"
        print(message)
    }
    
    func runCommand(_ command: String, args: [String] = []) -> (output: String, exitCode: Int32) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.standardInput = nil
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (output, task.terminationStatus)
        } catch {
            return ("Error: \(error)", 1)
        }
    }
    
    func safeCopy(from source: String, to destination: String, description: String) -> Bool {
        do {
            if fileManager.fileExists(atPath: source) {
                try fileManager.copyItem(atPath: source, toPath: destination)
                log("✓ Copied \(description)")
                return true
            } else {
                log("⚠ Skipped \(description) (not found)")
                return false
            }
        } catch {
            log("✗ Failed to copy \(description): \(error)")
            return false
        }
    }
    
    func createDirectoryStructure(at targetPath: String) throws {
        let claudePath = "\(targetPath)/.claude"
        let subdirs = ["config", "coordination", "scripts", "templates", "metrics", "logs"]
        
        try fileManager.createDirectory(atPath: claudePath, withIntermediateDirectories: true)
        
        for dir in subdirs {
            try fileManager.createDirectory(atPath: "\(claudePath)/\(dir)", withIntermediateDirectories: true)
        }
        
        // Create coordination subdirectories
        let coordDirs = ["tasks", "claims", "agents", "status", "logs"]
        for dir in coordDirs {
            try fileManager.createDirectory(atPath: "\(claudePath)/coordination/\(dir)", withIntermediateDirectories: true)
        }
    }
    
    func detectProjectType(at path: String) -> String {
        if fileManager.fileExists(atPath: "\(path)/package.json") {
            return "node"
        } else if fileManager.fileExists(atPath: "\(path)/requirements.txt") || 
                  fileManager.fileExists(atPath: "\(path)/pyproject.toml") {
            return "python"
        } else if fileManager.fileExists(atPath: "\(path)/go.mod") {
            return "go"
        } else if fileManager.fileExists(atPath: "\(path)/Cargo.toml") {
            return "rust"
        } else {
            return "unknown"
        }
    }
    
    func installFramework(to targetPath: String, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var success = true
            
            // Validate framework path
            guard !self.frameworkPath.isEmpty else {
                self.log("Error: Could not locate framework directory")
                completion(false, self.logOutput)
                return
            }
            
            // Validate target directory
            guard self.fileManager.fileExists(atPath: targetPath) else {
                self.log("Error: Target directory does not exist")
                completion(false, self.logOutput)
                return
            }
            
            self.log("=== Claude Workflow Framework Installation ===")
            self.log("Framework source: \(self.frameworkPath)")
            self.log("Target directory: \(targetPath)")
            
            // Create directory structure
            do {
                self.log("\nCreating .claude directory structure...")
                try self.createDirectoryStructure(at: targetPath)
                self.log("✓ Directory structure created")
            } catch {
                self.log("✗ Failed to create directories: \(error)")
                completion(false, self.logOutput)
                return
            }
            
            // Copy files
            self.log("\nInstalling configuration templates...")
            _ = self.safeCopy(from: "\(self.frameworkPath)/CLAUDE.md", 
                             to: "\(targetPath)/CLAUDE.md", 
                             description: "CLAUDE.md")
            
            self.log("\nInstalling implementation guides...")
            _ = self.safeCopy(from: "\(self.frameworkPath)/CLAUDE_COORDINATION_PLAN.md", 
                             to: "\(targetPath)/.claude/CLAUDE_COORDINATION_PLAN.md", 
                             description: "coordination plan")
            _ = self.safeCopy(from: "\(self.frameworkPath)/IMPLEMENTATION_GUIDE.md", 
                             to: "\(targetPath)/.claude/IMPLEMENTATION_GUIDE.md", 
                             description: "implementation guide")
            
            self.log("\nCopying documentation...")
            _ = self.safeCopy(from: "\(self.frameworkPath)/docs", 
                             to: "\(targetPath)/.claude/docs", 
                             description: "documentation")
            _ = self.safeCopy(from: "\(self.frameworkPath)/rules", 
                             to: "\(targetPath)/.claude/rules", 
                             description: "workflow rules")
            _ = self.safeCopy(from: "\(self.frameworkPath)/terminology", 
                             to: "\(targetPath)/.claude/terminology", 
                             description: "terminology")
            _ = self.safeCopy(from: "\(self.frameworkPath)/api", 
                             to: "\(targetPath)/.claude/api", 
                             description: "API patterns")
            
            // Create scripts
            self.log("\nInstalling coordination scripts...")
            self.createSetupScript(at: targetPath)
            self.createCoordinationUtils(at: targetPath)
            self.createDockerCompose(at: targetPath)
            self.createReadme(at: targetPath)
            
            // Run setup automatically
            self.log("\n=== Running Setup ===")
            let projectType = self.detectProjectType(at: targetPath)
            self.log("Detected project type: \(projectType)")
            
            // Generate agent ID
            let hostname = Host.current().name ?? "unknown"
            let timestamp = Int(Date().timeIntervalSince1970)
            let agentId = "claude-\(hostname)-\(timestamp)"
            
            do {
                try agentId.write(toFile: "\(targetPath)/.claude/agent_id", 
                                  atomically: true, 
                                  encoding: .utf8)
                self.log("Agent ID: \(agentId)")
            } catch {
                self.log("Failed to write agent ID: \(error)")
            }
            
            // Create workflow configuration
            self.createWorkflowConfig(at: targetPath, projectType: projectType)
            
            self.log("\n✓ Installation complete!")
            self.log("\nTo use the coordination utilities:")
            self.log("1. cd \(targetPath)")
            self.log("2. source .claude/scripts/coordination-utils.sh")
            self.log("\nOptional - for Redis coordination:")
            self.log("3. docker-compose -f docker-compose.coordination.yml up -d")
            
            DispatchQueue.main.async {
                completion(success, self.logOutput)
            }
        }
    }
    
    func createSetupScript(at targetPath: String) {
        let scriptPath = "\(targetPath)/.claude/scripts/setup-coordination.sh"
        let scriptContent = """
#!/bin/bash
# Auto-generated coordination setup script

# Detect project type
detect_project_type() {
    if [[ -f "package.json" ]]; then
        echo "node"
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        echo "python"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "Cargo.toml" ]]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

PROJECT_TYPE=$(detect_project_type)
echo "Project type detected: $PROJECT_TYPE"
echo "Setup complete. Run: source .claude/scripts/coordination-utils.sh"
"""
        
        do {
            try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            log("✓ Created setup script")
        } catch {
            log("✗ Failed to create setup script: \(error)")
        }
    }
    
    func createCoordinationUtils(at targetPath: String) {
        let scriptPath = "\(targetPath)/.claude/scripts/coordination-utils.sh"
        let utilsContent = """
#!/bin/bash
# Claude Coordination Utilities

# Load agent ID
if [[ -f ".claude/agent_id" ]]; then
    CLAUDE_AGENT_ID=$(cat .claude/agent_id)
    export CLAUDE_AGENT_ID
fi

# Task claiming functions
claude-claim-task() {
    local task_id=$1
    local agent_id=${2:-$CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]] || [[ -z "$agent_id" ]]; then
        echo "Usage: claude-claim-task <task_id> [agent_id]"
        return 1
    fi
    
    local claim_file=".claude/coordination/claims/${task_id}.claim"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if (set -C; echo "{\\"agent_id\\":\\"${agent_id}\\",\\"claimed_at\\":\\"${timestamp}\\",\\"ttl\\":300}" > "${claim_file}") 2>/dev/null; then
        echo "✓ Task ${task_id} claimed by ${agent_id}"
        echo "${task_id}" >> ".claude/coordination/agents/${agent_id}.tasks"
        return 0
    else
        echo "✗ Task ${task_id} already claimed"
        return 1
    fi
}

claude-release-task() {
    local task_id=$1
    local agent_id=${2:-$CLAUDE_AGENT_ID}
    
    if [[ -z "$task_id" ]] || [[ -z "$agent_id" ]]; then
        echo "Usage: claude-release-task <task_id> [agent_id]"
        return 1
    fi
    
    local claim_file=".claude/coordination/claims/${task_id}.claim"
    
    if [[ -f "${claim_file}" ]]; then
        rm -f "${claim_file}"
        echo "✓ Task ${task_id} released"
        return 0
    else
        echo "✗ Task ${task_id} not found"
        return 1
    fi
}

claude-list-tasks() {
    echo "=== Active Tasks ==="
    for claim in .claude/coordination/claims/*.claim 2>/dev/null; do
        [[ -f "$claim" ]] || continue
        basename "$claim" .claim
    done
}

claude-status() {
    echo "=== Claude Coordination Status ==="
    echo "Agent ID: ${CLAUDE_AGENT_ID:-Not set}"
    local total_claims=$(find .claude/coordination/claims -name "*.claim" 2>/dev/null | wc -l)
    echo "Active claims: $total_claims"
}

echo "Claude coordination utilities loaded!"
echo "Commands: claude-claim-task, claude-release-task, claude-list-tasks, claude-status"
"""
        
        do {
            try utilsContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            log("✓ Created coordination utilities")
        } catch {
            log("✗ Failed to create utilities: \(error)")
        }
    }
    
    func createDockerCompose(at targetPath: String) {
        let composePath = "\(targetPath)/docker-compose.coordination.yml"
        let composeContent = """
version: '3.8'
services:
  redis-coordinator:
    image: redis:7-alpine
    container_name: claude-redis-coordinator
    ports:
      - "6379:6379"
    volumes:
      - redis_coordination_data:/data
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    restart: unless-stopped

volumes:
  redis_coordination_data:
"""
        
        do {
            try composeContent.write(toFile: composePath, atomically: true, encoding: .utf8)
            log("✓ Created docker-compose file")
        } catch {
            log("✗ Failed to create docker-compose: \(error)")
        }
    }
    
    func createReadme(at targetPath: String) {
        let readmePath = "\(targetPath)/.claude/README.md"
        let readmeContent = """
# Claude Workflow Framework

This project has been set up with the Claude Workflow Framework.

## Quick Start

```bash
source .claude/scripts/coordination-utils.sh
claude-claim-task example-task
claude-list-tasks
claude-release-task example-task
```

## Redis Coordination (Optional)

```bash
docker-compose -f docker-compose.coordination.yml up -d
```
"""
        
        do {
            try readmeContent.write(toFile: readmePath, atomically: true, encoding: .utf8)
            log("✓ Created README")
        } catch {
            log("✗ Failed to create README: \(error)")
        }
    }
    
    func createWorkflowConfig(at targetPath: String, projectType: String) {
        let configPath = "\(targetPath)/.claude/config/workflow.json"
        
        let config: [String: Any] = [
            "coordination": [
                "mode": "file",
                "fallback": "file"
            ],
            "project_type": projectType,
            "tasks": projectType == "node" ? [
                "test": "npm test",
                "lint": "npm run lint",
                "build": "npm run build"
            ] : [
                "test": "echo 'No test configured'",
                "lint": "echo 'No lint configured'",
                "build": "echo 'No build configured'"
            ],
            "agents": [
                "max_concurrent_tasks": 3
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: configPath))
            log("✓ Created workflow configuration")
        } catch {
            log("✗ Failed to create config: \(error)")
        }
    }
}

// CLI Application
class ClaudeInstallerApp {
    let installer = ClaudeFrameworkInstaller()
    
    func run() {
        print("=================================")
        print("Claude Framework Installer (Swift)")
        print("=================================\n")
        
        if installer.frameworkPath.isEmpty {
            print("❌ Error: Could not locate Claude Workflow Framework")
            print("\nPlease ensure the framework exists in one of these locations:")
            print("- ~/Documents/code/workflow-ng")
            print("- ~/claude-workflow-framework")
            print("- Current directory")
            exit(1)
        }
        
        print("Framework found at: \(installer.frameworkPath)")
        print("\nEnter target directory path (or press Enter for current directory):")
        
        let targetPath = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? FileManager.default.currentDirectoryPath
        let expandedPath = NSString(string: targetPath).expandingTildeInPath
        
        print("\nInstalling to: \(expandedPath)")
        print("Continue? (y/n): ", terminator: "")
        
        guard let response = readLine()?.lowercased(), response == "y" else {
            print("Installation cancelled.")
            exit(0)
        }
        
        print("\nInstalling...")
        
        installer.installFramework(to: expandedPath) { success, log in
            if success {
                print("\n✅ Installation completed successfully!")
                print("\nNext steps:")
                print("1. cd \(expandedPath)")
                print("2. source .claude/scripts/coordination-utils.sh")
                print("3. claude-status")
            } else {
                print("\n❌ Installation failed. Check the log above for details.")
            }
            exit(success ? 0 : 1)
        }
        
        // Keep the main thread alive
        RunLoop.main.run()
    }
}

// Run the app
let app = ClaudeInstallerApp()
app.run()