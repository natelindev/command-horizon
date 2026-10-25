/* Bulk pose packing using the public Godot GDExtension C ABI.
 * Scene-tree reads remain on the main thread; GPU interpolation is parallel.
 * No game state is modified. The returned buffer owns its memory. */
#include "gdextension_interface.h"
#include <stdint.h>
#include <string.h>
#include <math.h>

typedef union { uint64_t align; unsigned char data[64]; } Value;
#define TYPE(name) GDEXTENSION_VARIANT_TYPE_##name
#define DECL(name, suffix) static GDExtensionInterface##suffix name
DECL(name_new, StringNameNewWithUtf8Chars);
DECL(string_new, StringNewWithUtf8Chars);
DECL(from_type, GetVariantFromTypeConstructor);
DECL(to_type, GetVariantToTypeConstructor);
DECL(get_ctor, VariantGetPtrConstructor);
DECL(get_dtor, VariantGetPtrDestructor);
DECL(get_builtin, VariantGetPtrBuiltinMethod);
DECL(get_type, VariantGetType);
DECL(variant_destroy, VariantDestroy);
DECL(variant_nil, VariantNewNil);
DECL(array_index, ArrayOperatorIndexConst);
DECL(dict_index, DictionaryOperatorIndexConst);
DECL(bytes_index, PackedByteArrayOperatorIndex);
DECL(object_id, VariantGetObjectInstanceId);
DECL(object_from_id, ObjectGetInstanceFromId);
DECL(object_cast, ObjectCastTo);
DECL(class_tag, ClassdbGetClassTag);
DECL(method_bind, ClassdbGetMethodBind);
DECL(ptrcall, ObjectMethodBindPtrcall);
DECL(construct, ClassdbConstructObject2);
DECL(set_instance, ObjectSetInstance);
DECL(register_class, ClassdbRegisterExtensionClass4);
DECL(register_method, ClassdbRegisterExtensionClassMethod);
DECL(unregister_class, ClassdbUnregisterExtensionClass);
static GDExtensionClassLibraryPtr library;
static Value class_name, parent_name, pack_name, node_name, transform_name;
static Value empty_name, empty_string, entries_name, capacity_name, size_name, resize_name;
static Value keys[4];
static Value query_name, object_name, queued_name, append_name, has_name, visible_name;
static Value query_args[5];
static GDExtensionPtrBuiltInMethod array_append;
static GDExtensionPtrBuiltInMethod dictionary_has;
static GDExtensionMethodBindPtr queued_for_deletion;
static GDExtensionPtrBuiltInMethod array_size, bytes_resize;
static GDExtensionMethodBindPtr global_transform;
static GDExtensionMethodBindPtr visible_in_tree;
static void *node_tag;
static int class_registered;

static void *dictionary_lookup(const void *dictionary, const void *key) {
    const void *args[] = {key};
    GDExtensionBool found = 0;
    dictionary_has((void *)dictionary, args, &found, 1);
    return found ? (void *)dict_index(dictionary, key) : 0;
}

static int64_t count_array(void *array) {
    int64_t size = 0;
    array_size(array, 0, &size, 0);
    return size;
}

static void pack_core(const void *entries, int64_t capacity, void *output) {
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 0)(output, 0);
    if (capacity <= 0 || capacity > 8192) return;
    int64_t length = capacity * 64, result = 0;
    const void *resize_args[] = { &length };
    bytes_resize(output, resize_args, &result, 1);
    if (result != 0) return;
    float *pixels = (float *)bytes_index(output, 0);
    memset(pixels, 0, (size_t)length);
    int64_t entries_count = count_array((void *)entries);
    for (int64_t i = 0; i < entries_count; ++i) {
        void *entry_variant = array_index(entries, i);
        if (get_type(entry_variant) != TYPE(DICTIONARY)) continue;
        Value entry, anchors;
        to_type(TYPE(DICTIONARY))(&entry, entry_variant);
        void *anchor_value = dictionary_lookup(&entry, &keys[0]);
        void *offset_value = dictionary_lookup(&entry, &keys[1]);
        void *visible_value = dictionary_lookup(&entry, &keys[2]);
        void *pulse_value = dictionary_lookup(&entry, &keys[3]);
        if (!anchor_value || !offset_value || !visible_value || !pulse_value ||
            get_type(anchor_value) != TYPE(ARRAY) || get_type(offset_value) != TYPE(INT) ||
            get_type(visible_value) != TYPE(BOOL) || get_type(pulse_value) != TYPE(COLOR)) {
            get_dtor(TYPE(DICTIONARY))(&entry);
            continue;
        }
        int64_t offset = 0;
        GDExtensionBool shown = 0;
        float pulse[4];
        to_type(TYPE(ARRAY))(&anchors, anchor_value);
        to_type(TYPE(INT))(&offset, offset_value);
        to_type(TYPE(BOOL))(&shown, visible_value);
        to_type(TYPE(COLOR))(pulse, pulse_value);
        int64_t count = count_array(&anchors);
        if (offset >= 0 && count <= capacity && offset <= capacity - count && shown) {
            for (int64_t part = 0; part < count; ++part) {
                void *value = array_index(&anchors, part);
                if (get_type(value) != TYPE(OBJECT)) continue;
                void *object = object_from_id(object_id(value));
                if (!object || !object_cast(object, node_tag)) continue;
                GDExtensionBool visible = 0;
                ptrcall(visible_in_tree, object, 0, &visible);
                if (!visible) continue;
                float transform[12];
                ptrcall(global_transform, object, 0, transform);
                float *row = pixels + (offset + part) * 16;
                for (int axis = 0; axis < 3; ++axis) {
                    memcpy(row + axis * 4, transform + axis * 3, sizeof(float) * 3);
                    row[axis * 4 + 3] = transform[9 + axis];
                }
                memcpy(row + 12, pulse, sizeof(pulse));
            }
        }
        get_dtor(TYPE(ARRAY))(&anchors);
        get_dtor(TYPE(DICTIONARY))(&entry);
    }
}

static void pack_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                      GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    if (argc != 2 || get_type(args[0]) != TYPE(ARRAY) || get_type(args[1]) != TYPE(INT)) {
        variant_nil(ret);
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        return;
    }
    Value entries, bytes;
    int64_t capacity = 0;
    to_type(TYPE(ARRAY))(&entries, (void *)args[0]);
    to_type(TYPE(INT))(&capacity, (void *)args[1]);
    pack_core(&entries, capacity, &bytes);
    from_type(TYPE(PACKED_BYTE_ARRAY))(ret, &bytes);
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&bytes);
    get_dtor(TYPE(ARRAY))(&entries);
    error->error = GDEXTENSION_CALL_OK;
}

static void pack_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    pack_core(args[0], *(const int64_t *)args[1], ret);
}

/* Same ordered spatial-cell traversal as Battlefield.nearby_units. Positions
 * and queued-deletion state are read live on the main thread, so sequential
 * avoidance callbacks and teleports retain their existing semantics. */
static void nearby_core(const void *cells, const float *point, double radius,
                        double cell_size, double indexed_reach, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    if (!(cell_size > 0) || !isfinite(radius) || !isfinite(indexed_reach) ||
        !isfinite(point[0]) || !isfinite(point[2])) return;
    double limits[] = {
        floor((point[0] - indexed_reach) / cell_size),
        floor((point[2] - indexed_reach) / cell_size),
        floor((point[0] + indexed_reach) / cell_size),
        floor((point[2] + indexed_reach) / cell_size)
    };
    for (int i = 0; i < 4; ++i)
        if (limits[i] <= INT32_MIN || limits[i] >= INT32_MAX) return;
    double squared_radius = radius * radius;
    for (int32_t x = (int32_t)limits[0]; x <= (int32_t)limits[2]; ++x) {
        for (int32_t z = (int32_t)limits[1]; z <= (int32_t)limits[3]; ++z) {
            int32_t coordinates[2] = {x, z};
            Value key;
            from_type(TYPE(VECTOR2I))(&key, coordinates);
            void *cell = dictionary_lookup(cells, &key);
            variant_destroy(&key);
            if (!cell || get_type(cell) != TYPE(ARRAY)) continue;
            Value bodies;
            to_type(TYPE(ARRAY))(&bodies, cell);
            int64_t count = count_array(&bodies);
            for (int64_t i = 0; i < count; ++i) {
                void *value = array_index(&bodies, i);
                if (get_type(value) != TYPE(OBJECT)) continue;
                void *body = object_from_id(object_id(value));
                if (!body || !object_cast(body, node_tag)) continue;
                GDExtensionBool queued = 0;
                ptrcall(queued_for_deletion, body, 0, &queued);
                if (queued) continue;
                float transform[12];
                ptrcall(global_transform, body, 0, transform);
                float dx = transform[9] - point[0], dz = transform[11] - point[2];
                float distance_squared = dx * dx + dz * dz;
                if (distance_squared <= squared_radius) {
                    const void *args[] = {value};
                    array_append(output, args, 0, 1);
                }
            }
            get_dtor(TYPE(ARRAY))(&bodies);
        }
    }
}

static void nearby_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                        GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    if (argc != 5 || get_type(args[0]) != TYPE(DICTIONARY) || get_type(args[1]) != TYPE(VECTOR3) ||
        get_type(args[2]) != TYPE(FLOAT) || get_type(args[3]) != TYPE(FLOAT) || get_type(args[4]) != TYPE(FLOAT)) {
        variant_nil(ret);
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        return;
    }
    Value cells, output;
    float point[3];
    double radius, cell_size, indexed_reach;
    to_type(TYPE(DICTIONARY))(&cells, (void *)args[0]);
    to_type(TYPE(VECTOR3))(point, (void *)args[1]);
    to_type(TYPE(FLOAT))(&radius, (void *)args[2]);
    to_type(TYPE(FLOAT))(&cell_size, (void *)args[3]);
    to_type(TYPE(FLOAT))(&indexed_reach, (void *)args[4]);
    nearby_core(&cells, point, radius, cell_size, indexed_reach, &output);
    from_type(TYPE(ARRAY))(ret, &output);
    get_dtor(TYPE(ARRAY))(&output);
    get_dtor(TYPE(DICTIONARY))(&cells);
    error->error = GDEXTENSION_CALL_OK;
}

static void nearby_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    nearby_core(args[0], args[1], *(const double *)args[2], *(const double *)args[3], *(const double *)args[4], ret);
}

static GDExtensionObjectPtr create_instance(void *userdata, GDExtensionBool notify) {
    (void)userdata; (void)notify;
    void *owner = construct(&parent_name);
    set_instance(owner, &class_name, owner);
    return owner;
}

static void free_instance(void *userdata, void *instance) { (void)userdata; (void)instance; }

static void initialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    name_new(&class_name, "CopperfinPosePacker");
    name_new(&parent_name, "RefCounted");
    name_new(&pack_name, "pack_poses");
    name_new(&node_name, "Node3D");
    name_new(&transform_name, "get_global_transform");
    name_new(&empty_name, "");
    string_new(&empty_string, "");
    name_new(&entries_name, "entries");
    name_new(&capacity_name, "capacity");
    name_new(&size_name, "size");
    name_new(&resize_name, "resize");
    name_new(&query_name, "nearby_units");
    name_new(&object_name, "Object");
    name_new(&queued_name, "is_queued_for_deletion");
    name_new(&append_name, "append");
    name_new(&has_name, "has");
    name_new(&visible_name, "is_visible_in_tree");
    const char *argument_names[] = {"cells", "point", "radius", "cell_size", "indexed_reach"};
    for (int i = 0; i < 5; ++i) name_new(&query_args[i], argument_names[i]);
    const char *key_names[] = { "anchors", "offset", "shown", "pulse" };
    for (int i = 0; i < 4; ++i) {
        Value string;
        string_new(&string, key_names[i]);
        from_type(TYPE(STRING))(&keys[i], &string);
        get_dtor(TYPE(STRING))(&string);
    }
    global_transform = method_bind(&node_name, &transform_name, 3229777777LL);
    visible_in_tree = method_bind(&node_name, &visible_name, 36873697LL);
    node_tag = class_tag(&node_name);
    array_size = get_builtin(TYPE(ARRAY), &size_name, 3173160232LL);
    bytes_resize = get_builtin(TYPE(PACKED_BYTE_ARRAY), &resize_name, 848867239LL);
    array_append = get_builtin(TYPE(ARRAY), &append_name, 3316032543LL);
    dictionary_has = get_builtin(TYPE(DICTIONARY), &has_name, 3680194679LL);
    queued_for_deletion = method_bind(&object_name, &queued_name, 36873697LL);
    if (!global_transform || !visible_in_tree || !node_tag || !array_size || !bytes_resize || !array_append || !dictionary_has || !queued_for_deletion) return;
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = create_instance;
    info.free_instance_func = free_instance;
    register_class(library, &class_name, &parent_name, &info);
    class_registered = 1;
    GDExtensionPropertyInfo output = { TYPE(PACKED_BYTE_ARRAY), &empty_name, &empty_name, 0, &empty_string, 6 };
    GDExtensionPropertyInfo arguments[] = {
        { TYPE(ARRAY), &entries_name, &empty_name, 0, &empty_string, 6 },
        { TYPE(INT), &capacity_name, &empty_name, 0, &empty_string, 6 }
    };
    GDExtensionClassMethodArgumentMetadata metadata[2] = {0, 0};
    GDExtensionClassMethodInfo method = {0};
    method.name = &pack_name;
    method.call_func = pack_call;
    method.ptrcall_func = pack_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1;
    method.return_value_info = &output;
    method.argument_count = 2;
    method.arguments_info = arguments;
    method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
    GDExtensionPropertyInfo query_output = {TYPE(ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo query_arguments[5];
    GDExtensionVariantType types[] = {TYPE(DICTIONARY), TYPE(VECTOR3), TYPE(FLOAT), TYPE(FLOAT), TYPE(FLOAT)};
    GDExtensionClassMethodArgumentMetadata query_metadata[5] = {0};
    for (int i = 0; i < 5; ++i)
        query_arguments[i] = (GDExtensionPropertyInfo){types[i], &query_args[i], &empty_name, 0, &empty_string, 6};
    method.name = &query_name;
    method.call_func = nearby_call;
    method.ptrcall_func = nearby_ptrcall;
    method.return_value_info = &query_output;
    method.argument_count = 5;
    method.arguments_info = query_arguments;
    method.arguments_metadata = query_metadata;
    register_method(library, &class_name, &method);
}

static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    if (class_registered) unregister_class(library, &class_name);
    Value *names[] = { &class_name, &parent_name, &pack_name, &node_name, &transform_name,
                      &empty_name, &entries_name, &capacity_name, &size_name, &resize_name,
                      &query_name, &object_name, &queued_name, &append_name, &has_name, &visible_name };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); ++i) get_dtor(TYPE(STRING_NAME))(names[i]);
    get_dtor(TYPE(STRING))(&empty_string);
    for (int i = 0; i < 4; ++i) variant_destroy(&keys[i]);
    for (int i = 0; i < 5; ++i) get_dtor(TYPE(STRING_NAME))(&query_args[i]);
}

__declspec(dllexport) GDExtensionBool copperfin_library_init(GDExtensionInterfaceGetProcAddress proc,
             GDExtensionClassLibraryPtr lib, GDExtensionInitialization *init) {
    library = lib;
#define LOAD(name, suffix, symbol) name = (GDExtensionInterface##suffix)proc(symbol); if (!name) return 0
    LOAD(name_new, StringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(string_new, StringNewWithUtf8Chars, "string_new_with_utf8_chars");
    LOAD(from_type, GetVariantFromTypeConstructor, "get_variant_from_type_constructor");
    LOAD(to_type, GetVariantToTypeConstructor, "get_variant_to_type_constructor");
    LOAD(get_ctor, VariantGetPtrConstructor, "variant_get_ptr_constructor");
    LOAD(get_dtor, VariantGetPtrDestructor, "variant_get_ptr_destructor");
    LOAD(get_builtin, VariantGetPtrBuiltinMethod, "variant_get_ptr_builtin_method");
    LOAD(get_type, VariantGetType, "variant_get_type");
    LOAD(variant_destroy, VariantDestroy, "variant_destroy");
    LOAD(variant_nil, VariantNewNil, "variant_new_nil");
    LOAD(array_index, ArrayOperatorIndexConst, "array_operator_index_const");
    LOAD(dict_index, DictionaryOperatorIndexConst, "dictionary_operator_index_const");
    LOAD(bytes_index, PackedByteArrayOperatorIndex, "packed_byte_array_operator_index");
    LOAD(object_id, VariantGetObjectInstanceId, "variant_get_object_instance_id");
    LOAD(object_from_id, ObjectGetInstanceFromId, "object_get_instance_from_id");
    LOAD(object_cast, ObjectCastTo, "object_cast_to");
    LOAD(class_tag, ClassdbGetClassTag, "classdb_get_class_tag");
    LOAD(method_bind, ClassdbGetMethodBind, "classdb_get_method_bind");
    LOAD(ptrcall, ObjectMethodBindPtrcall, "object_method_bind_ptrcall");
    LOAD(construct, ClassdbConstructObject2, "classdb_construct_object2");
    LOAD(set_instance, ObjectSetInstance, "object_set_instance");
    LOAD(register_class, ClassdbRegisterExtensionClass4, "classdb_register_extension_class4");
    LOAD(register_method, ClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(unregister_class, ClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    init->userdata = 0;
    init->initialize = initialize;
    init->deinitialize = deinitialize;
    return 1;
}
