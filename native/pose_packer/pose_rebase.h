/* Preserve the last two simulation roots when visual poses are coalesced.
 * Local articulation may advance once per rendered frame; translation and
 * heading still interpolate between consecutive simulation ticks. */
static Value rebase_method, rebase_key, rebase_arguments[2];
static GDExtensionPtrBuiltInMethod rebase_bytes_size;
static GDExtensionInterfacePackedByteArrayOperatorIndexConst rebase_bytes_read;
static int rebase_initialized;

static void rebase_core(const void *input, const void *entries, void *output) {
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 0)(output, 0);
    int64_t length = 0;
    rebase_bytes_size((void *)input, 0, &length, 0);
    if (length <= 0 || length % 64 || length > 8192 * 64) return;
    int64_t error = 0;
    const void *resize[] = {&length};
    bytes_resize(output, resize, &error, 1);
    if (error) return;
    float *pixels = (float *)bytes_index(output, 0);
    memcpy(pixels, rebase_bytes_read(input, 0), (size_t)length);
    int64_t capacity = length / 64;
    static const float identity[12] = {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0};
    for (int64_t i = 0; i < count_array((void *)entries); ++i) {
        void *value = array_index(entries, i);
        if (get_type(value) != TYPE(DICTIONARY)) continue;
        Value entry, anchors;
        to_type(TYPE(DICTIONARY))(&entry, value);
        void *offset_value = dictionary_lookup(&entry, &keys[1]);
        void *anchor_value = dictionary_lookup(&entry, &keys[0]);
        void *delta_value = dictionary_lookup(&entry, &rebase_key);
        if (!offset_value || !anchor_value || !delta_value || get_type(offset_value) != TYPE(INT) ||
            get_type(anchor_value) != TYPE(ARRAY) || get_type(delta_value) != TYPE(TRANSFORM3D)) {
            get_dtor(TYPE(DICTIONARY))(&entry);
            continue;
        }
        float delta[12];
        to_type(TYPE(TRANSFORM3D))(delta, delta_value);
        int valid = 1;
        for (int axis = 0; axis < 12; ++axis) if (!isfinite(delta[axis])) valid = 0;
        if (!valid || !memcmp(delta, identity, sizeof(identity))) {
            get_dtor(TYPE(DICTIONARY))(&entry);
            continue;
        }
        int64_t offset;
        to_type(TYPE(INT))(&offset, offset_value);
        to_type(TYPE(ARRAY))(&anchors, anchor_value);
        int64_t count = count_array(&anchors);
        if (offset >= 1 && count <= capacity && offset <= capacity - count) {
            for (int64_t part = 0; part < count; ++part) {
                float *row = pixels + (offset + part) * 16;
                float old[12], advanced[12];
                int shown = 0;
                for (int axis = 0; axis < 3; ++axis) {
                    memcpy(old + axis * 3, row + axis * 4, sizeof(float) * 3);
                    old[9 + axis] = row[axis * 4 + 3];
                    for (int column = 0; column < 3; ++column) shown |= row[axis * 4 + column] != 0;
                }
                if (!shown) continue;
                compose_pose(delta, old, advanced);
                for (int axis = 0; axis < 3; ++axis) {
                    memcpy(row + axis * 4, advanced + axis * 3, sizeof(float) * 3);
                    row[axis * 4 + 3] = advanced[9 + axis];
                }
            }
        }
        get_dtor(TYPE(ARRAY))(&anchors);
        get_dtor(TYPE(DICTIONARY))(&entry);
    }
}

static void rebase_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                        GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 2 || get_type(args[0]) != TYPE(PACKED_BYTE_ARRAY) || get_type(args[1]) != TYPE(ARRAY)) {
        variant_nil(ret); return;
    }
    Value input, entries, output;
    to_type(TYPE(PACKED_BYTE_ARRAY))(&input, (void *)args[0]);
    to_type(TYPE(ARRAY))(&entries, (void *)args[1]);
    rebase_core(&input, &entries, &output);
    from_type(TYPE(PACKED_BYTE_ARRAY))(ret, &output);
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&output);
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&input);
    get_dtor(TYPE(ARRAY))(&entries);
    error->error = GDEXTENSION_CALL_OK;
}

static void rebase_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    rebase_core(args[0], args[1], ret);
}

static int rebase_load(GDExtensionInterfaceGetProcAddress proc) {
    rebase_bytes_read = (GDExtensionInterfacePackedByteArrayOperatorIndexConst)proc("packed_byte_array_operator_index_const");
    return rebase_bytes_read != 0;
}

static void rebase_initialize(void) {
    name_new(&rebase_method, "rebase_poses");
    name_new(&rebase_arguments[0], "pixels");
    name_new(&rebase_arguments[1], "entries");
    Value key;
    string_new(&key, "rebase");
    from_type(TYPE(STRING))(&rebase_key, &key);
    get_dtor(TYPE(STRING))(&key);
    rebase_initialized = 1;
    rebase_bytes_size = get_builtin(TYPE(PACKED_BYTE_ARRAY), &size_name, 3173160232LL);
    if (!rebase_bytes_size) return;
    GDExtensionPropertyInfo output = {TYPE(PACKED_BYTE_ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo arguments[] = {
        {TYPE(PACKED_BYTE_ARRAY), &rebase_arguments[0], &empty_name, 0, &empty_string, 6},
        {TYPE(ARRAY), &rebase_arguments[1], &empty_name, 0, &empty_string, 6}
    };
    GDExtensionClassMethodArgumentMetadata metadata[2] = {0};
    GDExtensionClassMethodInfo method = {0};
    method.name = &rebase_method;
    method.call_func = rebase_call;
    method.ptrcall_func = rebase_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1;
    method.return_value_info = &output;
    method.argument_count = 2;
    method.arguments_info = arguments;
    method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
}

static void rebase_deinitialize(void) {
    if (!rebase_initialized) return;
    get_dtor(TYPE(STRING_NAME))(&rebase_method);
    for (int i = 0; i < 2; ++i) get_dtor(TYPE(STRING_NAME))(&rebase_arguments[i]);
    variant_destroy(&rebase_key);
    rebase_initialized = 0;
}
