# Plugin System - Incomplete Tasks

**Last Updated:** 2026-02-05
**Status:** Phase 2 Complete, Phase 3 Pending

---

## 📊 Executive Summary

**Completed:**
- ✅ Phase 1: MCP Foundation (4 working plugins)
- ✅ Phase 2: Visual Marketplace UI

**In Progress:**
- 🔄 Phase 3: Polish & Integration (4 tasks)
- ⏳ Phase 4: Plugin Expansion (4 tasks)

**Statistics:**
- **Total Tasks:** 13 incomplete
- **Critical:** 2 tasks
- **High Priority:** 2 tasks
- **Medium Priority:** 4 tasks
- **Low Priority:** 5 tasks

---

## 🔴 CRITICAL PRIORITY

### 1. Connect UI to Real MCP Manager

**Status:** ❌ Not Started
**Impact:** HIGH - Currently showing mock data
**Effort:** 1-2 days

**Problem:**
- Web UI endpoints return hardcoded plugin data
- No connection to actual MCP manager state
- Install/uninstall/start/stop buttons don't work

**Files to Modify:**
```
daemon/lib/ui/plugin_marketplace_ui.dart
  - _handleGetPlugins() - Connect to MCPServerManager
  - _handleInstallPlugin() - Implement real npm install
  - _handleStartPlugin() - Call manager.startServer()
  - _handleStopPlugin() - Call manager.stopServer()
  - _handleGetInstalledPlugins() - Query real state
```

**Implementation Steps:**
1. Import MCPServerManager in plugin_marketplace_ui.dart
2. Pass manager instance to PluginMarketplaceUI constructor
3. Replace mock data with manager.listServers()
4. Implement real install: npm install in plugins/ directory
5. Wire start/stop to manager lifecycle methods
6. Add error handling and status updates

**Expected Outcome:**
- UI shows actual installed plugins
- Buttons trigger real actions
- Status updates reflect actual state

---

### 2. Add Configuration UI

**Status:** ❌ Not Started
**Impact:** HIGH - Major UX blocker
**Effort:** 2-3 days

**Problem:**
- Users must manually edit `.opencli/mcp-servers.json`
- No visual way to add API keys/credentials
- Error-prone and intimidating for non-technical users

**Requirements:**
1. Configuration form in web UI
2. Per-plugin configuration fields
3. Validation for required fields
4. Secure handling of credentials
5. Save to mcp-servers.json
6. Reload plugins after config change

**UI Design:**
```
Plugin Details Modal
├── Overview Tab
├── Tools Tab
└── Configuration Tab ← NEW
    ├── API Key: [input field]
    ├── API Secret: [input field (masked)]
    ├── Base URL: [input field]
    └── [Save Configuration] button
```

**Implementation:**
```dart
// New endpoint
router.post('/api/plugins/<name>/configure', _handleConfigurePlugin);

Future<Response> _handleConfigurePlugin(Request request, String name) async {
  final body = await request.readAsString();
  final config = jsonDecode(body);

  // 1. Validate config
  // 2. Update mcp-servers.json
  // 3. Reload plugin
  // 4. Return success/error
}
```

**Expected Outcome:**
- Visual configuration in browser
- No manual JSON editing needed
- Validates required fields
- Applies changes immediately

---

## 🟡 HIGH PRIORITY

### 3. Add 10-20 Core Plugins

**Status:** ❌ Not Started
**Impact:** HIGH - Increases system usefulness
**Effort:** 1-2 weeks

**Goal:** Reach 15-20 working plugins (currently 4)

**Top Priority Plugins:**

**Cloud Services (3):**
1. **AWS Integration** - S3, EC2, Lambda (most requested)
2. **Google Cloud** - GCS, Compute, Cloud Functions
3. **Azure** - Blob Storage, VMs, Functions

**Development Tools (4):**
4. **GitLab** - Repos, CI/CD, merge requests
5. **Bitbucket** - Repos, pipelines
6. **Jira** - Issue tracking, project management
7. **Confluence** - Documentation management

**Testing & Automation (3):**
8. **Playwright** - Web automation (high demand)
9. **Selenium** - Browser testing
10. **Postman** - API testing

**Databases (2):**
11. **PostgreSQL** - Database operations
12. **MongoDB** - NoSQL operations

**DevOps (2):**
13. **Kubernetes** - Cluster management
14. **Terraform** - Infrastructure as code

**Communication (2):**
15. **Discord** - Bot integration
16. **Microsoft Teams** - Messaging

**Estimated Time:** 1-2 days per plugin = 2-4 weeks total

---

### 4. Implement Real Install/Uninstall

**Status:** ❌ Not Started
**Impact:** HIGH - Core functionality
**Effort:** 1-2 days

**Current:**
- Install button shows alert but doesn't install
- Uninstall doesn't work
- Manual npm install required

**Needed:**
```dart
Future<Response> _handleInstallPlugin(Request request, String name) async {
  // 1. Create plugin directory: plugins/<name>/
  // 2. Download package.json from registry
  // 3. Run: npm install
  // 4. Add to mcp-servers.json
  // 5. Return success with logs
}

Future<Response> _handleUninstallPlugin(Request request, String name) async {
  // 1. Stop plugin if running
  // 2. Remove from mcp-servers.json
  // 3. Delete plugin directory
  // 4. Return success
}
```

**Challenges:**
- Need plugin registry/repository
- Handle npm install failures
- Progress feedback during install
- Rollback on error

---

## 🟢 MEDIUM PRIORITY

### 5. Plugin Update Mechanism

**Status:** ❌ Not Started
**Impact:** MEDIUM
**Effort:** 2-3 days

**Features:**
- Check for plugin updates
- Show "Update Available" badge
- One-click update
- Changelog display
- Auto-update option

**Implementation:**
```dart
// Check plugin version vs registry
router.get('/api/plugins/<name>/check-update', _handleCheckUpdate);

// Update plugin
router.post('/api/plugins/<name>/update', _handleUpdatePlugin);
```

---

### 6. Plugin Templates

**Status:** ❌ Not Started
**Impact:** MEDIUM
**Effort:** 1-2 days

**Goal:** Make plugin creation easy

**Template Structure:**
```
plugin-template/
├── package.json (boilerplate)
├── index.js (MCP server skeleton)
├── README.md (documentation template)
└── .env.example (config template)
```

**Usage:**
```bash
opencli plugin create my-plugin
# Creates plugins/my-plugin/ from template
```

---

### 7. Plugin Generator CLI

**Status:** ❌ Not Started
**Impact:** MEDIUM
**Effort:** 2-3 days

**Command:**
```bash
opencli plugin create <name> --type=<api|automation|database>
```

**Features:**
- Interactive prompts for plugin details
- Choose plugin type (API, automation, etc.)
- Auto-generate boilerplate code
- Create tool definitions
- Setup testing structure

---

### 8. Plugin Ratings System

**Status:** ❌ Not Started
**Impact:** MEDIUM
**Effort:** 2-3 days

**Current:** Mock ratings (4.5-4.9 stars)

**Needed:**
- Real rating storage (database/file)
- User can rate after using plugin
- Average rating calculation
- Review text (optional)
- Display in marketplace

---

## 🔵 LOW PRIORITY

### 9. Fix Tray Menu Integration

**Status:** 🟡 Partial (code written, package missing)
**Impact:** LOW
**Effort:** 1 hour

**Issue:**
- `tray_manager` package not installed
- Code exists in `daemon/lib/personal/tray_plugin_menu.dart`
- Menubar integration non-functional

**Fix:**
```yaml
# Add to daemon/pubspec.yaml
dependencies:
  tray_manager: ^0.2.0
```

**Alternative:**
- Remove tray code if not needed
- Or implement using existing tray system

---

### 10. Community Marketplace

**Status:** ❌ Not Started
**Impact:** LOW (future)
**Effort:** 1-2 weeks

**Features:**
- User accounts
- Plugin submission
- Review/approval process
- Publishing workflow
- Plugin search/discovery

---

### 11. Plugin Dependencies

**Status:** ❌ Not Started
**Impact:** LOW
**Effort:** 1-2 days

**Feature:** Allow plugins to depend on other plugins

**Example:**
```json
{
  "name": "github-advanced",
  "dependencies": ["github-automation"]
}
```

---

### 12. Security Scanning

**Status:** ❌ Not Started
**Impact:** LOW
**Effort:** 2-3 days

**Features:**
- Scan plugin code for vulnerabilities
- Check npm packages for known issues
- Display security warnings
- Block malicious plugins

---

### 13. Manual Testing Checklist

**Status:** ⏳ Partially Done
**Remaining Tests:**

**UI Tests:**
- [ ] Page loads with gradient background
- [ ] Stats show correct numbers (currently mock)
- [ ] Search filters plugins in real-time
- [ ] Category filters work correctly
- [ ] Plugin cards show all information
- [ ] Install button triggers installation
- [ ] Uninstall removes plugin
- [ ] Start/Stop updates UI state
- [ ] Configuration saves correctly
- [ ] Error messages display properly

**Integration Tests:**
- [ ] Daemon starts marketplace on boot
- [ ] CLI `opencli plugin browse` opens UI
- [ ] API endpoints respond correctly
- [ ] MCP manager integration works
- [ ] Plugin lifecycle (install→start→use→stop→uninstall)

---

## 📅 Recommended Timeline

### Week 1-2: Critical Tasks
- Days 1-2: Connect UI to real MCP manager
- Days 3-5: Add configuration UI
- Days 6-7: Testing and bug fixes

### Week 3-4: High Priority
- Days 8-14: Implement 10 core plugins (AWS, Playwright, etc.)
- Days 15-16: Real install/uninstall functionality

### Week 5-6: Medium Priority
- Days 17-19: Plugin update mechanism
- Days 20-21: Plugin templates and generator
- Days 22-23: Plugin ratings system

### Week 7+: Polish & Low Priority
- Days 24-25: Manual testing completion
- Days 26-27: Fix tray menu
- Days 28+: Community features (if needed)

**Total Estimated Time:** 6-8 weeks for complete system

---

## 🎯 Quick Wins (Do First)

If limited time, prioritize these for maximum impact:

1. **Connect UI to MCP Manager** (1-2 days)
   - Makes everything functional
   - Buttons actually work
   - Shows real data

2. **Configuration UI** (2-3 days)
   - Huge UX improvement
   - Removes biggest barrier to use
   - Professional polish

3. **Add 5 Popular Plugins** (1 week)
   - AWS, Playwright, PostgreSQL, Kubernetes, GitLab
   - Dramatically increases usefulness
   - Addresses most common use cases

**Total Quick Wins:** 2 weeks, massive impact

---

## 📊 Task Breakdown by Category

**Backend/API:** 5 tasks
- Connect to MCP manager
- Real install/uninstall
- Configuration endpoint
- Update mechanism
- Security scanning

**Frontend/UI:** 3 tasks
- Configuration form
- Update notifications
- Rating interface

**Plugin Development:** 2 tasks
- Create 56+ plugins
- Plugin templates

**Infrastructure:** 3 tasks
- Community marketplace
- Plugin generator CLI
- Dependency system

---

## 💡 Notes

**Current State:**
- ✅ Visual marketplace works and looks great
- ✅ CLI commands functional
- ✅ 4 working plugins as proof of concept
- ❌ UI shows mock data, buttons don't do real actions
- ❌ Configuration requires manual JSON editing

**Biggest Gaps:**
1. UI not connected to backend (mock data)
2. No visual configuration (big UX issue)
3. Only 4 plugins (need 60+ for real usefulness)

**Recommendation:**
Focus on tasks 1, 2, and 3 first. These three alone would make the system genuinely useful for production.

---

**Next Action:** See [TASK_TRACKER.md](TASK_TRACKER.md) for current progress tracking.
