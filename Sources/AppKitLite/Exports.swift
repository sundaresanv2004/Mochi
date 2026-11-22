#if os(Windows)
// Like AppKit, bring Foundation (and its networking half, separate on Windows) along.
@_exported import Foundation
@_exported import FoundationNetworking
#endif
