# Lua runtime dependency review and API v1

Implementation date: 2026-10-01. This is the native runtime and game-action integration gate. The subsequent [Lua authoring slice](playtests/2026-10-02/LUA_AUTHORING.md) adds a custom editor and reusable source library. Visual rules, the battle arena and First Orders are now delivered. Optional LLM assistance now has a provider foundation and a player-facing draft workflow; live-provider and release acceptance remain open.

## Pinned dependencies

| Dependency | Pin | Review |
| --- | --- | --- |
| Lua | 5.5.1, official archive SHA-256 `1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce` | MIT license. The [official download listing](https://www.lua.org/ftp/) supplies the archive checksum. |
| Lua GC correction | [`0b29f408433e92953cc72b1d3e06c7ac8139e439`](https://github.com/lua/lua/commit/0b29f408433e92953cc72b1d3e06c7ac8139e439) | The [reported 5.5.1 bug](https://www.lua.org/bugs.html#5.5.1-1) permits a negative value in GC parameter arithmetic. Apply the two upstream production-source changes, even though collector controls are not exposed to scripts. |
| godot-cpp | `godot-4.5-stable`, commit `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`; archive SHA-256 `d4c03daf46c8bef4544614182b0762c3e32789151c7f8f44e8eb2053d5cddeba` | MIT license. Pinned bindings are exercised in the project's Godot 4.6 runtime. Build profile retains RefCounted, OS (needed internally by binding logging), and godot-cpp's required core classes; none is exposed to Lua. |

The archive hashes, URLs and patch provenance live in `native/rts_lua/dependencies.json`. A clean fetch/patch was compared byte-for-byte with the actual build sources, then idempotent reuse was tested. Use the [build instructions](../native/rts_lua/README.md). Validated toolchain: Apple Clang, SCons 4.11.1, Godot 4.6, macOS arm64. Other mapped platforms and final exports remain unverified.

Before updating: review the official Lua bug list and release changes; change the pins and patch assumptions deliberately; retain license notices; re-run the sanitizer, bridge, unit authority, rendered UI and 200-unit tests. Do not silently follow a branch head or load a system Lua installation.

## Boundary and execution limits

Each unit owns an independent Lua VM. `RtsLuaSandbox` accepts copied, bounded records/arrays of primitive values. No Node, Object, RID, callable, Variant userdata, world-query callback or engine singleton crosses the bridge. Snapshot mutation only changes the script's private copy. All potentially raising Lua calls are confined to C inside a protected `lua_pcall`; no Lua longjmp crosses a C++/Godot destructor. Godot input/output conversion happens outside that boundary using a fixed-capacity plain-C representation.

| Limit | Implemented value |
| --- | --- |
| Source | 1–32,768 UTF-8 bytes; text chunks only |
| Lua allocation | 256 KiB per VM, including allocator headers; includes stack, bytecode, globals, closures and strings |
| Instructions | 50,000 per initialization/evaluation; hook every 100 instructions |
| Slow evaluation guard | Monotonic 10 ms deadline checked by the instruction hook; not OS preemption or a hard wall-time guarantee |
| Data bridge | 2,048 values, depth 8, 64 KiB combined string/key bytes per payload; individual strings ≤4,096 bytes |
| Persistent explicit state | Record; serialized JSON ≤16 KiB, committed only after valid output |
| Perception | At most 32 nearest eligible current contacts, stable distance/identity ordering; truncation flag |
| Cadence | Five evaluations per simulation second, staggered by unit profile; no evaluations during tactical pause |
| Diagnostics | Native error ≤511 bytes, program trace ≤16 entries; two visible reason lines and full hover trace |

Host-side copied buffers, Godot objects and allocator infrastructure are additional to the Lua heap limit. Empty Lua tables decode as records; non-empty numeric tables must have dense indices 1..N. Mixed/sparse keys, cycles, functions, userdata, threads, non-finite numbers and invalid UTF-8/NUL text outputs are rejected. Input engine objects and cyclic/deep structures are rejected as well.

Allowed globals: `assert`, `error`, `ipairs`, `next`, `pairs`, `select`, `tonumber`, `type`, and `math.abs/ceil/floor/min/max/sqrt/sin/cos/atan/pi`. Ordinary Lua expressions, tables, loops and local functions work. No IO, OS, package/require, load/loadfile/dofile, debug, coroutine, metatable manipulation, collector control, random generator, print, string-pattern library or table-sort library is exposed. Protected calls (`pcall`/`xpcall`) are unavailable so scripts cannot catch budget errors and continue. The intentionally small library also limits native work that would run outside instruction accounting.

This is an in-process sandbox with bounded inputs and outputs, backed by tests, **not a claim of a formally verified interpreter or an OS security boundary**. Interpreter defects still require updates. Public untrusted-script sharing remains gated on further fuzzing, platform validation and review. Do not add arbitrary Godot bindings or unbounded C library functions as conveniences.

## Script contract

Source returns a function. Keep persistent behavior state in the explicit `state` record; closure/global state is private but deliberately discarded on Resume and is not a future save-game contract.

```lua
return function(snapshot, state)
    state.retreating = state.retreating or false
    local fraction = snapshot.self.hp / snapshot.self.hp_max
    if fraction < 0.3 then state.retreating = true end
    if fraction >= 0.8 then state.retreating = false end
    if state.retreating then
        return {
            intent = {kind = "move", assignment = "safe", status = "Regrouping for repair"},
            state = state
        }
    end
    for _, enemy in ipairs(snapshot.enemies) do
        if enemy.can_attack then
            return {intent = {kind = "attack", target = enemy.id}, state = state}
        end
    end
    return {intent = {kind = "hold"}, state = state}
end
```

Snapshot fields:

- `api_version = 1`, simulation `time`, `contacts_truncated`.
- `self`: role `type`, `hp`, `hp_max`, `position = {x,z}`, `attack_range` (zero for unarmed units).
- `assignments`: currently assigned `anchor`, `safe`, `route_a`, `route_b` positions. Unassigned points are absent. Scripts cannot create or alter assignments.
- `enemies`, `allies`: contact arrays (32 combined). Each record has opaque `id`, `type`, HP, position, distance, `can_attack` and `can_repair`. No hidden enemy coordinates are sampled into the snapshot. Handles persist only while the contact remains in the current bounded observation set; a lost handle cannot resolve via engine instance IDs.

Return exactly `{intent = {...}, state = {...}}`. Intent fields are strictly checked. Optional `status` is text of at most 120 characters.

| Intent | Extra field | Engine authority |
| --- | --- | --- |
| `hold` | None | Stop program movement; normal non-pursuing idle defense. |
| `move` | `assignment`: one of the four point names | Resolve the player's current assignment; missing assignment enters Waiting. No arbitrary script coordinates or arbitrary map queries. |
| `attack` | `target`: current contact ID | Revalidate ownership, visibility, capability, range and line of fire; real weapon cadence/damage remain authoritative. No chase implied. |
| `repair` | `target`: current contact ID | Repair robot only, eligible friendly target inside the assigned repair area. Approach within that area; heal through the existing shared repair service. |
| `guard` | None | Armed unit defends the player-assigned six-metre anchor area. Acquire currently allied-observed legal targets inside it, approach only within the sector plus two metres, stop at weapon range, and return when targets leave. Missing area waits. The script chooses when to retreat or resume guarding. |
| `escort` | None | Follow the player's assigned friendly escort; missing/dead/foreign/self assignment enters Waiting. |

No construction, production, purchases, resource transfers or squad membership changes are available. Squad shared-state access, parameter schemas, user-authored movement offsets and future additional capabilities require explicit API review; they are not implicitly enabled by native Lua.

## Authority and faults

`UnitProgram.configure_lua()` validates a candidate before replacing the active program or manual order. Existing chip/technology gates still control Run. Applying a preset clears custom Lua. Manual orders immediately suspend it; no script evaluation waits ahead of a human command. Resume recompiles into a clean VM and clears explicit memory. A bad edit preserves the prior working program/order.

An execution, memory, result-schema or serialization fault suspends the unit's Lua action once, clears program movement/fire/repair, releases target claims and enters Error with normal idle defense. Other units continue. A deduplicated notification identifies the player's faction unit type, program title and reason; budget faults identify the source line. Existing Manual/Resume controls remain usable, including while paused. Long reasons cannot push controls off the 720p panel. Enemy program faults do not produce player notifications.

The player-facing Lua editor now supports drafts, starter scripts, role/capability preview, isolated sample checks, immutable source/API/hash versions and explicit group application. Factory jobs inherit the exact selected source record. Legacy preset files migrate without read-time writes; invalid records preserve the file. See [authoring behavior and verification](playtests/2026-10-02/LUA_AUTHORING.md). Visual-rule compilation now uses the same runtime and action path. Up to twelve ordered cards, fixed retreat/recovery parameters and optional named states generate deterministic source; saved schema-3 records verify graph/source agreement. Freeform parameter-schema editing remains unavailable. See [visual-rule contract and verification](playtests/2026-10-02/VISUAL_RULES.md). Sample checks remain synthetic. The [battle arena](playtests/2026-10-02/BATTLE_ARENA.md) now runs seven real-unit scenarios in an isolated desktop process, with expected outcomes and bounded traces. The host-only evaluation signal grants Lua no new access. LLM generation remains later work.


## Optional LLM provider foundation — 2026-10-02

The provider layer under `source/match/programs/llm/` is implemented and locally verified. The Lua editor now exposes **AI assistant**, with provider/key controls, Create/Revise/Explain, context disclosure, parameter review and explicit import into the existing Check/Arena/Save/Apply flow. Visual rules remain separate; use **Copy as Lua** before requesting AI changes.

Default configuration selects OpenAI Responses at `https://api.openai.com/v1/responses` with the pinned `gpt-4.1-mini-2025-04-14` model, strict structured output, a 2,048-token output limit and a 45-second timeout. The model is a conservative configurable drafting baseline, not a claim to be the newest or best coding model. An explicitly selected Chat Completions-compatible endpoint is also supported. There is no automatic provider fallback, repair loop, retry or model selection. Requests set `store: false` on both APIs; this requests no response storage, not zero provider retention. See the official [Responses migration guide](https://developers.openai.com/api/docs/guides/migrate-to-responses), [structured-output contract](https://developers.openai.com/api/docs/guides/structured-outputs) and [model specification](https://developers.openai.com/api/docs/models/gpt-4.1-mini).

Configuration accepts HTTPS endpoints, or HTTP only for exact localhost/127.0.0.1/IPv6 loopback hosts. Credentials, query strings, fragments and line breaks are rejected in endpoint settings. Output limits are 256–4,096 tokens and timeouts 5–120 seconds. Compatible mode uses `max_tokens`; a provider rejecting that parameter, `store` or structured output produces a reviewable error rather than a silent second paid call. Explicit JSON-object mode still supplies the exact response schema in the system instructions and validates the result locally.

Only whitelisted context is packaged: API v1 documentation, the player request (up to 4,000 UTF-8 bytes), supported unit roles, the named current source for Revise/Explain, and at most 16 explicitly supplied diagnostic reasons. Other draft/trace fields are discarded. Create does not serialize the existing draft. No match, hidden world, unit objects, global library, account settings or key is included. Request context is at most 64 KiB, the serialized request 96 KiB, and provider response 256 KiB. The UI must disclose this transfer before requesting generation; freeform player text can itself contain sensitive information.

The one-request client remains usable during the editor's existing tactical pause without changing pause ownership. Cancellation invalidates its generation ID and drops the transport; reopening/retrying cannot accept an old callback. Redirects are disabled. HTTP, refusal, incomplete output, malformed JSON and response-contract errors return fixed local messages and preserve the caller's draft. Provider error bodies are never displayed or logged. Numeric usage fields are whitelisted; arbitrary provider metadata is discarded. No arriving Lua is compiled or executed. Returned code and numeric parameter metadata remain inert until the player imports and explicitly checks them. Explain must return no replacement code or parameters.

### Credentials

Provider settings are a bounded JSON file containing only the seven non-secret configuration fields. API keys stay in the credentials object's session memory unless the player explicitly requests persistence. Native `RtsCredentialStore` uses macOS Keychain generic-password items scoped to `OpenRTS.LLM` and a SHA-256 of protocol plus exact endpoint; Windows has a Credential Manager implementation using the equivalent scoped target. A changed endpoint requires its own credential. No plaintext fallback exists. Linux or a missing native extension supports session keys. Session overrides do not erase an older persisted key; Forget explicitly deletes both. Native methods are not exposed to the Lua VM.

macOS uses a noninteractive `LAContext` so denied/locked access returns a recoverable error instead of an authentication dialog blocking play. The Keychain implementation was built and exercised on the development Mac. Windows Credential Manager, Linux builds and exported packages are unverified. See Apple's [Keychain item guidance](https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain) and Microsoft's [CredWriteW reference](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew). Keys are not part of program records, battle archives or exported drafts.

### Verification and remaining gates

`tests/headless/LLMProviderRegression.gd` passes on Godot 4.6/macOS arm64. It checks configuration round trips/corruption preservation, secret-field rejection, endpoint/header/parameter injection guards, context filtering, both protocol formats, refusal/truncation/invalid responses, inert Lua arrival and parameter-prefix compilation. An isolated temporary Keychain item passes write/read/update/delete and cross-endpoint isolation; it is deleted by the test. Actual loopback HTTP exercises Responses and Chat, bearer-header placement, request overlap, immediate cancel/retry, redirects, response limits, a silent-server timeout and disposal while paused.

The silent-server test exposed a real hang with threaded `HTTPRequest`: cancellation waited for a blocking worker read. The client now uses Godot's nonblocking poller, and cancellation is asserted to return within 250 ms. This behavior matches the engine's [request/cancel implementation](https://github.com/godotengine/godot/blob/4.6/scene/main/http_request.cpp). The native extension rebuild, Lua sandbox and both-faction Lua authoring regressions also pass. Existing navigation readback and shutdown resource warnings remain in the gameplay harness.

No paid provider request was made: metadata-only checks found no accessible relevant API credential in Keychain. Real-provider acceptance, broader delayed/invalid-output UI scenarios, cross-platform exports and novice review are still required. The player-facing UI and parameter persistence verification are recorded below. Passing mock tests does not certify any remote provider/model deployment.


## LLM authoring UI and offline parameters — 2026-10-02

Open **Lua editor → AI assistant**. The Draft tab offers Create, Revise and Explain, the request field, opt-in diagnostic sharing, destination/output-limit disclosure, a plain-language review and separate code/parameter tabs. **Sent context** shows the prepared API guide and user context; the wire layer additionally supplies the strict response schema. Diagnostic sharing defaults off each opening and includes only the first 500 UTF-8 bytes of current editor check results. The assistant runs within the editor's existing tactical pause, and never changes that ownership itself.

Connection settings require an explicit Save connection. The provider/model/endpoint, strict-output preference, output limit and timeout are saved separately from keys. **Use key** clears the masked input after successful storage; persistence is unchecked by default. **Forget key** clears the endpoint's session and persistent credential. Existing keys are never populated into the field. Unsaved connection edits prevent generation against an unexpected prior endpoint. The UI states that cancel stops waiting but may not prevent provider billing for work already started.

A successful response changes only the review pane. **Import as unsaved draft** explicitly replaces the editor draft, clears its saved-version eligibility and previous arena evidence, and returns to the ordinary authoring flow. Check samples, Battle arena, Save version and Apply remain distinct actions. Explain has no import action. Failure/cancel retains the last reviewed program, prompt and editor draft. Closing/reopening the assistant retains prompt/review in the editor session; closing/reopening the editor retains that session through HUD draft memory. Sharing diagnostics still requires a new opt-in. This transient UI state is not included in battle saves.

Up to eight named numeric parameters can be reviewed before import, and later changed offline through the editor's **Parameters** button. Metadata records version 1 plus the bounded parameter values, ranges and arrow increments. Canonical numeric literals are prepended as a local `params` table. A metadata/source-prefix mismatch invalidates a saved record. Manual edits to the parameter prefix keep the freeform Lua text and detach the stale controls; editing the body preserves valid metadata. Updating parameters makes an unsaved draft and invalidates previous check evidence. Numeric controls preserve fractional defaults even when they are not multiples of the arrow increment.

Program libraries now write schema 4 and continue reading schema 1–3. Lua record fields remain unchanged; `parameter_schema` can now contain the versioned numeric metadata. Source, defaults and metadata participate in immutable version hashing. Factories keep the exact queued version, and battle archives embed the complete record. Canonical whole-number encoding avoids treating JSON's float representation as a source-prefix change or an unsaved connection edit.

### UI verification

`tests/rendered/LLMAssistantPreview.gd` passes with actual viewport mouse clicks and Escape at 1280×720, using an actual loopback provider. It exercises generation, inert arrival, retained review after HTTP 401, close/reopen, explicit draft import, parameter editing, sample checks, save/apply, read-only Explain, cancelling a silent request, masked session-key use/forget and saved connection limits. A 40%-health sample retreats with a 45% threshold and holds with a 30% threshold. Parameter/source tampering is rejected, library round trips retain metadata, and freeform prefix edits detach stale controls. Captures: [review](../art/skirmish/llm-review-720p.png), [parameters](../art/skirmish/llm-parameters-720p.png), [connection](../art/skirmish/llm-connection-720p.png), [failure](../art/skirmish/llm-error-720p.png).

`LuaAuthoringRegression` now uses parameterized records for both-faction Apply/manual/pause and exact factory inheritance, including library deletion after queueing. `SaveRestoreRegression` now embeds parameter metadata in its live Lua unit and queued factory job, and verifies actual scene restoration with exact program/state. Both pass, as do the provider, visual-rule and editor-import checks. Existing shutdown-only resource and navigation-readback warnings remain. No paid API request or novice user study has been performed; screenshots demonstrate a local fixture, not live model quality.

`tests/rendered/LLMAdversePreview.gd` extends that actual-input workflow with malformed JSON, rate limits, incomplete/refused output, wrong operations, nonfinite parameters and oversized source. Each failure retains the editor, last review and unit orders without automatically retrying. It verifies explicit diagnostic opt-in and its 500-byte limit, Escape during a silent request, socket cancellation, closing/reopening the complete editor, and renewed diagnostic consent. A returned `while true do end` remains inert on arrival and import; the explicit sample check rejects it within the sandbox budget. The full adverse workflow passes with zero failures against local HTTP fixtures. Live model quality, Windows/Linux native credential builds and novice acceptance remain open.


## Arena research setup — 2026-10-04

Opening Battle arena captures the human faction's completed research, including Coordination. The arena defaults to that captured setup and offers an **Unupgraded baseline** comparison. Upgrades apply before spawning fresh test units and remain fixed for a running scenario. Restart recreates the selected setup without stacking armor or retaining scenario memory. Only completed technologies are copied; live research payments, timers, resources and orders stay in the paused parent battle. Basic chip access and fresh fixtures remain arena conveniences, and the opposing target uses baseline stats.

Every result, including a failed scenario, carries its tested research setup. The trace, returned editor evidence and saved program test notes display that setup. The bridge accepts only the captured setup or the unupgraded baseline for the matching launch/draft. These results establish the selected scenario's observed behavior, not general tactical effectiveness or faction balance. See [arena research verification](playtests/2026-10-04/ARENA_RESEARCH.md).
