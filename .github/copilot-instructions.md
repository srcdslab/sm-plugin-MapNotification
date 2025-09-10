# Copilot Instructions for MapNotification SourcePawn Plugin

## Repository Overview
This repository contains a SourcePawn plugin for SourceMod that sends Discord webhook notifications when maps start and end on Source engine game servers (primarily CS:GO/CS2). The plugin provides rich embed messages with server information, player counts, map thumbnails, and quick connect links.

## Project Structure
```
addons/sourcemod/scripting/
├── MapNotification.sp          # Main plugin source file
.github/
├── workflows/ci.yml           # GitHub Actions CI/CD pipeline
├── dependabot.yml            # Dependency updates configuration
sourceknight.yaml             # Build configuration and dependencies
```

## Technical Environment
- **Language**: SourcePawn
- **Platform**: SourceMod 1.11.0+ (latest stable from sourceknight.yaml)
- **Build Tool**: SourceKnight (automated dependency management)
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **Target**: Source engine game servers (CS:GO/CS2)

## Key Dependencies
The plugin relies on several external libraries managed through `sourceknight.yaml`:
- **SourceMod**: Core platform (1.11.0-git6934+)
- **DiscordWebhookAPI**: For Discord webhook integration
- **utilshelper**: Utility functions (external repository dependency)
- **Extended-Discord**: Optional enhanced Discord integration

## Code Style & Standards (Project-Specific)
Follow these conventions when working on this codebase:

### SourcePawn Conventions
- Use `#pragma semicolon 1` and `#pragma newdecls required` (already present)
- Tab indentation: 4 spaces
- camelCase for local variables and function parameters
- PascalCase for function names and global variables
- Prefix global variables with `g_` (e.g., `g_bPreMapEnd`, `g_cvAvatar`)
- Prefix ConVars with `g_cv` (e.g., `g_cvWebhook`, `g_cvUsername`)
- Boolean variables prefixed with `g_b` (e.g., `g_bPreMapEnd`)

### Memory Management
- Always use `delete` for ConVar handles and objects without null checks
- Example: `delete cvar;` not `if (cvar != null) { delete cvar; cvar = null; }`
- Use `delete` for StringMap/ArrayList instead of `.Clear()` to prevent memory leaks
- Properly clean up webhook objects, embeds, and DataPacks

### Plugin Structure Patterns
- Initialize ConVars in `OnPluginStart()`
- Use `AutoExecConfig(true)` for automatic config file generation
- Register admin commands with proper permission flags (`ADMFLAG_ROOT`)
- Hook game events appropriately (e.g., `cs_win_panel_match` for map end detection)
- Use timers with `TIMER_FLAG_NO_MAPCHANGE` for map-specific operations

## Configuration Management
The plugin uses ConVars for all configuration:
- Discord settings: webhook URL, username, avatar, colors
- Thread support: thread name, thread ID, channel type
- Server settings: redirect URL, map thumbnail URL, bot counting
- Retry mechanism: webhook retry count

ConVar naming convention: `sm_mapnotification_<feature>_<setting>`

## Discord Integration Specifics
- Supports both regular Discord channels and forum threads
- Uses Discord webhook embeds with rich formatting
- Implements retry mechanism for failed webhook deliveries
- Color-coded embeds (different colors for map start vs. map end)
- Thumbnail support for map images (JPG format only)
- Quick connect links with server IP/port information

### Thread Support Details
- Thread creation via `webhook.SetThreadName(sThreadName)`
- Thread replies via thread ID parameter in `webhook.Execute()`
- Different HTTP status codes: `HTTPStatus_OK` for channels, `HTTPStatus_NoContent` for thread replies
- Thread configuration priority: thread_id > thread_name > regular channel

## Build Process
This project uses SourceKnight for automated building:

1. **Dependencies**: Automatically fetched via `sourceknight.yaml`
2. **Build Command**: Use GitHub Actions or SourceKnight CLI
3. **Output**: Compiled `.smx` files in `/addons/sourcemod/plugins`
4. **Packaging**: Automated via CI/CD to `.tar.gz` releases

To build locally (if SourceKnight is available):
```bash
sourceknight build
```

## Testing Approach
- **Manual Testing**: Use admin command `sm_mapnotification` to test webhook delivery
- **Server Testing**: Deploy on development server before production
- **Webhook Testing**: Verify Discord webhook delivery and embed formatting
- **Event Testing**: Test both map start and map end notifications
- **Thread Testing**: Verify thread creation and message delivery if using Discord forums

## Error Handling Patterns
- All webhook operations include retry logic with configurable retry count
- Comprehensive logging using `LogError()` for critical failures
- Optional integration with Extended-Discord for enhanced error reporting
- Graceful degradation when optional dependencies are unavailable

## Common Development Tasks

### Adding New Configuration Options
1. Add ConVar in `OnPluginStart()` with proper naming convention
2. Update the embed generation logic in `Timer_SendMessage()`
3. Test configuration changes thoroughly

### Modifying Discord Embeds
1. Locate embed creation in `Timer_SendMessage()` function
2. Follow existing patterns for fields, colors, and formatting
3. Ensure proper memory cleanup with `delete` statements
4. Test embed rendering in Discord

### Adding New Events
1. Hook events in `OnPluginStart()` using `HookEvent()`
2. Create event handlers following naming convention `Event_<EventName>`
3. Consider map change timing and use appropriate timer flags

## Performance Considerations
- Webhook operations are asynchronous to avoid blocking server
- Timers use `TIMER_FLAG_NO_MAPCHANGE` to prevent cross-map issues
- Minimize string operations in frequently called functions
- Cache ConVar values when accessed multiple times
- Use DataPack for passing data between async operations

## Security Considerations
- Webhook URLs use `FCVAR_PROTECTED` flag to prevent exposure
- Thread configuration also protected for privacy
- Validate all user inputs and external data
- Use proper SQL escaping if database features are added

## Version Management
- Version defined in plugin info structure
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Current version: 2.1.3
- GitHub releases automated via CI/CD

## Library Integration Notes
- Optional Extended-Discord integration via conditional compilation
- Use `#tryinclude` for optional dependencies
- Check library availability with `LibraryExists()` and handle gracefully
- Follow SourceMod event system for library loading/unloading

## Common Code Patterns in This Project

### ConVar Management
```sourcepawn
// Finding and using temporary ConVars
ConVar cvar = FindConVar("hostname");
cvar.GetString(sHostname, sizeof(sHostname));
delete cvar;  // Always delete immediately after use
```

### Asynchronous Operations
```sourcepawn
// Use DataPack for async webhook callbacks
DataPack pack = new DataPack();
pack.WriteCell(someValue);
pack.WriteString(someString);
webhook.Execute(url, OnWebHookExecuted, pack, threadID);

// In callback, always reset and cleanup
pack.Reset();
bool value = pack.ReadCell();
pack.ReadString(buffer, sizeof(buffer));
delete pack;
```

### Conditional Compilation for Optional Dependencies
```sourcepawn
#if defined _extendeddiscord_included
    ExtendedDiscord_LogError("[%s] Error message", PLUGIN_NAME);
#endif
```

## Debugging Tips
- Use `PrintToServer()` for debug output during development
- Test webhook delivery using the admin command `sm_mapnotification`
- Check SourceMod logs for plugin errors and HTTP responses
- Verify ConVar values are being read correctly with test messages
- Test with various Discord channel configurations (regular channels vs. threads)
- Monitor webhook retry mechanism during network issues
- Validate map thumbnail URLs and embed formatting in Discord