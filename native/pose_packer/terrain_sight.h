/* Exact terrain-ray kernel. Packed terrain arrays are borrowed only for this
 * call, so edits and replacement arrays remain visible without invalidation. */
static GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst sight_float_index;
static GDExtensionInterfacePackedByteArrayOperatorIndexConst sight_byte_index;
static GDExtensionPtrBuiltInMethod sight_float_size, sight_byte_size;
static Value sight_method, sight_fields[8], sight_arguments[4];
static int sight_initialized;

static int sight_cell(float x, float z, int columns, int rows, float scale) {
    float cx = x / scale, cz = z / scale;
    int column = cx <= 0 ? 0 : (cx >= columns ? columns - 1 : (int)cx);
    int row = cz <= 0 ? 0 : (cz >= rows ? rows - 1 : (int)cz);
    return row * columns + column;
}

static GDExtensionBool terrain_sight_core(const void *model, const float *origin,
                                         const float *end, GDExtensionBool forest) {
    float dx = end[0] - origin[0], dz = end[2] - origin[2];
    float length = sqrtf(dx * dx + dz * dz);
    if (!isfinite(length) || !isfinite(origin[1]) || !isfinite(end[1]) || length > 1000000) return 0;
    if (length <= 1.5f) return 1;
    const GDExtensionVariantType types[8] = {TYPE(INT), TYPE(INT), TYPE(PACKED_FLOAT32_ARRAY),
        TYPE(PACKED_FLOAT32_ARRAY), TYPE(PACKED_BYTE_ARRAY), TYPE(INT),
        TYPE(PACKED_FLOAT32_ARRAY), TYPE(PACKED_BYTE_ARRAY)};
    Value fields[8], packed[5];
    int read = 0, borrowed = 0;
    GDExtensionBool result = 0;
    for (int i = 0; i < 8; ++i) {
        GDExtensionBool valid = 0;
        get_named(model, &sight_fields[i], &fields[i], &valid);
        read++;
        if (!valid || get_type(&fields[i]) != types[i]) goto cleanup;
    }
    int64_t columns, rows, coarse_columns;
    to_type(TYPE(INT))(&columns, &fields[0]);
    to_type(TYPE(INT))(&rows, &fields[1]);
    to_type(TYPE(INT))(&coarse_columns, &fields[5]);
    if (columns <= 0 || rows <= 0 || columns > 32768 || rows > 32768 ||
        coarse_columns <= 0 || coarse_columns > 32768) goto cleanup;
    const int slots[5] = {2, 3, 4, 6, 7};
    int64_t sizes[5];
    for (int i = 0; i < 5; ++i) {
        GDExtensionVariantType type = types[slots[i]];
        to_type(type)(&packed[i], &fields[slots[i]]);
        borrowed++;
        (type == TYPE(PACKED_FLOAT32_ARRAY) ? sight_float_size : sight_byte_size)(
            &packed[i], 0, &sizes[i], 0);
    }
    int64_t cells = columns * rows;
    if (sizes[0] < cells || sizes[1] < cells || sizes[2] < cells ||
        sizes[3] < coarse_columns || sizes[3] % coarse_columns || sizes[4] < sizes[3]) goto cleanup;
    const float *ground = sight_float_index(&packed[0], 0);
    const float *cover = sight_float_index(&packed[1], 0);
    const uint8_t *flags = sight_byte_index(&packed[2], 0);
    const float *coarse = sight_float_index(&packed[3], 0);
    const uint8_t *woods = sight_byte_index(&packed[4], 0);
    int coarse_rows = (int)(sizes[3] / coarse_columns);
    int samples = (int)ceil((double)length);
    double lowest = fmin(origin[1], end[1]);
    int open = 1;
    for (int i = 0; i <= samples; ++i) {
        float t = (float)((double)i / samples);
        float x = origin[0] + dx * t, z = origin[2] + dz * t;
        int cell = sight_cell(x, z, (int)coarse_columns, coarse_rows, 4.0f);
        if (coarse[cell] > lowest || (forest && woods[cell])) { open = 0; break; }
    }
    if (open) { result = 1; goto cleanup; }
    int steps = (int)ceil((double)length / 0.5);
    for (int step = 1; step < steps; ++step) {
        double t = (double)step / steps;
        double distance = t * length;
        double from_end = fmin(distance, length - distance);
        float weight = (float)t;
        int cell = sight_cell(origin[0] + dx * weight, origin[2] + dz * weight,
                              (int)columns, (int)rows, 0.5f);
        double line = (double)origin[1] + ((double)end[1] - origin[1]) * t;
        if (from_end > 0.75 && ground[cell] > line) goto cleanup;
        if (cover[cell] > line && ((flags[cell] & 2) || (forest && from_end > 3.0))) goto cleanup;
    }
    result = 1;
cleanup:
    for (int i = 0; i < borrowed; ++i) get_dtor(types[(int[]){2, 3, 4, 6, 7}[i]])(&packed[i]);
    for (int i = 0; i < read; ++i) variant_destroy(&fields[i]);
    return result;
}

static void terrain_sight_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                               GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 4 || get_type(args[0]) != TYPE(OBJECT) || get_type(args[1]) != TYPE(VECTOR3) ||
        get_type(args[2]) != TYPE(VECTOR3) || get_type(args[3]) != TYPE(BOOL)) { variant_nil(ret); return; }
    float origin[3], end[3];
    GDExtensionBool forest;
    to_type(TYPE(VECTOR3))(origin, (void *)args[1]);
    to_type(TYPE(VECTOR3))(end, (void *)args[2]);
    to_type(TYPE(BOOL))(&forest, (void *)args[3]);
    GDExtensionBool result = terrain_sight_core(args[0], origin, end, forest);
    from_type(TYPE(BOOL))(ret, &result);
    error->error = GDEXTENSION_CALL_OK;
}

static void terrain_sight_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    Value model;
    from_type(TYPE(OBJECT))(&model, (void *)args[0]);
    *(GDExtensionBool *)ret = terrain_sight_core(&model, args[1], args[2], *(const GDExtensionBool *)args[3]);
    variant_destroy(&model);
}

static int terrain_sight_load(GDExtensionInterfaceGetProcAddress proc) {
    sight_float_index = (GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst)proc("packed_float32_array_operator_index_const");
    sight_byte_index = (GDExtensionInterfacePackedByteArrayOperatorIndexConst)proc("packed_byte_array_operator_index_const");
    return sight_float_index && sight_byte_index;
}

static void terrain_sight_initialize(void) {
    name_new(&sight_method, "terrain_segment_clear");
    const char *fields[] = {"columns", "rows", "ground_tops", "cover_tops", "flags", "coarse_columns", "coarse_tops", "coarse_forest"};
    const char *arguments[] = {"model", "origin", "end", "forest_blocks"};
    for (int i = 0; i < 8; ++i) name_new(&sight_fields[i], fields[i]);
    for (int i = 0; i < 4; ++i) name_new(&sight_arguments[i], arguments[i]);
    sight_initialized = 1;
    sight_float_size = get_builtin(TYPE(PACKED_FLOAT32_ARRAY), &size_name, 3173160232LL);
    sight_byte_size = get_builtin(TYPE(PACKED_BYTE_ARRAY), &size_name, 3173160232LL);
    if (!sight_float_size || !sight_byte_size) return;
    GDExtensionPropertyInfo output = {TYPE(BOOL), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionVariantType types[] = {TYPE(OBJECT), TYPE(VECTOR3), TYPE(VECTOR3), TYPE(BOOL)};
    GDExtensionPropertyInfo parameters[4];
    GDExtensionClassMethodArgumentMetadata metadata[4] = {0};
    for (int i = 0; i < 4; ++i) parameters[i] = (GDExtensionPropertyInfo){types[i], &sight_arguments[i], &empty_name, 0, &empty_string, 6};
    parameters[0].class_name = &parent_name;
    GDExtensionClassMethodInfo method = {0};
    method.name = &sight_method;
    method.call_func = terrain_sight_call;
    method.ptrcall_func = terrain_sight_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1;
    method.return_value_info = &output;
    method.argument_count = 4;
    method.arguments_info = parameters;
    method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
}

static void terrain_sight_deinitialize(void) {
    if (!sight_initialized) return;
    get_dtor(TYPE(STRING_NAME))(&sight_method);
    for (int i = 0; i < 8; ++i) get_dtor(TYPE(STRING_NAME))(&sight_fields[i]);
    for (int i = 0; i < 4; ++i) get_dtor(TYPE(STRING_NAME))(&sight_arguments[i]);
    sight_initialized = 0;
}
