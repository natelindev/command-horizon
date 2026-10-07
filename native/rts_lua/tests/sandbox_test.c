#include "sandbox.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static RtsData input, output;
static int checks;
static void expect(int condition, const char *name, RtsReport report) {
    ++checks;
    if (!condition) {
        fprintf(stderr, "FAIL: %s: %s\n", name, report.error);
        exit(1);
    }
    assert(report.peak_memory <= RTS_LUA_MEMORY);
}
static RtsReport compile(RtsLua *vm, const char *source) {
    return rts_lua_compile(vm, source, strlen(source));
}
static void fault(RtsLua *vm, const char *source, const char *message) {
    RtsReport result = compile(vm, source);
    expect(result.ok, "fault fixture compiles", result);
    result = rts_lua_step(vm, &input, &input, &output);
    expect(!result.ok && strstr(result.error, message), message, result);
    result = rts_lua_step(vm, &input, &input, &output);
    expect(!result.ok && strstr(result.error, "suspended"), "fault stays suspended", result);
}
int main(void) {
    input.count = 1;
    input.nodes[0].type = RTS_MAP;
    input.nodes[0].child = input.nodes[0].next = -1;
    RtsLua *vm = rts_lua_create();
    RtsReport result =
        compile(vm, "return function(s,m) return {intent={kind='hold'},state={ticks=1}} end");
    expect(result.ok, "valid compile", result);
    result = rts_lua_step(vm, &input, &input, &output);
    expect(result.ok && output.count == 5, "valid data result", result);
    fault(vm, "return function() while true do end end", "budget");
    fault(vm, "return function() local t={} for i=1,100000 do t[i]=i end return t end", "memory");
    fault(vm, "return function() local s='abcdefgh'; for i=1,30 do s=s..s end return {s} end",
          "memory");
    fault(vm, "return function() local function f() return 1+f() end return {f()} end", "memory");
    fault(vm, "return function() local t={} t.self=t return t end", "Cyclic");
    fault(vm, "return function() return {a=function() end} end", "function");
    fault(vm, "return function() return {[1]=1, [3]=3} end", "Sparse");
    fault(vm, "return function() return {[true]=1} end", "keys");
    fault(vm, "return function() return {a=0/0} end", "finite");
    fault(vm, "return function() return {a=1/0} end", "finite");
    fault(vm, "return function() local t={} for i=1,2100 do t[i]=i end return t end",
          "node budget");
    fault(vm, "return function() local t={} local r=t for i=1,10 do t.a={} t=t.a end return r end",
          "depth");
    fault(vm, "return function() local s='a'; for i=1,13 do s=s..s end return {s} end",
          "string budget");
    fault(vm, "return function() return require('os') end", "nil value");
    fault(vm, "return function() return _G.os.execute('unused') end", "nil value");
    fault(vm, "return function() return {x='\\255'} end", "UTF-8");
    fault(vm, "return function() return {x='\\192\\128'} end", "UTF-8");
    fault(vm, "return function() return {x='\\237\\160\\128'} end", "UTF-8");
    fault(vm, "return function() return {x='\\244\\144\\128\\128'} end", "UTF-8");
    fault(vm, "return function() return {x='a\\0b'} end", "NUL");
    result = compile(vm, "while true do end");
    expect(!result.ok && strstr(result.error, "budget"), "top level budget", result);
    result = compile(vm, "return function(");
    expect(!result.ok, "syntax rejected", result);
    result = compile(vm, "return 42");
    expect(!result.ok, "nonfunction rejected", result);
    result = compile(vm, "\033Lua");
    expect(!result.ok, "bytecode rejected", result);
    char nested[2010] = "return ";
    memset(nested + 7, '(', 1000);
    nested[1007] = '1';
    memset(nested + 1008, ')', 1000);
    nested[2008] = 0;
    result = compile(vm, nested);
    expect(!result.ok, "parser nesting rejected without C stack overflow", result);
    result = compile(
        vm,
        "return function() return {safe = io==nil and os==nil and package==nil and require==nil "
        "and load==nil and dofile==nil and loadfile==nil and debug==nil and coroutine==nil "
        "and pcall==nil and xpcall==nil and getmetatable==nil and setmetatable==nil "
        "and collectgarbage==nil and string==nil and table==nil and math.random==nil} end");
    expect(result.ok, "whitelist fixture", result);
    result = rts_lua_step(vm, &input, &input, &output);
    expect(result.ok && output.nodes[1].integer == 1, "host APIs absent", result);
    /* Repeated exhaustion followed by clean compile catches allocator/close corruption. */
    for (int i = 0; i < 100; ++i) {
        fault(vm, "return function() local t={} for i=1,100000 do t[i]=i end return t end",
              "memory");
        result = compile(vm, "return function() return {ok=true} end");
        expect(result.ok, "clean recovery compile", result);
        result = rts_lua_step(vm, &input, &input, &output);
        expect(result.ok && output.nodes[1].integer, "clean recovery step", result);
    }
    rts_lua_destroy(vm);
    printf("PASS: %d native sandbox assertions\n", checks);
    return 0;
}
