/* Pack the compute fog's circle/triangle bins without crossing the script VM
 * for every tile. Inputs are borrowed for one call; output buffers own copies.
 * An empty result requests the portable path for unsupported input or OOM. */
typedef struct {
    float values[8];
    int low_x, low_y, high_x, high_y;
} FpPrimitive;
static Value fp_name, fp_fields[3], fp_arguments[2];
static GDExtensionPtrBuiltInMethod fp_vector_size;
static GDExtensionInterfacePackedVector2ArrayOperatorIndexConst fp_vector_read;

static int fp_add(FpPrimitive **items, int *count, int *capacity, const float *values,
                  float low_x, float low_y, float high_x, float high_y, int columns, int rows) {
    if (!isfinite(low_x) || !isfinite(low_y) || !isfinite(high_x) || !isfinite(high_y)) return 0;
    double lx = floor(low_x / 16.0), ly = floor(low_y / 16.0);
    double hx = floor(high_x / 16.0), hy = floor(high_y / 16.0);
    if (hx < 0 || hy < 0 || lx >= columns || ly >= rows) return 1;
    if (*count >= 1048576) return 0;
    if (*count == *capacity) {
        int next = *capacity ? *capacity * 2 : 256;
        FpPrimitive *grown = realloc(*items, (size_t)next * sizeof(**items));
        if (!grown) return 0;
        *items = grown; *capacity = next;
    }
    FpPrimitive *p = *items + (*count)++;
    memcpy(p->values, values, sizeof(p->values));
    p->low_x = (int)fmax(0, fmin(columns, lx));
    p->low_y = (int)fmax(0, fmin(rows, ly));
    p->high_x = (int)fmax(-1, fmin(columns - 1, hx));
    p->high_y = (int)fmax(-1, fmin(rows - 1, hy));
    return 1;
}

static int fp_reveal(const void *reveal, FpPrimitive **items, int *count, int *capacity,
                     int columns, int rows) {
    Value fields[3] = {{0}}, triangles = {0};
    int read = 0, borrowed = 0, success = 0;
    const GDExtensionVariantType types[] = {TYPE(VECTOR2), TYPE(FLOAT), TYPE(PACKED_VECTOR2_ARRAY)};
    for (int i = 0; i < 3; ++i) {
        GDExtensionBool valid = 0;
        get_named(reveal, &fp_fields[i], &fields[i], &valid);
        ++read;
        if (!valid || (get_type(&fields[i]) != types[i] && !(i == 1 && get_type(&fields[i]) == TYPE(INT))))
            goto cleanup;
    }
    float centre[2];
    double radius;
    to_type(TYPE(VECTOR2))(centre, &fields[0]);
    to_type(TYPE(FLOAT))(&radius, &fields[1]);
    if (!isfinite(centre[0]) || !isfinite(centre[1]) || !isfinite(radius) || radius < 0) goto cleanup;
    to_type(TYPE(PACKED_VECTOR2_ARRAY))(&triangles, &fields[2]); borrowed = 1;
    int64_t size = 0;
    fp_vector_size(&triangles, 0, &size, 0);
    if (size < 3) {
        float reach = (float)radius;
        float values[] = {centre[0], centre[1], reach, 0, 0, 0, 0, 0};
        /* Rect2(center - radius, radius * 2).end preserves float rounding. */
        float low_x = centre[0] - reach, low_y = centre[1] - reach;
        success = fp_add(items, count, capacity, values, low_x, low_y,
                         low_x + reach * 2.0f, low_y + reach * 2.0f, columns, rows);
    } else {
        const float *points = (const float *)fp_vector_read(&triangles, 0);
        success = 1;
        for (int64_t i = 0; i + 2 < size && success; i += 3) {
            float values[] = {points[2*i] + centre[0], points[2*i+1] + centre[1],
                points[2*i+2] + centre[0], points[2*i+3] + centre[1],
                points[2*i+4] + centre[0], points[2*i+5] + centre[1], 1, 0};
            for (int j = 0; j < 6; ++j) if (!isfinite(values[j])) {success = 0; break;}
            if (!success) break;
            float lx = fminf(values[0], fminf(values[2], values[4]));
            float ly = fminf(values[1], fminf(values[3], values[5]));
            float hx = fmaxf(values[0], fmaxf(values[2], values[4]));
            float hy = fmaxf(values[1], fmaxf(values[3], values[5]));
            success = fp_add(items, count, capacity, values, lx, ly,
                             lx + (hx - lx), ly + (hy - ly), columns, rows);
        }
    }
cleanup:
    if (borrowed) get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&triangles);
    for (int i = 0; i < read; ++i) variant_destroy(&fields[i]);
    return success;
}

static void fp_core(const void *reveals, const int32_t *dimensions, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    if (dimensions[0] <= 0 || dimensions[1] <= 0 || dimensions[0] > 16384 || dimensions[1] > 16384) return;
    int columns = (dimensions[0] + 15) / 16, rows = (dimensions[1] + 15) / 16;
    int bins = columns * rows, count = 0, capacity = 0;
    FpPrimitive *items = 0;
    int32_t *ranges = calloc((size_t)bins * 2, sizeof(*ranges)), *indices = 0, *cursors = 0;
    float *data = 0;
    if (!ranges) goto cleanup;
    int64_t n = count_array((void *)reveals);
    for (int64_t i = 0; i < n; ++i)
        if (!fp_reveal(array_index(reveals, i), &items, &count, &capacity, columns, rows)) goto cleanup;
    int64_t total = 0;
    for (int i = 0; i < count; ++i) {
        FpPrimitive *p = items + i;
        for (int y = p->low_y; y <= p->high_y; ++y)
            for (int x = p->low_x; x <= p->high_x; ++x) ++ranges[2 * (y * columns + x) + 1];
        total += (int64_t)(p->high_x - p->low_x + 1) * (p->high_y - p->low_y + 1);
        if (total > 16777216) goto cleanup;
    }
    cursors = calloc((size_t)bins, sizeof(*cursors));
    indices = calloc((size_t)(total ? total : 1), sizeof(*indices));
    data = calloc((size_t)(count ? count : 1) * 8, sizeof(*data));
    if (!cursors || !indices || !data) goto cleanup;
    int32_t start = 0;
    for (int i = 0; i < bins; ++i) {
        ranges[2*i] = cursors[i] = start;
        start += ranges[2*i+1];
    }
    for (int i = 0; i < count; ++i) {
        FpPrimitive *p = items + i;
        memcpy(data + i * 8, p->values, sizeof(p->values));
        for (int y = p->low_y; y <= p->high_y; ++y)
            for (int x = p->low_x; x <= p->high_x; ++x) indices[cursors[y * columns + x]++] = i;
    }
    int64_t sizes[] = {(int64_t)(count ? count : 1) * 32, (int64_t)bins * 8, (total ? total : 1) * 4};
    const void *sources[] = {data, ranges, indices};
    /* Publish only once all buffers exist, leaving an empty fallback on OOM. */
    Value bytes[3];
    int created = 0;
    for (int i = 0; i < 3; ++i) {
        get_ctor(TYPE(PACKED_BYTE_ARRAY), 0)(&bytes[i], 0); ++created;
        int64_t error = 0;
        bytes_resize(&bytes[i], (const void *[]){&sizes[i]}, &error, 1);
        if (error) break;
        memcpy(bytes_index(&bytes[i], 0), sources[i], (size_t)sizes[i]);
        if (i == 2) {
            for (int j = 0; j < 3; ++j) {
                Value value;
                from_type(TYPE(PACKED_BYTE_ARRAY))(&value, &bytes[j]);
                array_append(output, (const void *[]){&value}, 0, 1);
                variant_destroy(&value);
            }
        }
    }
    for (int i = 0; i < created; ++i) get_dtor(TYPE(PACKED_BYTE_ARRAY))(&bytes[i]);
cleanup:
    free(items); free(ranges); free(indices); free(cursors); free(data);
}

static void fp_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                     GDExtensionInt count, void *ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    variant_nil(ret);
    if (count != 2) {error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; return;}
    if (get_type(args[0]) != TYPE(ARRAY) || get_type(args[1]) != TYPE(VECTOR2I)) {
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT; return;
    }
    Value reveals, result;
    int32_t dimensions[2];
    to_type(TYPE(ARRAY))(&reveals, (void *)args[0]);
    to_type(TYPE(VECTOR2I))(dimensions, (void *)args[1]);
    fp_core(&reveals, dimensions, &result);
    variant_destroy(ret); from_type(TYPE(ARRAY))(ret, &result);
    get_dtor(TYPE(ARRAY))(&result); get_dtor(TYPE(ARRAY))(&reveals);
    error->error = GDEXTENSION_CALL_OK;
}

static void fp_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    fp_core(args[0], args[1], ret);
}

static void fog_pack_initialize(void) {
    name_new(&fp_name, "pack_fog");
    const char *fields[] = {"position", "radius", "triangles"};
    for (int i = 0; i < 3; ++i) name_new(&fp_fields[i], fields[i]);
    name_new(&fp_arguments[0], "reveals"); name_new(&fp_arguments[1], "dimensions");
    fp_vector_size = get_builtin(TYPE(PACKED_VECTOR2_ARRAY), &size_name, 3173160232LL);
    if (!fp_vector_size) return;
    GDExtensionPropertyInfo result = {TYPE(ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo arguments[] = {
        {TYPE(ARRAY), &fp_arguments[0], &empty_name, 0, &empty_string, 6},
        {TYPE(VECTOR2I), &fp_arguments[1], &empty_name, 0, &empty_string, 6}};
    GDExtensionClassMethodArgumentMetadata metadata[2] = {0};
    GDExtensionClassMethodInfo method = {0};
    method.name = &fp_name; method.call_func = fp_call; method.ptrcall_func = fp_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1; method.return_value_info = &result;
    method.argument_count = 2; method.arguments_info = arguments; method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
}

static void fog_pack_deinitialize(void) {
    get_dtor(TYPE(STRING_NAME))(&fp_name);
    for (int i = 0; i < 3; ++i) get_dtor(TYPE(STRING_NAME))(&fp_fields[i]);
    for (int i = 0; i < 2; ++i) get_dtor(TYPE(STRING_NAME))(&fp_arguments[i]);
}
