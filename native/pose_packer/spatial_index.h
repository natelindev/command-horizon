/* Build the same ordered grids as Battlefield's script fallback. Scene reads
 * stay on the caller/main thread; output dictionaries own all array storage. */
static Value index_method, index_arguments[2], index_fields[5], index_effective;
static Value index_group_method, index_node_class, index_units_group, index_meta_name;
static Value index_meta_method, index_meta_key;
static GDExtensionInterfaceDictionaryOperatorIndex index_dictionary_write;
static GDExtensionMethodBindPtr index_in_group, index_has_meta, index_has_method;
static int index_initialized;

static int index_number(const void *value, double *result) {
    if (get_type(value) == TYPE(FLOAT)) to_type(TYPE(FLOAT))(result, (void *)value);
    else if (get_type(value) == TYPE(INT)) {
        int64_t integer;
        to_type(TYPE(INT))(&integer, (void *)value);
        *result = (double)integer;
    } else return 0;
    return isfinite(*result);
}

static int index_field_number(const void *object, const Value *name, double *result) {
    void *node = get_type(object) == TYPE(OBJECT) ? object_from_id(object_id(object)) : 0;
    if (name == &index_fields[2] && native_unit_radius(node, result))
        return isfinite(*result);
    if (name == &index_fields[3] && native_unit_speed(node, result))
        return isfinite(*result);
    Value value;
    GDExtensionBool valid = 0;
    get_named(object, name, &value, &valid);
    int success = valid && index_number(&value, result);
    variant_destroy(&value);
    return success;
}

static void index_store_dictionary(void *dictionary, const void *key, const void *value) {
    void *slot = index_dictionary_write(dictionary, key);
    variant_destroy(slot);
    from_type(TYPE(DICTIONARY))(slot, (void *)value);
}

static void index_append_cell(void *dictionary, const float *position, double size, const void *unit) {
    int32_t coordinates[] = {(int32_t)floor((double)position[0] / size),
                              (int32_t)floor((double)position[2] / size)};
    Value key, array;
    from_type(TYPE(VECTOR2I))(&key, coordinates);
    void *existing = dictionary_lookup(dictionary, &key);
    if (existing) to_type(TYPE(ARRAY))(&array, existing);
    else {
        get_ctor(TYPE(ARRAY), 0)(&array, 0);
        void *slot = index_dictionary_write(dictionary, &key);
        variant_destroy(slot);
        from_type(TYPE(ARRAY))(slot, &array);
    }
    const void *arguments[] = {unit};
    array_append(&array, arguments, 0, 1);
    get_dtor(TYPE(ARRAY))(&array);
    variant_destroy(&key);
}

static int index_observer(const void *unit, double delta, Value *grids, double *maxima) {
    if (get_type(unit) != TYPE(OBJECT)) return 1;
    void *node = object_from_id(object_id(unit));
    if (!node || !object_cast(node, node_tag)) return 1;
    GDExtensionBool queued = 0;
    ptrcall(queued_for_deletion, node, 0, &queued);
    if (queued) return 1;
    Value sight, owner;
    GDExtensionBool valid = 0;
    double resident_sight = 0;
    int resident_present = 0;
    if (native_unit_scalar(node, US_SIGHT, &resident_sight, &resident_present)) {
        if (resident_present)
            from_type(TYPE(FLOAT))(&sight, &resident_sight);
        else
            variant_nil(&sight);
        valid = 1;
    } else
        get_named(unit, &index_fields[0], &sight, &valid);
    if (!valid || get_type(&sight) == TYPE(NIL)) { variant_destroy(&sight); return 1; }
    double reach = 0;
    int numeric = index_number(&sight, &reach);
    variant_destroy(&sight);
    if (!numeric) return 0;
    get_named(unit, &index_fields[1], &owner, &valid);
    if (!valid || get_type(&owner) != TYPE(OBJECT) || !object_from_id(object_id(&owner))) {
        variant_destroy(&owner); return 1;
    }
    GDExtensionCallError error = {0};
    GDExtensionBool has_effective = 0;
    const void *effective_arguments[] = {&index_effective};
    ptrcall(index_has_method, node, effective_arguments, &has_effective);
    if (has_effective) {
        Value effective;
        variant_call((void *)unit, &index_effective, 0, 0, &effective, &error);
        numeric = error.error == GDEXTENSION_CALL_OK && index_number(&effective, &reach);
        variant_destroy(&effective);
    }
    if (!numeric) { variant_destroy(&owner); return 0; }
    node = object_from_id(object_id(unit));
    if (!node) { variant_destroy(&owner); return 1; }
    GDExtensionBool garrisoned = 0;
    const void *meta_arguments[] = {&index_meta_name};
    ptrcall(index_has_meta, node, meta_arguments, &garrisoned);
    if (garrisoned) {
        Value host;
        const void *arguments[] = {&index_meta_key};
        variant_call((void *)unit, &index_meta_method, arguments, 1, &host, &error);
        double radius = 0;
        if (error.error == GDEXTENSION_CALL_OK && index_field_number(&host, &index_fields[2], &radius)) reach += radius + 2.0;
        else numeric = 0;
        variant_destroy(&host);
    }
    if (!numeric) { variant_destroy(&owner); return 0; }
    node = object_from_id(object_id(unit));
    if (!node) { variant_destroy(&owner); return 1; }
    float transform[12];
    ptrcall(global_transform, node, 0, transform);
    const float *position = transform + 9;
    if (!isfinite(position[0]) || !isfinite(position[2]) || fabs(position[0]) > 1000000000 || fabs(position[2]) > 1000000000) {
        variant_destroy(&owner); return 0;
    }
    Value team, cells;
    get_named(&owner, &index_fields[4], &team, &valid);
    double team_number = -1;
    int teamed = valid && index_number(&team, &team_number) && team_number >= 0;
    const void *key = teamed ? (const void *)&team : (const void *)&owner;
    void *existing = dictionary_lookup(&grids[0], key);
    if (existing) to_type(TYPE(DICTIONARY))(&cells, existing);
    else {
        get_ctor(TYPE(DICTIONARY), 0)(&cells, 0);
        index_store_dictionary(&grids[0], key, &cells);
    }
    index_append_cell(&cells, position, 12.0, unit);
    get_dtor(TYPE(DICTIONARY))(&cells);
    variant_destroy(&team);
    variant_destroy(&owner);
    maxima[0] = fmax(maxima[0], reach);
    GDExtensionBool body = 0;
    const void *group_arguments[] = {&index_units_group};
    ptrcall(index_in_group, node, group_arguments, &body);
    if (body) {
        double radius = 0, speed = 0;
        if (!index_field_number(unit, &index_fields[2], &radius) ||
            !index_field_number(unit, &index_fields[3], &speed)) return 0;
        maxima[1] = fmax(maxima[1], radius);
        maxima[2] = fmax(maxima[2], speed * delta);
        index_append_cell(&grids[1], position, 3.0, unit);
        index_append_cell(&grids[2], position, 12.0, unit);
    }
    return 1;
}

static void spatial_index_core(const void *units, double delta, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    if (!isfinite(delta) || delta < 0) return;
    Value grids[3];
    double maxima[3] = {0};
    int success = 1;
    for (int i = 0; i < 3; ++i) get_ctor(TYPE(DICTIONARY), 0)(&grids[i], 0);
    int64_t count = count_array((void *)units);
    for (int64_t i = 0; i < count; ++i) {
        if (!index_observer(array_index(units, i), delta, grids, maxima)) { success = 0; break; }
    }
    if (success) {
        for (int i = 0; i < 6; ++i) {
            Value value;
            if (i < 3) from_type(TYPE(DICTIONARY))(&value, &grids[i]);
            else from_type(TYPE(FLOAT))(&value, &maxima[i - 3]);
            const void *arguments[] = {&value};
            array_append(output, arguments, 0, 1);
            variant_destroy(&value);
        }
    }
    for (int i = 0; i < 3; ++i) get_dtor(TYPE(DICTIONARY))(&grids[i]);
}

static void spatial_index_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                               GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 2 || get_type(args[0]) != TYPE(ARRAY) || get_type(args[1]) != TYPE(FLOAT)) { variant_nil(ret); return; }
    Value units, output; double delta;
    to_type(TYPE(ARRAY))(&units, (void *)args[0]);
    to_type(TYPE(FLOAT))(&delta, (void *)args[1]);
    spatial_index_core(&units, delta, &output);
    from_type(TYPE(ARRAY))(ret, &output);
    get_dtor(TYPE(ARRAY))(&units);
    get_dtor(TYPE(ARRAY))(&output);
    error->error = GDEXTENSION_CALL_OK;
}

static void spatial_index_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    spatial_index_core(args[0], *(const double *)args[1], ret);
}

static int spatial_index_load(GDExtensionInterfaceGetProcAddress proc) {
    index_dictionary_write = (GDExtensionInterfaceDictionaryOperatorIndex)proc("dictionary_operator_index");
    return index_dictionary_write != 0;
}

static void spatial_index_initialize(void) {
    name_new(&index_method, "index_observers");
    name_new(&index_arguments[0], "observers"); name_new(&index_arguments[1], "delta");
    const char *fields[] = {"sight_range", "player", "radius", "movement_speed", "team"};
    for (int i = 0; i < 5; ++i) name_new(&index_fields[i], fields[i]);
    name_new(&index_effective, "effective_sight_range");
    name_new(&index_group_method, "is_in_group"); name_new(&index_node_class, "Node");
    name_new(&index_units_group, "units"); name_new(&index_meta_name, "garrison_host");
    name_new(&index_meta_method, "get_meta");
    from_type(TYPE(STRING_NAME))(&index_meta_key, &index_meta_name);
    Value has_meta;
    name_new(&has_meta, "has_meta");
    index_has_meta = method_bind(&object_name, &has_meta, 2619796661LL);
    get_dtor(TYPE(STRING_NAME))(&has_meta);
    name_new(&has_meta, "has_method");
    index_has_method = method_bind(&object_name, &has_meta, 2619796661LL);
    get_dtor(TYPE(STRING_NAME))(&has_meta);
    index_in_group = method_bind(&index_node_class, &index_group_method, 2619796661LL);
    index_initialized = 1;
    if (!index_has_meta || !index_has_method || !index_in_group) return;
    GDExtensionPropertyInfo output = {TYPE(ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo arguments[] = {
        {TYPE(ARRAY), &index_arguments[0], &empty_name, 0, &empty_string, 6},
        {TYPE(FLOAT), &index_arguments[1], &empty_name, 0, &empty_string, 6}
    };
    GDExtensionClassMethodArgumentMetadata metadata[] = {0, GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE};
    GDExtensionClassMethodInfo method = {0};
    method.name = &index_method; method.call_func = spatial_index_call; method.ptrcall_func = spatial_index_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL; method.has_return_value = 1; method.return_value_info = &output;
    method.argument_count = 2; method.arguments_info = arguments; method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
}

static void spatial_index_deinitialize(void) {
    if (!index_initialized) return;
    get_dtor(TYPE(STRING_NAME))(&index_method);
    for (int i = 0; i < 2; ++i) get_dtor(TYPE(STRING_NAME))(&index_arguments[i]);
    for (int i = 0; i < 5; ++i) get_dtor(TYPE(STRING_NAME))(&index_fields[i]);
    get_dtor(TYPE(STRING_NAME))(&index_effective); get_dtor(TYPE(STRING_NAME))(&index_group_method);
    get_dtor(TYPE(STRING_NAME))(&index_node_class); get_dtor(TYPE(STRING_NAME))(&index_units_group);
    get_dtor(TYPE(STRING_NAME))(&index_meta_name); get_dtor(TYPE(STRING_NAME))(&index_meta_method);
    variant_destroy(&index_meta_key);
    index_initialized = 0;
}
