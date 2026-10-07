/* All potentially throwing Lua API calls live in C, under lua_pcall.
 * Never move this boundary into C++: Lua errors use longjmp in this build. */
#include "sandbox.h"
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifdef _WIN32
#include <windows.h>
#endif

struct RtsLua {
    lua_State *L;
    size_t memory, peak;
    int instructions, exhausted, ready;
    double deadline;
    const char *source;
    size_t source_length;
    const RtsData *snapshot, *state;
    RtsData *output;
};

/* Track actual allocations (including aligned headers), independently of Lua's
 * requested-size hints. A failed shrink can retain the old allocation safely. */
typedef union {
    max_align_t alignment;
    size_t size;
} Allocation;

static double now_seconds(void) {
#ifdef _WIN32
    LARGE_INTEGER ticks, frequency;
    QueryPerformanceCounter(&ticks);
    QueryPerformanceFrequency(&frequency);
    return (double)ticks.QuadPart / (double)frequency.QuadPart;
#else
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + t.tv_nsec / 1e9;
#endif
}

static void *allocate(void *context, void *ptr, size_t old_size, size_t new_size) {
    RtsLua *vm = (RtsLua *)context;
    Allocation *old = ptr ? (Allocation *)ptr - 1 : NULL;
    old_size = old ? old->size : 0;
    if (!new_size) {
        free(old);
        vm->memory -= old_size;
        return NULL;
    }
    if (new_size > RTS_LUA_MEMORY - sizeof(Allocation))
        return NULL;
    size_t size = new_size + sizeof(Allocation);
    if (size > RTS_LUA_MEMORY - (vm->memory - old_size))
        return NULL;
    Allocation *next = (Allocation *)realloc(old, size);
    if (next) {
        next->size = size;
        vm->memory = vm->memory - old_size + size;
        if (vm->memory > vm->peak)
            vm->peak = vm->memory;
        return next + 1;
    }
    return size <= old_size ? ptr : NULL;
}

static RtsLua *owner(lua_State *L) {
    void *context = NULL;
    lua_getallocf(L, &context);
    return (RtsLua *)context;
}

static void count_hook(lua_State *L, lua_Debug *ar) {
    RtsLua *vm = owner(L);
    vm->instructions += 100;
    if (vm->instructions >= RTS_LUA_INSTRUCTIONS || now_seconds() > vm->deadline) {
        vm->exhausted = 1;
        lua_getinfo(L, "l", ar);
        luaL_error(L, "line %d: execution budget exceeded", ar->currentline);
    }
}

static void begin(RtsLua *vm) {
    vm->instructions = vm->exhausted = 0;
    vm->deadline = now_seconds() + 0.010;
    lua_sethook(vm->L, count_hook, LUA_MASKCOUNT, 100);
}

static RtsReport report(RtsLua *vm, int status) {
    RtsReport result = {0};
    result.ok = status == LUA_OK && !vm->exhausted;
    result.instructions = vm->instructions;
    result.memory = vm->memory;
    result.peak_memory = vm->peak;
    if (!result.ok) {
        const char *message = "Lua program failed";
        if (status == LUA_ERRMEM)
            message = "Lua memory budget exceeded";
        else if (lua_type(vm->L, -1) == LUA_TSTRING)
            message = lua_tostring(vm->L, -1);
        snprintf(result.error, sizeof(result.error), "%s", message);
        vm->ready = 0; /* A fault never restarts itself. Explicit compile creates a clean VM. */
    }
    lua_sethook(vm->L, NULL, 0, 0);
    lua_settop(vm->L, 0);
    return result;
}

static void copy_fields(lua_State *L, int from, int to, const char **names) {
    for (int i = 0; names[i]; ++i) {
        lua_getfield(L, from, names[i]);
        lua_setfield(L, to, names[i]);
    }
}

static int compile_call(lua_State *L) {
    RtsLua *vm = owner(L);
    static const char *base[] = {"assert", "error",    "ipairs", "next", "pairs",
                                 "select", "tonumber", "type",   NULL};
    static const char *math[] = {"abs", "ceil", "floor", "min", "max", "sqrt",
                                 "sin", "cos",  "atan",  "pi",  NULL};
    luaopen_base(L);
    int original = lua_gettop(L);
    lua_newtable(L);
    int env = lua_gettop(L);
    copy_fields(L, original, env, base);
    luaopen_math(L);
    int original_math = lua_gettop(L);
    lua_newtable(L);
    copy_fields(L, original_math, lua_gettop(L), math);
    lua_setfield(L, env, "math");
    lua_pop(L, 1);
    /* No stdlib references can reach the discarded global table. */
    lua_pushvalue(L, env);
    lua_rawseti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
    if (luaL_loadbufferx(L, vm->source, vm->source_length, "unit_program", "t") != LUA_OK)
        return lua_error(L);
    lua_pushvalue(L, env);
    lua_setupvalue(L, -2, 1);
    lua_call(L, 0, 1);
    if (!lua_isfunction(L, -1) || lua_iscfunction(L, -1))
        return luaL_error(L, "Source must return function(snapshot, state)");
    lua_setfield(L, LUA_REGISTRYINDEX, "rts_function");
    return 0;
}

static void push_value(lua_State *L, const RtsData *data, int index, int depth) {
    if (depth > RTS_LUA_DEPTH || index < 0 || index >= data->count)
        luaL_error(L, "Invalid snapshot depth or index");
    luaL_checkstack(L, 4, "snapshot stack");
    const RtsValue *value = &data->nodes[index];
    switch (value->type) {
    case RTS_NIL:
        lua_pushnil(L);
        break;
    case RTS_BOOL:
        lua_pushboolean(L, (int)value->integer);
        break;
    case RTS_INT:
        lua_pushinteger(L, value->integer);
        break;
    case RTS_NUMBER:
        lua_pushnumber(L, value->number);
        break;
    case RTS_STRING:
        lua_pushlstring(L, data->strings + value->text, value->text_len);
        break;
    case RTS_MAP:
    case RTS_ARRAY:
        lua_newtable(L);
        for (int child = value->child; child >= 0; child = data->nodes[child].next) {
            if (value->type == RTS_MAP)
                lua_pushlstring(L, data->strings + data->nodes[child].key,
                                data->nodes[child].key_len);
            else
                lua_pushinteger(L, data->nodes[child].index);
            push_value(L, data, child, depth + 1);
            lua_rawset(L, -3);
        }
        break;
    default:
        luaL_error(L, "Invalid snapshot value");
    }
}

static int save_string(lua_State *L, RtsData *data, const char *text, size_t size) {
    if (size > RTS_LUA_STRING || size > (size_t)(RTS_LUA_BYTES - data->bytes))
        luaL_error(L, "Result string budget exceeded");
    /* Reject invalid text before it reaches Godot's diagnostic-emitting decoder.
     * NUL is excluded because UI text/record keys must round-trip losslessly. */
    for (size_t i = 0; i < size;) {
        unsigned int first = (unsigned char)text[i++];
        if (first == 0)
            luaL_error(L, "Result text cannot contain NUL");
        if (first < 0x80)
            continue;
        int remaining;
        unsigned int code, minimum;
        if (first >= 0xC2 && first <= 0xDF) {
            remaining = 1;
            code = first & 0x1F;
            minimum = 0x80;
        } else if (first >= 0xE0 && first <= 0xEF) {
            remaining = 2;
            code = first & 0x0F;
            minimum = 0x800;
        } else if (first >= 0xF0 && first <= 0xF4) {
            remaining = 3;
            code = first & 7;
            minimum = 0x10000;
        } else {
            return luaL_error(L, "Result text must contain valid UTF-8");
        }
        while (remaining--) {
            if (i >= size || ((unsigned char)text[i] & 0xC0) != 0x80)
                luaL_error(L, "Result text must contain valid UTF-8");
            code = (code << 6) | ((unsigned char)text[i++] & 0x3F);
        }
        if (code < minimum || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF))
            luaL_error(L, "Result text must contain valid UTF-8");
    }
    int offset = data->bytes;
    memcpy(data->strings + offset, text, size);
    data->bytes += (int)size;
    return offset;
}

static int read_value(lua_State *L, RtsData *data, int slot, int depth, const void **ancestors) {
    if (depth > RTS_LUA_DEPTH || data->count >= RTS_LUA_NODES)
        luaL_error(L, "Result depth or node budget exceeded");
    luaL_checkstack(L, 4, "result stack");
    slot = lua_absindex(L, slot);
    int index = data->count++;
    RtsValue *value = &data->nodes[index];
    memset(value, 0, sizeof(*value));
    value->child = value->next = -1;
    switch (lua_type(L, slot)) {
    case LUA_TNIL:
        value->type = RTS_NIL;
        break;
    case LUA_TBOOLEAN:
        value->type = RTS_BOOL;
        value->integer = lua_toboolean(L, slot);
        break;
    case LUA_TNUMBER:
        if (lua_isinteger(L, slot)) {
            value->type = RTS_INT;
            value->integer = lua_tointeger(L, slot);
        } else {
            value->type = RTS_NUMBER;
            value->number = lua_tonumber(L, slot);
            if (!isfinite(value->number))
                luaL_error(L, "Result numbers must be finite");
        }
        break;
    case LUA_TSTRING: {
        value->type = RTS_STRING;
        size_t length;
        const char *text = lua_tolstring(L, slot, &length);
        value->text = save_string(L, data, text, length);
        value->text_len = (int)length;
        break;
    }
    case LUA_TTABLE: {
        const void *identity = lua_topointer(L, slot);
        for (int i = 0; i < depth; ++i)
            if (ancestors[i] == identity)
                luaL_error(L, "Cyclic result table");
        ancestors[depth] = identity;
        value->type = RTS_MAP; /* Empty Lua tables are records. */
        int previous = -1, count = 0, maximum = 0, kind = 0;
        lua_pushnil(L);
        while (lua_next(L, slot)) {
            int current_kind = lua_type(L, -2) == LUA_TSTRING ? RTS_MAP : RTS_ARRAY;
            if (kind && kind != current_kind)
                luaL_error(L, "Mixed result table keys");
            kind = current_kind;
            int child = read_value(L, data, -1, depth + 1, ancestors);
            RtsValue *entry = &data->nodes[child];
            if (kind == RTS_MAP) {
                size_t length;
                const char *key = lua_tolstring(L, -2, &length);
                entry->key = save_string(L, data, key, length);
                entry->key_len = (int)length;
            } else {
                if (!lua_isinteger(L, -2))
                    luaL_error(L, "Result keys must be strings or dense indices");
                lua_Integer number = lua_tointeger(L, -2);
                if (number < 1 || number > RTS_LUA_NODES)
                    luaL_error(L, "Result array index out of range");
                entry->index = (int)number;
                if (number > maximum)
                    maximum = (int)number;
            }
            if (previous < 0)
                value->child = child;
            else
                data->nodes[previous].next = child;
            previous = child;
            ++count;
            lua_pop(L, 1);
        }
        if (kind == RTS_ARRAY && count != maximum)
            luaL_error(L, "Sparse result array");
        if (kind)
            value->type = kind;
        break;
    }
    default:
        luaL_error(L, "Result contains a function, thread or userdata");
    }
    return index;
}

static int step_call(lua_State *L) {
    RtsLua *vm = owner(L);
    lua_getfield(L, LUA_REGISTRYINDEX, "rts_function");
    push_value(L, vm->snapshot, 0, 0);
    push_value(L, vm->state, 0, 0);
    lua_call(L, 2, 1);
    if (!lua_istable(L, -1))
        return luaL_error(L, "Program must return a result table");
    const void *ancestors[RTS_LUA_DEPTH + 1] = {0};
    read_value(L, vm->output, -1, 0, ancestors);
    return 0;
}

RtsLua *rts_lua_create(void) { return (RtsLua *)calloc(1, sizeof(RtsLua)); }
void rts_lua_destroy(RtsLua *vm) {
    if (!vm)
        return;
    if (vm->L)
        lua_close(vm->L);
    free(vm);
}

RtsReport rts_lua_compile(RtsLua *vm, const char *source, size_t length) {
    RtsReport invalid = {0};
    if (!vm) {
        strcpy(invalid.error, "Cannot allocate sandbox");
        return invalid;
    }
    if (vm->L)
        lua_close(vm->L);
    memset(vm, 0, sizeof(*vm));
    if (!length || length > RTS_LUA_SOURCE) {
        strcpy(invalid.error, "Source must contain 1–32768 UTF-8 bytes");
        return invalid;
    }
    vm->L = lua_newstate(allocate, vm, 0x525453); /* Private, reproducible string hash seed. */
    if (!vm->L) {
        strcpy(invalid.error, "Cannot allocate Lua state");
        return invalid;
    }
    vm->source = source;
    vm->source_length = length;
    begin(vm);
    lua_pushcfunction(vm->L, compile_call);
    RtsReport result = report(vm, lua_pcall(vm->L, 0, 0, 0));
    vm->ready = result.ok;
    vm->source = NULL;
    return result;
}

RtsReport rts_lua_step(RtsLua *vm, const RtsData *snapshot, const RtsData *state, RtsData *output) {
    RtsReport invalid = {0};
    if (!vm || !vm->ready) {
        strcpy(invalid.error, "Sandbox suspended; compile to start from clean state");
        return invalid;
    }
    vm->snapshot = snapshot;
    vm->state = state;
    vm->output = output;
    output->count = output->bytes = 0;
    begin(vm);
    lua_pushcfunction(vm->L, step_call);
    RtsReport result = report(vm, lua_pcall(vm->L, 0, 0, 0));
    vm->snapshot = vm->state = NULL;
    vm->output = NULL;
    return result;
}
