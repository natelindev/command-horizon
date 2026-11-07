/* Byte-compatible with SaveValue's tagged canonical JSON and SHA-256.
 * Each call owns its scratch data. No Nodes, shared caches or input mutations:
 * the same method is safe on detached packet-builder/reader worker snapshots.
 * Unsupported/oversized values return an empty string for the script fallback. */
#include <stdio.h>
#include <inttypes.h>

#define STATE_HASH_MAX_DEPTH 32
#define STATE_HASH_MAX_NODES 750000
#define STATE_HASH_MAX_STRING (2 * 1024 * 1024)
/* Valid network packets are limited to 4 MiB. Larger offline inputs can use
 * the portable encoder without making native scratch allocation unbounded. */
#define STATE_HASH_MAX_BYTES (64 * 1024 * 1024)

static GDExtensionInterfaceStringToUtf8Chars state_hash_utf8;
static GDExtensionInterfaceStringNewWithUtf8CharsAndLen state_hash_string;
static GDExtensionPtrBuiltInMethod state_hash_keys, state_hash_sort;
static GDExtensionPtrBuiltInMethod state_hash_escape, state_hash_sha256;

typedef struct {
    char *data;
    size_t length, capacity;
    int nodes, failed;
} StateHashBuffer;

static void state_hash_reserve(StateHashBuffer *b, size_t extra) {
    if (b->failed) return;
    if (extra > STATE_HASH_MAX_BYTES - b->length) { b->failed = 1; return; }
    size_t required = b->length + extra;
    if (required <= b->capacity) return;
    size_t capacity = b->capacity ? b->capacity : 4096;
    while (capacity < required) capacity *= 2;
    char *data = (char *)realloc(b->data, capacity);
    if (!data) { b->failed = 1; return; }
    b->data = data;
    b->capacity = capacity;
}

static void state_hash_write(StateHashBuffer *b, const char *data, size_t length) {
    state_hash_reserve(b, length);
    if (b->failed) return;
    memcpy(b->data + b->length, data, length);
    b->length += length;
}

#define STATE_HASH_TEXT(b, text) state_hash_write(b, text, sizeof(text) - 1)

static void state_hash_text(StateHashBuffer *b, const void *string) {
    int64_t size = state_hash_utf8(string, 0, 0);
    if (size < 0 || size > STATE_HASH_MAX_STRING) { b->failed = 1; return; }
    Value escaped;
    get_ctor(TYPE(STRING), 0)(&escaped, 0);
    /* Use the engine's escaping, including its treatment of control characters. */
    state_hash_escape((void *)string, 0, &escaped, 0);
    size = state_hash_utf8(&escaped, 0, 0);
    STATE_HASH_TEXT(b, "\"");
    state_hash_reserve(b, (size_t)size);
    if (!b->failed) {
        state_hash_utf8(&escaped, b->data + b->length, size);
        b->length += (size_t)size;
    }
    STATE_HASH_TEXT(b, "\"");
    get_dtor(TYPE(STRING))(&escaped);
}

static void state_hash_number(StateHashBuffer *b, double number) {
    if (!isfinite(number)) { b->failed = 1; return; }
    /* SaveValue serializes doubles as little-endian IEEE-754 hex, even for
     * Vector3/Color components promoted from the standard float engine build. */
    uint64_t bits;
    memcpy(&bits, &number, sizeof(bits));
    const char *hex = "0123456789abcdef";
    char encoded[18];
    encoded[0] = encoded[17] = '"';
    for (int i = 0; i < 8; i++) {
        unsigned byte = (unsigned)((bits >> (i * 8)) & 255);
        encoded[1 + i * 2] = hex[byte >> 4];
        encoded[2 + i * 2] = hex[byte & 15];
    }
    state_hash_write(b, encoded, sizeof(encoded));
}

static void state_hash_value(StateHashBuffer *b, const void *value, int depth);

static void state_hash_record(StateHashBuffer *b, const void *value, int depth) {
    Value dictionary, sorted;
    to_type(TYPE(DICTIONARY))(&dictionary, (void *)value);
    get_ctor(TYPE(ARRAY), 0)(&sorted, 0);
    state_hash_keys(&dictionary, 0, &sorted, 0);
    int64_t count = count_array(&sorted);
    if (count > STATE_HASH_MAX_NODES) b->failed = 1;
    /* StringName and String keys must sort together by their text. */
    for (int64_t i = 0; i < count && !b->failed; i++) {
        void *key = array_write(&sorted, i);
        GDExtensionVariantType type = get_type(key);
        if (type == TYPE(STRING_NAME)) {
            Value name, string;
            to_type(TYPE(STRING_NAME))(&name, key);
            const void *args[] = {&name};
            get_ctor(TYPE(STRING), 2)(&string, args);
            variant_destroy(key);
            from_type(TYPE(STRING))(key, &string);
            get_dtor(TYPE(STRING))(&string);
            get_dtor(TYPE(STRING_NAME))(&name);
        } else if (type != TYPE(STRING)) {
            b->failed = 1;
        }
    }
    if (!b->failed) state_hash_sort(&sorted, 0, 0, 0);
    STATE_HASH_TEXT(b, "[\"record\",[");
    int first = 1;
    for (int64_t i = 0; i < count && !b->failed; i++) {
        const void *key = array_index(&sorted, i);
        Value string;
        to_type(TYPE(STRING))(&string, (void *)key);
        int64_t length = state_hash_utf8(&string, 0, 0);
        char camera[6];
        int skip = depth == 0 && length == 6 &&
                   state_hash_utf8(&string, camera, sizeof(camera)) == 6 &&
                   memcmp(camera, "camera", 6) == 0;
        if (!skip) {
            if (!first) STATE_HASH_TEXT(b, ",");
            first = 0;
            STATE_HASH_TEXT(b, "[");
            state_hash_text(b, &string);
            STATE_HASH_TEXT(b, ",");
            state_hash_value(b, dict_index(&dictionary, key), depth + 1);
            STATE_HASH_TEXT(b, "]");
        }
        get_dtor(TYPE(STRING))(&string);
    }
    STATE_HASH_TEXT(b, "]]");
    get_dtor(TYPE(ARRAY))(&sorted);
    get_dtor(TYPE(DICTIONARY))(&dictionary);
}

static void state_hash_value(StateHashBuffer *b, const void *value, int depth) {
    if (b->failed) return;
    if (depth > STATE_HASH_MAX_DEPTH || ++b->nodes > STATE_HASH_MAX_NODES) {
        b->failed = 1;
        return;
    }
    switch (get_type(value)) {
        case TYPE(NIL): STATE_HASH_TEXT(b, "[\"null\"]"); break;
        case TYPE(BOOL): {
            GDExtensionBool boolean = 0;
            to_type(TYPE(BOOL))(&boolean, (void *)value);
            if (boolean) STATE_HASH_TEXT(b, "[\"bool\",true]");
            else STATE_HASH_TEXT(b, "[\"bool\",false]");
            break;
        }
        case TYPE(INT): {
            int64_t integer = 0;
            char text[48];
            to_type(TYPE(INT))(&integer, (void *)value);
            int length = snprintf(text, sizeof(text), "[\"int\",\"%" PRId64 "\"]", integer);
            state_hash_write(b, text, (size_t)length);
            break;
        }
        case TYPE(FLOAT): {
            double number = 0;
            to_type(TYPE(FLOAT))(&number, (void *)value);
            STATE_HASH_TEXT(b, "[\"float\",");
            state_hash_number(b, number);
            STATE_HASH_TEXT(b, "]");
            break;
        }
        case TYPE(STRING): {
            Value string;
            to_type(TYPE(STRING))(&string, (void *)value);
            STATE_HASH_TEXT(b, "[\"text\",");
            state_hash_text(b, &string);
            STATE_HASH_TEXT(b, "]");
            get_dtor(TYPE(STRING))(&string);
            break;
        }
        case TYPE(VECTOR3):
        case TYPE(COLOR): {
            float parts[4];
            GDExtensionVariantType type = get_type(value);
            to_type(type)(parts, (void *)value);
            int count = type == TYPE(VECTOR3) ? 3 : 4;
            if (count == 3) STATE_HASH_TEXT(b, "[\"vec3\",[");
            else STATE_HASH_TEXT(b, "[\"color\",[");
            for (int i = 0; i < count; i++) {
                if (i) STATE_HASH_TEXT(b, ",");
                state_hash_number(b, (double)parts[i]);
            }
            STATE_HASH_TEXT(b, "]]");
            break;
        }
        case TYPE(ARRAY): {
            Value array;
            to_type(TYPE(ARRAY))(&array, (void *)value);
            int64_t count = count_array(&array);
            STATE_HASH_TEXT(b, "[\"list\",[");
            for (int64_t i = 0; i < count && !b->failed; i++) {
                if (i) STATE_HASH_TEXT(b, ",");
                state_hash_value(b, array_index(&array, i), depth + 1);
            }
            STATE_HASH_TEXT(b, "]]");
            get_dtor(TYPE(ARRAY))(&array);
            break;
        }
        case TYPE(DICTIONARY): state_hash_record(b, value, depth); break;
        default: b->failed = 1;
    }
}

static void state_hash_call(void *userdata, void *instance,
                            const GDExtensionConstVariantPtr *args, GDExtensionInt count,
                            GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_OK;
    if (count != 1 || get_type(args[0]) != TYPE(DICTIONARY)) {
        variant_nil(ret);
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        error->argument = 0;
        error->expected = TYPE(DICTIONARY);
        return;
    }
    StateHashBuffer buffer = {0};
    state_hash_value(&buffer, args[0], 0);
    Value hash;
    if (!buffer.failed) {
        Value string;
        state_hash_string(&string, buffer.data, (int64_t)buffer.length);
        get_ctor(TYPE(STRING), 0)(&hash, 0);
        state_hash_sha256(&string, 0, &hash, 0);
        get_dtor(TYPE(STRING))(&string);
    } else {
        string_new(&hash, "");
    }
    free(buffer.data);
    from_type(TYPE(STRING))(ret, &hash);
    get_dtor(TYPE(STRING))(&hash);
}

static int state_hash_load(GDExtensionInterfaceGetProcAddress proc) {
    state_hash_utf8 = (GDExtensionInterfaceStringToUtf8Chars)proc("string_to_utf8_chars");
    state_hash_string = (GDExtensionInterfaceStringNewWithUtf8CharsAndLen)
                        proc("string_new_with_utf8_chars_and_len");
    return state_hash_utf8 && state_hash_string;
}

static void state_hash_initialize(void) {
    Value name, argument;
    name_new(&name, "keys");
    state_hash_keys = get_builtin(TYPE(DICTIONARY), &name, 4144163970LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&name, "sort");
    state_hash_sort = get_builtin(TYPE(ARRAY), &name, 3218959716LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&name, "json_escape");
    state_hash_escape = get_builtin(TYPE(STRING), &name, 3942272618LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&name, "sha256_text");
    state_hash_sha256 = get_builtin(TYPE(STRING), &name, 3942272618LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    if (!state_hash_keys || !state_hash_sort || !state_hash_escape || !state_hash_sha256) return;
    name_new(&name, "hash_state");
    name_new(&argument, "snapshot");
    GDExtensionPropertyInfo output = {TYPE(STRING), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo input = {TYPE(DICTIONARY), &argument, &empty_name, 0, &empty_string, 6};
    GDExtensionClassMethodArgumentMetadata metadata = 0;
    GDExtensionClassMethodInfo method = {0};
    method.name = &name;
    method.call_func = state_hash_call;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1;
    method.return_value_info = &output;
    method.argument_count = 1;
    method.arguments_info = &input;
    method.arguments_metadata = &metadata;
    register_method(library, &class_name, &method);
    get_dtor(TYPE(STRING_NAME))(&argument);
    get_dtor(TYPE(STRING_NAME))(&name);
}

#undef STATE_HASH_TEXT
