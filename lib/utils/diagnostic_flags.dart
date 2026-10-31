const networkDiagnosticsEnabled = bool.fromEnvironment('NETWORK_DIAGNOSTICS');

/// Session-only switch in the diagnostic APK; never persisted to preferences.
bool bypassHttpCacheForDiagnostics = false;
