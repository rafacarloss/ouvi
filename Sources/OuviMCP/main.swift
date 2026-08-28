import Foundation
import OuviKit

// Placeholder entry point; the MCP stdio server is implemented in a later phase.
FileHandle.standardError.write("ouvi-mcp \(OuviInfo.version)\n".data(using: .utf8)!)
