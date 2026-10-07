#include "sandbox.h"
#include "credentials.h"
#include <cmath>
#include <cstring>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <memory>

using namespace godot;

namespace {
int store_string(RtsData &data, const String &value, int &length, String &error) {
    if (value.length() > RTS_LUA_STRING) {
        error = "Input string budget exceeded";
        return -1;
    }
    const CharString utf8 = value.utf8();
    length = utf8.length();
    if (length > RTS_LUA_STRING || length > RTS_LUA_BYTES - data.bytes) {
        error = "Input string budget exceeded";
        return -1;
    }
    int offset = data.bytes;
    memcpy(data.strings + offset, utf8.get_data(), length);
    data.bytes += length;
    return offset;
}

int encode(RtsData &data, const Variant &value, int depth, String &error) {
    if (depth > RTS_LUA_DEPTH || data.count >= RTS_LUA_NODES) {
        error = "Input depth or node budget exceeded";
        return -1;
    }
    int index = data.count++;
    RtsValue &node = data.nodes[index];
    node = {};
    node.child = node.next = -1;
    switch (value.get_type()) {
    case Variant::NIL:
        node.type = RTS_NIL;
        break;
    case Variant::BOOL:
        node.type = RTS_BOOL;
        node.integer = (bool)value;
        break;
    case Variant::INT:
        node.type = RTS_INT;
        node.integer = (int64_t)value;
        break;
    case Variant::FLOAT:
        node.type = RTS_NUMBER;
        node.number = (double)value;
        if (!std::isfinite(node.number))
            error = "Input numbers must be finite";
        break;
    case Variant::STRING:
        node.type = RTS_STRING;
        node.text = store_string(data, value, node.text_len, error);
        break;
    case Variant::DICTIONARY:
    case Variant::ARRAY: {
        bool map = value.get_type() == Variant::DICTIONARY;
        node.type = map ? RTS_MAP : RTS_ARRAY;
        Dictionary dict;
        Array array;
        Array keys;
        if (map) {
            dict = value;
        } else
            array = value;
        int size = map ? dict.size() : array.size();
        if (size > RTS_LUA_NODES - data.count) {
            error = "Input node budget exceeded";
            return -1;
        }
        if (map)
            keys = dict.keys();
        int previous = -1;
        for (int i = 0; i < size; ++i) {
            if (map && keys[i].get_type() != Variant::STRING) {
                error = "Input record keys must be strings";
                return -1;
            }
            int child = encode(data, map ? dict[keys[i]] : array[i], depth + 1, error);
            if (!error.is_empty())
                return -1;
            if (map)
                data.nodes[child].key =
                    store_string(data, keys[i], data.nodes[child].key_len, error);
            else
                data.nodes[child].index = i + 1;
            if (previous < 0)
                node.child = child;
            else
                data.nodes[previous].next = child;
            previous = child;
        }
        break;
    }
    default:
        error = "Input accepts only records, arrays, strings, booleans and finite numbers";
    }
    return error.is_empty() ? index : -1;
}

String decode_string(const RtsData &data, int offset, int length, String &error) {
    String result;
    if (result.parse_utf8(data.strings + offset, length) != OK)
        error = "Result strings must contain valid UTF-8";
    return result;
}

Variant decode(const RtsData &data, int index, String &error) {
    const RtsValue &node = data.nodes[index];
    switch (node.type) {
    case RTS_NIL:
        return Variant();
    case RTS_BOOL:
        return (bool)node.integer;
    case RTS_INT:
        return node.integer;
    case RTS_NUMBER:
        return node.number;
    case RTS_STRING:
        return decode_string(data, node.text, node.text_len, error);
    case RTS_MAP: {
        Dictionary result;
        for (int child = node.child; child >= 0; child = data.nodes[child].next) {
            const RtsValue &entry = data.nodes[child];
            String key = decode_string(data, entry.key, entry.key_len, error);
            result[key] = decode(data, child, error);
        }
        return result;
    }
    case RTS_ARRAY: {
        Array result;
        int count = 0;
        for (int child = node.child; child >= 0; child = data.nodes[child].next)
            ++count;
        result.resize(count);
        for (int child = node.child; child >= 0; child = data.nodes[child].next)
            result[data.nodes[child].index - 1] = decode(data, child, error);
        return result;
    }
    default:
        error = "Invalid native result";
        return Variant();
    }
}

Dictionary convert_report(const RtsReport &report) {
    Dictionary result;
    result["ok"] = (bool)report.ok;
    result["error"] = String::utf8(report.error);
    result["instructions"] = report.instructions;
    result["memory_bytes"] = (int64_t)report.memory;
    result["peak_memory_bytes"] = (int64_t)report.peak_memory;
    return result;
}
} // namespace

class RtsLuaSandbox : public RefCounted {
    GDCLASS(RtsLuaSandbox, RefCounted)
    RtsLua *vm = nullptr;
    bool suspended = true;

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("compile_source", "source"), &RtsLuaSandbox::compile_source);
        ClassDB::bind_method(D_METHOD("step", "snapshot", "state"), &RtsLuaSandbox::step);
        ClassDB::bind_method(D_METHOD("limits"), &RtsLuaSandbox::limits);
    }

  public:
    RtsLuaSandbox() { vm = rts_lua_create(); }
    ~RtsLuaSandbox() { rts_lua_destroy(vm); }
    Dictionary compile_source(const String &source) {
        if (source.length() > RTS_LUA_SOURCE) {
            suspended = true;
            return convert_report(rts_lua_compile(vm, "", 0));
        }
        const CharString bytes = source.utf8();
        RtsReport report = rts_lua_compile(vm, bytes.get_data(), bytes.length());
        suspended = !report.ok;
        return convert_report(report);
    }
    Dictionary step(const Dictionary &snapshot, const Dictionary &state) {
        Dictionary result;
        result["ok"] = false;
        if (suspended) {
            result["error"] = "Sandbox suspended; compile to start from clean state";
            return result;
        }
        auto input = std::make_unique<RtsData>();
        auto memory = std::make_unique<RtsData>();
        auto output = std::make_unique<RtsData>();
        String error;
        encode(*input, snapshot, 0, error);
        if (error.is_empty())
            encode(*memory, state, 0, error);
        if (!error.is_empty()) {
            suspended = true;
            result["error"] = error;
            return result;
        }
        RtsReport report = rts_lua_step(vm, input.get(), memory.get(), output.get());
        result = convert_report(report);
        suspended = !report.ok;
        if (report.ok) {
            Variant value = decode(*output, 0, error);
            if (error.is_empty())
                result["value"] = value;
            else {
                suspended = true;
                result["ok"] = false;
                result["error"] = error;
            }
        }
        return result;
    }
    Dictionary limits() const {
        Dictionary result;
        result["lua_version"] = "5.5.1+0b29f40";
        result["source_bytes"] = RTS_LUA_SOURCE;
        result["memory_bytes"] = RTS_LUA_MEMORY;
        result["instructions"] = RTS_LUA_INSTRUCTIONS;
        result["bridge_nodes"] = RTS_LUA_NODES;
        result["bridge_bytes"] = RTS_LUA_BYTES;
        result["bridge_depth"] = RTS_LUA_DEPTH;
        result["string_bytes"] = RTS_LUA_STRING;
        return result;
    }
};

static void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_class<RtsLuaSandbox>();
        ClassDB::register_class<RtsCredentialStore>();
    }
}
static void terminate(ModuleInitializationLevel level) { (void)level; }
extern "C" GDExtensionBool GDE_EXPORT rts_lua_init(GDExtensionInterfaceGetProcAddress get_proc,
                                                   GDExtensionClassLibraryPtr library,
                                                   GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
