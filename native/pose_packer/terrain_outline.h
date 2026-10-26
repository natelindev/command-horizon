/* Fog geometry, using the same sampling and interval rules as TerrainSight.
 * Borrow terrain arrays for this call only; never retain SceneTree pointers. */
static Value outline_method, outline_fields[11], outline_arguments[4];
static GDExtensionInterfacePackedVector2ArrayOperatorIndex outline_vector_write;
static GDExtensionPtrBuiltInMethod outline_resize;
static int outline_initialized;

static double outline_height(const float *heights, const float *centre, int columns, int rows) {
    double x = fmax(0, fmin((double)centre[0] * 2.0, columns));
    double z = fmax(0, fmin((double)centre[1] * 2.0, rows));
    int i = (int)fmin((int)x, columns - 1), j = (int)fmin((int)z, rows - 1);
    int stride = columns + 1, index = j * stride + i;
    double top = heights[index] + ((double)heights[index + 1] - heights[index]) * (x - i);
    double bottom = heights[index + stride] + ((double)heights[index + stride + 1] - heights[index + stride]) * (x - i);
    return top + (bottom - top) * (z - j);
}

static void outline_wedge(float *points, int *count, const float *centre,
                          const float *left, const float *right, float near, float far) {
    float a[] = {centre[0] + left[0] * near, centre[1] + left[1] * near};
    float b[] = {centre[0] + right[0] * near, centre[1] + right[1] * near};
    float c[] = {centre[0] + right[0] * far, centre[1] + right[1] * far};
    float d[] = {centre[0] + left[0] * far, centre[1] + left[1] * far};
    const float *vertices[] = {a, b, c, a, c, d};
    if (near <= 0) {
        vertices[0] = centre; vertices[1] = d; vertices[2] = c;
    }
    int length = near <= 0 ? 3 : 6;
    for (int i = 0; i < length; ++i) {
        points[*count * 2] = vertices[i][0];
        points[*count * 2 + 1] = vertices[i][1];
        ++*count;
    }
}

static void terrain_outline_core(const void *model, const float *centre, double reach,
                                  double level_reach, void *output) {
    get_ctor(TYPE(PACKED_VECTOR2_ARRAY), 0)(output, 0);
    if (!isfinite(centre[0]) || !isfinite(centre[1]) || !isfinite(reach) ||
        !isfinite(level_reach) || reach <= 0 || reach > 1024) return;
    const GDExtensionVariantType types[] = {TYPE(INT), TYPE(INT), TYPE(PACKED_FLOAT32_ARRAY),
        TYPE(PACKED_FLOAT32_ARRAY), TYPE(PACKED_FLOAT32_ARRAY), TYPE(PACKED_FLOAT32_ARRAY),
        TYPE(PACKED_BYTE_ARRAY), TYPE(INT), TYPE(PACKED_FLOAT32_ARRAY),
        TYPE(PACKED_FLOAT32_ARRAY), TYPE(PACKED_BYTE_ARRAY)};
    const int slots[] = {2, 3, 4, 5, 6, 8, 9, 10};
    Value fields[11], packed[8];
    int read = 0, borrowed = 0;
    float *points = 0;
    for (int i = 0; i < 11; ++i) {
        GDExtensionBool valid = 0;
        get_named(model, &outline_fields[i], &fields[i], &valid);
        ++read;
        if (!valid || get_type(&fields[i]) != types[i]) goto cleanup;
    }
    int64_t columns, rows, coarse_columns, sizes[8];
    to_type(TYPE(INT))(&columns, &fields[0]);
    to_type(TYPE(INT))(&rows, &fields[1]);
    to_type(TYPE(INT))(&coarse_columns, &fields[7]);
    if (columns <= 0 || rows <= 0 || columns > 32768 || rows > 32768 ||
        coarse_columns <= 0 || coarse_columns > 32768) goto cleanup;
    for (int i = 0; i < 8; ++i) {
        to_type(types[slots[i]])(&packed[i], &fields[slots[i]]);
        ++borrowed;
        (types[slots[i]] == TYPE(PACKED_BYTE_ARRAY) ? sight_byte_size : sight_float_size)(
            &packed[i], 0, &sizes[i], 0);
    }
    if (sizes[0] < (columns + 1) * (rows + 1) || sizes[1] < columns * rows ||
        sizes[2] < columns * rows || sizes[3] < columns * rows || sizes[4] < columns * rows ||
        sizes[5] < coarse_columns || sizes[5] % coarse_columns || sizes[6] < sizes[5] ||
        sizes[7] < sizes[5]) goto cleanup;
    const float *heights = sight_float_index(&packed[0], 0);
    const float *tops = sight_float_index(&packed[1], 0);
    const float *floors = sight_float_index(&packed[2], 0);
    const float *cover = sight_float_index(&packed[3], 0);
    const uint8_t *flags = sight_byte_index(&packed[4], 0);
    const float *coarse_top = sight_float_index(&packed[5], 0);
    const float *coarse_bottom = sight_float_index(&packed[6], 0);
    const uint8_t *coarse_forest = sight_byte_index(&packed[7], 0);
    double ground = outline_height(heights, centre, (int)columns, (int)rows), eye = ground + .8;
    if (level_reach < 0) {
        int coarse_rows = (int)(sizes[5] / coarse_columns);
        float radius = (float)reach;
        int low = sight_cell(centre[0] - radius, centre[1] - radius, (int)coarse_columns, coarse_rows, 4);
        int high = sight_cell(centre[0] + radius, centre[1] + radius, (int)coarse_columns, coarse_rows, 4);
        int open = 1;
        for (int row = low / coarse_columns; row <= high / coarse_columns && open; ++row) {
            for (int column = low % coarse_columns; column <= high % coarse_columns; ++column) {
                int cell = (int)(row * coarse_columns + column);
                if (coarse_top[cell] > ground + .4 || coarse_bottom[cell] < ground - .4 || coarse_forest[cell]) {
                    open = 0; break;
                }
            }
        }
        if (open) goto cleanup;
    }
    /* At most one closed/open interval transition per sample and one tail. */
    size_t capacity = (size_t)(ceil(reach / .5) + 1) * 48 * 6;
    points = malloc(capacity * sizeof(float) * 2);
    if (!points) goto cleanup;
    int count = 0;
    const double tau = 6.283185307179586476925286766559;
    for (int ray = 0; ray < 48; ++ray) {
        double angle = ray * tau / 48.0, half = tau / 96.0;
        float direction[] = {cosf((float)angle), sinf((float)angle)};
        float left[] = {cosf((float)(angle - half)), sinf((float)(angle - half))};
        float right[] = {cosf((float)(angle + half)), sinf((float)(angle + half))};
        double horizon = -INFINITY, forest_from = INFINITY, open_from = 0;
        int is_open = 1;
        for (double distance = .5; distance <= reach; distance += .5) {
            /* GDScript scalar arithmetic is double; Vector2 output is float. */
            double x = centre[0] + direction[0] * distance;
            double z = centre[1] + direction[1] * distance;
            int column = x <= 0 ? 0 : (x * 2 >= columns ? (int)columns - 1 : (int)(x * 2));
            int row = z <= 0 ? 0 : (z * 2 >= rows ? (int)rows - 1 : (int)(z * 2));
            int cell = (int)(row * columns + column), flag = flags[cell];
            double floor_height = floors[cell];
            if ((flag & 4) && distance > 3) forest_from = fmin(forest_from, distance);
            int visible = (distance <= .75 || (floor_height + .8 - eye) / distance >= horizon) &&
                (level_reach < 0 || distance <= level_reach || ground - floor_height >= 1.5) &&
                distance < forest_from + 3 && !(floor_height - ground >= 1.5 && distance > 1.5) &&
                !((flag & 2) && cover[cell] > eye);
            if (visible && !is_open) { open_from = distance - .25; is_open = 1; }
            else if (!visible && is_open) {
                outline_wedge(points, &count, centre, left, right, (float)open_from, (float)(distance - .25));
                is_open = 0;
            }
            if (distance > .75) horizon = fmax(horizon, (tops[cell] - eye) / distance);
            if ((flag & 2) && cover[cell] > eye) break;
        }
        if (is_open) outline_wedge(points, &count, centre, left, right, (float)open_from, (float)reach);
    }
    if (count > 0) {
        int64_t length = count, error = 0;
        const void *resize[] = {&length};
        outline_resize(output, resize, &error, 1);
        if (!error) memcpy(outline_vector_write(output, 0), points, (size_t)count * sizeof(float) * 2);
    }
cleanup:
    free(points);
    for (int i = 0; i < borrowed; ++i) get_dtor(types[slots[i]])(&packed[i]);
    for (int i = 0; i < read; ++i) variant_destroy(&fields[i]);
}

static void terrain_outline_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                                 GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 4 || get_type(args[0]) != TYPE(OBJECT) || get_type(args[1]) != TYPE(VECTOR2) ||
        get_type(args[2]) != TYPE(FLOAT) || get_type(args[3]) != TYPE(FLOAT)) { variant_nil(ret); return; }
    float centre[2]; double reach, level_reach; Value output;
    to_type(TYPE(VECTOR2))(centre, (void *)args[1]);
    to_type(TYPE(FLOAT))(&reach, (void *)args[2]);
    to_type(TYPE(FLOAT))(&level_reach, (void *)args[3]);
    terrain_outline_core(args[0], centre, reach, level_reach, &output);
    from_type(TYPE(PACKED_VECTOR2_ARRAY))(ret, &output);
    get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&output);
    error->error = GDEXTENSION_CALL_OK;
}

static void terrain_outline_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    Value model;
    from_type(TYPE(OBJECT))(&model, (void *)args[0]);
    terrain_outline_core(&model, args[1], *(const double *)args[2], *(const double *)args[3], ret);
    variant_destroy(&model);
}

static int terrain_outline_load(GDExtensionInterfaceGetProcAddress proc) {
    outline_vector_write = (GDExtensionInterfacePackedVector2ArrayOperatorIndex)proc("packed_vector2_array_operator_index");
    return outline_vector_write != 0;
}

static void terrain_outline_initialize(void) {
    name_new(&outline_method, "terrain_reveal_triangles");
    const char *fields[] = {"columns", "rows", "heights", "ground_tops", "cell_heights", "cover_tops",
        "flags", "coarse_columns", "coarse_tops", "coarse_bottoms", "coarse_forest"};
    const char *arguments[] = {"model", "centre", "reach", "level_reach"};
    for (int i = 0; i < 11; ++i) name_new(&outline_fields[i], fields[i]);
    for (int i = 0; i < 4; ++i) name_new(&outline_arguments[i], arguments[i]);
    outline_initialized = 1;
    outline_resize = get_builtin(TYPE(PACKED_VECTOR2_ARRAY), &resize_name, 848867239LL);
    if (!outline_resize) return;
    GDExtensionPropertyInfo output = {TYPE(PACKED_VECTOR2_ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionVariantType types[] = {TYPE(OBJECT), TYPE(VECTOR2), TYPE(FLOAT), TYPE(FLOAT)};
    GDExtensionPropertyInfo parameters[4];
    GDExtensionClassMethodArgumentMetadata metadata[4] = {0, 0, GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE, GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE};
    for (int i = 0; i < 4; ++i) parameters[i] = (GDExtensionPropertyInfo){types[i], &outline_arguments[i], &empty_name, 0, &empty_string, 6};
    parameters[0].class_name = &parent_name;
    GDExtensionClassMethodInfo method = {0};
    method.name = &outline_method; method.call_func = terrain_outline_call; method.ptrcall_func = terrain_outline_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL; method.has_return_value = 1; method.return_value_info = &output;
    method.argument_count = 4; method.arguments_info = parameters; method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
}

static void terrain_outline_deinitialize(void) {
    if (!outline_initialized) return;
    get_dtor(TYPE(STRING_NAME))(&outline_method);
    for (int i = 0; i < 11; ++i) get_dtor(TYPE(STRING_NAME))(&outline_fields[i]);
    for (int i = 0; i < 4; ++i) get_dtor(TYPE(STRING_NAME))(&outline_arguments[i]);
    outline_initialized = 0;
}
