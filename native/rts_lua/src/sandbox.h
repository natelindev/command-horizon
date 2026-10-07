#ifndef RTS_LUA_SANDBOX_H
#define RTS_LUA_SANDBOX_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define RTS_LUA_MEMORY (256 * 1024)
#define RTS_LUA_SOURCE (32 * 1024)
#define RTS_LUA_INSTRUCTIONS 50000
#define RTS_LUA_NODES 2048
#define RTS_LUA_BYTES (64 * 1024)
#define RTS_LUA_DEPTH 8
#define RTS_LUA_STRING 4096
/* Index 0 is the root. child/next use -1 for none. No owning C++ values cross here. */
enum RtsType { RTS_NIL, RTS_BOOL, RTS_INT, RTS_NUMBER, RTS_STRING, RTS_MAP, RTS_ARRAY };
typedef struct {
    int type, child, next, key, key_len, text, text_len, index;
    int64_t integer;
    double number;
} RtsValue;
typedef struct {
    int count, bytes;
    RtsValue nodes[RTS_LUA_NODES];
    char strings[RTS_LUA_BYTES];
} RtsData;
typedef struct {
    int ok, instructions;
    size_t memory, peak_memory;
    char error[512];
} RtsReport;
typedef struct RtsLua RtsLua;
RtsLua *rts_lua_create(void);
void rts_lua_destroy(RtsLua *vm);
RtsReport rts_lua_compile(RtsLua *vm, const char *source, size_t length);
RtsReport rts_lua_step(RtsLua *vm, const RtsData *snapshot, const RtsData *state, RtsData *output);
#ifdef __cplusplus
}
#endif
#endif
