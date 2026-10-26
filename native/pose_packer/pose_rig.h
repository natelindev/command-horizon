/* Resident articulated transforms. Part views expose the existing transform
 * interface without SceneTree writes or script transform proxies. Each worker
 * owns a disjoint rig until the join. Engine nodes are retained only by the
 * script coordinator for explicit materialization and visibility checks. */
typedef struct {
    IpT local, world;
    int parent;
    uint64_t local_revision, seen_local, world_revision, seen_parent, view;
} RpPose;
typedef struct {
    int kind;
    uint64_t owner, revision, world_clock, writes, updates, packed, views;
    RpPose *poses;
    int count, capacity, *anchors, anchor_count;
} RpRig;
typedef struct {
    int kind;
    RpRig *rig;
    int index;
    Value owner;
    uint64_t id;
} RpPart;
enum { RP_RIG = 1001, RP_PART = 1002 };
static Value rp_classes[2], rp_fields[8], rp_rig_methods[6], rp_part_methods[2], rp_arguments[4],
    rp_key;
static GDExtensionInterfaceObjectGetInstanceBinding rp_get_binding;
static GDExtensionInterfaceObjectSetInstanceBinding rp_set_binding;
static GDExtensionInterfaceObjectGetInstanceId rp_object_id;
static GDExtensionInterfaceVariantGetPtrOperatorEvaluator rp_evaluator;
static GDExtensionPtrOperatorEvaluator rp_equal;
static GDExtensionPtrBuiltInMethod rp_orthonormalized, rp_euler, rp_from_euler, rp_scale;
static int rp_initialized, rp_registered;
static void *rp_binding_create(void *token, void *owner) {
    (void)token;
    (void)owner;
    return 0;
}
static void rp_binding_free(void *token, void *owner, void *binding) {
    (void)token;
    (void)owner;
    (void)binding;
}
static GDExtensionBool rp_binding_reference(void *token, void *binding, GDExtensionBool reference) {
    (void)token;
    (void)binding;
    (void)reference;
    return 1;
}
static GDExtensionInstanceBindingCallbacks rp_callbacks = {rp_binding_create, rp_binding_free,
                                                           rp_binding_reference};
static IpT rp_identity(void) { return (IpT){(IpB){{1, 0, 0, 0, 1, 0, 0, 0, 1}}, (IpV){0, 0, 0}}; }
static IpT rp_multiply(IpT a, IpT b) { return (IpT){ipmul(a.b, b.b), ipa(ipxform(a.b, b.p), a.p)}; }
static void rp_worlds(RpRig *r, int last) {
    for (int i = 0; i <= last; i++) {
        RpPose *p = &r->poses[i];
        uint64_t parent = p->parent >= 0 ? r->poses[p->parent].world_revision : 0;
        if (p->seen_local != p->local_revision || p->seen_parent != parent) {
            p->world = p->parent >= 0 ? rp_multiply(r->poses[p->parent].world, p->local) : p->local;
            p->seen_local = p->local_revision;
            p->seen_parent = parent;
            p->world_revision = ++r->world_clock;
            r->updates++;
        }
    }
}
static void *rp_view(RpRig *r, int index);
static int rp_field(const void *name) {
    for (int i = 0; i < 8; i++) {
        GDExtensionBool same = 0;
        rp_equal(name, &rp_fields[i], &same);
        if (same)
            return i;
    }
    return -1;
}
static GDExtensionBool rp_get(void *instance, const void *name, void *ret) {
    RpPart *part = instance;
    int field = rp_field(name);
    if (field < 0)
        return 0;
    RpRig *r = part->rig;
    int valid = r && part->index >= 0 && part->index < r->count;
    IpT identity = rp_identity(), *t = valid ? &r->poses[part->index].local : &identity;
    variant_destroy(ret);
    if (field == 0)
        from_type(TYPE(TRANSFORM3D))(ret, t);
    else if (field == 1)
        from_type(TYPE(VECTOR3))(ret, &t->p);
    else if (field == 2)
        from_type(TYPE(BASIS))(ret, &t->b);
    else if (field == 3) {
        IpB normal;
        rp_orthonormalized(&t->b, 0, &normal, 0);
        float *a = normal.v;
        float determinant = a[0] * (a[4] * a[8] - a[5] * a[7]) -
                            a[1] * (a[3] * a[8] - a[5] * a[6]) + a[2] * (a[3] * a[7] - a[4] * a[6]);
        if (determinant < 0)
            for (int i = 0; i < 9; i++)
                normal.v[i] = -normal.v[i];
        int64_t order = 2;
        const void *args[] = {&order};
        IpV rotation;
        rp_euler(&normal, args, &rotation, 1);
        from_type(TYPE(VECTOR3))(ret, &rotation);
    } else if (field == 4) {
        IpV scale;
        rp_scale(&t->b, 0, &scale, 0);
        from_type(TYPE(VECTOR3))(ret, &scale);
    } else if (field == 5) {
        if (valid) {
            rp_worlds(r, part->index);
            from_type(TYPE(TRANSFORM3D))(ret, &r->poses[part->index].world);
        } else
            from_type(TYPE(TRANSFORM3D))(ret, &identity);
    } else if (field == 6) {
        int64_t index = valid ? part->index : -1;
        from_type(TYPE(INT))(ret, &index);
    } else {
        void *parent = valid ? rp_view(r, r->poses[part->index].parent) : 0;
        from_type(TYPE(OBJECT))(ret, &parent);
    }
    return 1;
}
static GDExtensionBool rp_set(void *instance, const void *name, const void *value) {
    RpPart *part = instance;
    RpRig *r = part->rig;
    int field = rp_field(name);
    if (!r || part->index < 0 || part->index >= r->count)
        return 0;
    IpT *t = &r->poses[part->index].local;
    if (field == 0 && get_type(value) == TYPE(TRANSFORM3D))
        to_type(TYPE(TRANSFORM3D))(t, (void *)value);
    else if (field == 1 && get_type(value) == TYPE(VECTOR3))
        to_type(TYPE(VECTOR3))(&t->p, (void *)value);
    else if (field == 2 && get_type(value) == TYPE(BASIS))
        to_type(TYPE(BASIS))(&t->b, (void *)value);
    else if (field == 3 && get_type(value) == TYPE(VECTOR3)) {
        IpV rotation, scale;
        to_type(TYPE(VECTOR3))(&rotation, (void *)value);
        rp_scale(&t->b, 0, &scale, 0);
        int64_t order = 2;
        const void *args[] = {&rotation, &order};
        rp_from_euler(0, args, &t->b, 2);
        float factors[] = {scale.x, scale.y, scale.z};
        for (int y = 0; y < 3; y++)
            for (int x = 0; x < 3; x++)
                t->b.v[y * 3 + x] *= factors[x];
    } else
        return 0;
    r->poses[part->index].local_revision = ++r->revision;
    r->writes++;
    return 1;
}
static GDExtensionObjectPtr rp_create(void *userdata, GDExtensionBool notify) {
    (void)notify;
    int part = (int)(intptr_t)userdata;
    void *state;
    if (part) {
        RpPart *p = calloc(1, sizeof(RpPart));
        if (!p)
            return 0;
        p->kind = RP_PART;
        p->index = -1;
        variant_nil(&p->owner);
        state = p;
    } else {
        RpRig *r = calloc(1, sizeof(RpRig));
        if (!r)
            return 0;
        r->kind = RP_RIG;
        r->revision = 1;
        state = r;
    }
    void *owner = construct(&parent_name);
    if (!owner) {
        free(state);
        return 0;
    }
    set_instance(owner, &rp_classes[part], state);
    rp_set_binding(owner, library, state, &rp_callbacks);
    if (part)
        ((RpPart *)state)->id = rp_object_id(owner);
    else
        ((RpRig *)state)->owner = rp_object_id(owner);
    return owner;
}
static void rp_free(void *userdata, void *instance) {
    int part = (int)(intptr_t)userdata;
    if (part) {
        RpPart *p = instance;
        if (p->rig && p->index >= 0 && p->index < p->rig->count &&
            p->rig->poses[p->index].view == p->id)
            p->rig->poses[p->index].view = 0;
        variant_destroy(&p->owner);
        free(p);
    } else {
        RpRig *r = instance;
        free(r->poses);
        free(r->anchors);
        free(r);
    }
}
static void *rp_view(RpRig *r, int index) {
    if (index < 0 || index >= r->count)
        return 0;
    void *owner = object_from_id(r->poses[index].view);
    if (owner)
        return owner;
    owner = construct(&rp_classes[1]);
    if (!owner)
        return 0;
    RpPart *p = rp_get_binding(owner, library, &rp_callbacks);
    p->rig = r;
    p->index = index;
    void *rig = object_from_id(r->owner);
    variant_destroy(&p->owner);
    from_type(TYPE(OBJECT))(&p->owner, &rig);
    r->poses[index].view = rp_object_id(owner);
    r->views++;
    return owner;
}
static void rp_part_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                         GDExtensionInt count, void *ret, GDExtensionCallError *error) {
    RpPart *p = instance;
    int method = (int)(intptr_t)userdata;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (method == 0 && count == 0) {
        void *parent =
            p->rig && p->index >= 0 ? rp_view(p->rig, p->rig->poses[p->index].parent) : 0;
        from_type(TYPE(OBJECT))(ret, &parent);
    } else if (method == 1 && count == 1 && get_type(args[0]) == TYPE(VECTOR3) && p->rig &&
               p->index >= 0) {
        rp_worlds(p->rig, p->index);
        IpT t = p->rig->poses[p->index].world;
        IpV point;
        to_type(TYPE(VECTOR3))(&point, (void *)args[0]);
        point = ipxform(ipinv(t.b), ips(point, t.p));
        from_type(TYPE(VECTOR3))(ret, &point);
    } else {
        variant_nil(ret);
        return;
    }
    error->error = GDEXTENSION_CALL_OK;
}
static void rp_rig_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                        GDExtensionInt count, void *ret, GDExtensionCallError *error) {
    RpRig *r = instance;
    int method = (int)(intptr_t)userdata;
    variant_nil(ret);
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (method == 0 && count == 2 && get_type(args[0]) == TYPE(INT) &&
        get_type(args[1]) == TYPE(TRANSFORM3D)) {
        int64_t parent;
        to_type(TYPE(INT))(&parent, (void *)args[0]);
        if (parent < -1 || parent >= r->count || r->count >= 4096)
            return;
        if (r->count == r->capacity) {
            int capacity = r->capacity ? r->capacity * 2 : 16;
            RpPose *poses = realloc(r->poses, (size_t)capacity * sizeof(RpPose));
            if (!poses)
                return;
            r->poses = poses;
            r->capacity = capacity;
        }
        int index = r->count++;
        RpPose *p = &r->poses[index];
        memset(p, 0, sizeof(*p));
        p->parent = (int)parent;
        p->local_revision = ++r->revision;
        to_type(TYPE(TRANSFORM3D))(&p->local, (void *)args[1]);
        void *view = rp_view(r, index);
        variant_destroy(ret);
        from_type(TYPE(OBJECT))(ret, &view);
    } else if (method == 1 && count == 1 && get_type(args[0]) == TYPE(PACKED_INT32_ARRAY)) {
        Value indices;
        to_type(TYPE(PACKED_INT32_ARRAY))(&indices, (void *)args[0]);
        int64_t n = 0;
        ints_size(&indices, 0, &n, 0);
        GDExtensionBool valid = n >= 0 && n <= 4096;
        const int32_t *p = n ? ints_index(&indices, 0) : 0;
        for (int i = 0; valid && i < n; i++)
            valid = p[i] >= 0 && p[i] < r->count;
        int *copy = valid && n ? malloc((size_t)n * sizeof(int)) : 0;
        if (valid && n && !copy)
            valid = 0;
        if (valid) {
            if (n)
                memcpy(copy, p, (size_t)n * sizeof(int));
            free(r->anchors);
            r->anchors = copy;
            r->anchor_count = (int)n;
        }
        get_dtor(TYPE(PACKED_INT32_ARRAY))(&indices);
        variant_destroy(ret);
        from_type(TYPE(BOOL))(ret, &valid);
    } else if (method == 2 && count == 1 && get_type(args[0]) == TYPE(ARRAY)) {
        Value palette;
        to_type(TYPE(ARRAY))(&palette, (void *)args[0]);
        rp_worlds(r, r->count - 1);
        int64_t n = count_array(&palette);
        if (n >= r->anchor_count)
            for (int i = 0; i < r->anchor_count; i++) {
                void *out = array_write(&palette, i);
                variant_destroy(out);
                from_type(TYPE(TRANSFORM3D))(out, &r->poses[r->anchors[i]].world);
            }
        get_dtor(TYPE(ARRAY))(&palette);
    } else if (method == 3 && count == 0)
        rp_worlds(r, r->count - 1);
    else if (method == 4 && count == 1 && get_type(args[0]) == TYPE(INT)) {
        int64_t index;
        to_type(TYPE(INT))(&index, (void *)args[0]);
        IpT t = rp_identity();
        if (index >= 0 && index < r->count) {
            rp_worlds(r, (int)index);
            t = r->poses[index].world;
        }
        variant_destroy(ret);
        from_type(TYPE(TRANSFORM3D))(ret, &t);
    } else if (method == 5 && count == 0) {
        uint64_t values[] = {(uint64_t)r->count, r->writes, r->updates, r->packed, r->views};
        variant_destroy(ret);
        profile_array(values, 5, ret);
    } else
        return;
    error->error = GDEXTENSION_CALL_OK;
}
static void *resident_rig_for_entry(const void *entry) {
    if (!rp_registered)
        return 0;
    void *value = dictionary_lookup(entry, &rp_key);
    if (!value || get_type(value) != TYPE(OBJECT))
        return 0;
    void *owner = object_from_id(object_id(value));
    if (!owner)
        return 0;
    RpRig *r = rp_get_binding(owner, library, 0);
    if (!r || r->kind != RP_RIG)
        return 0;
    rp_worlds(r, r->count - 1);
    return r;
}
static int resident_rig_pose(void *state, int index, float *transform) {
    RpRig *r = state;
    if (index < 0 || index >= r->anchor_count)
        return 0;
    memcpy(transform, &r->poses[r->anchors[index]].world, sizeof(IpT));
    r->packed++;
    return 1;
}
static int pose_rig_load(GDExtensionInterfaceGetProcAddress proc) {
    rp_get_binding =
        (GDExtensionInterfaceObjectGetInstanceBinding)proc("object_get_instance_binding");
    rp_set_binding =
        (GDExtensionInterfaceObjectSetInstanceBinding)proc("object_set_instance_binding");
    rp_object_id = (GDExtensionInterfaceObjectGetInstanceId)proc("object_get_instance_id");
    rp_evaluator = (GDExtensionInterfaceVariantGetPtrOperatorEvaluator)proc(
        "variant_get_ptr_operator_evaluator");
    return rp_get_binding && rp_set_binding && rp_object_id && rp_evaluator;
}
static void pose_rig_initialize(void) {
    name_new(&rp_classes[0], "CopperfinPoseRig");
    name_new(&rp_classes[1], "CopperfinPosePart");
    const char *fields[] = {"transform", "position",         "basis", "rotation",
                            "scale",     "global_transform", "index", "parent"};
    const char *methods[] = {"add_part",     "configure_anchors", "solve_palette",
                             "solve_worlds", "global_pose",       "statistics"};
    const char *parts[] = {"get_parent", "to_local"};
    const char *arguments[] = {"parent", "transform", "anchors", "palette"};
    for (int i = 0; i < 8; i++)
        name_new(&rp_fields[i], fields[i]);
    for (int i = 0; i < 6; i++)
        name_new(&rp_rig_methods[i], methods[i]);
    for (int i = 0; i < 2; i++)
        name_new(&rp_part_methods[i], parts[i]);
    for (int i = 0; i < 4; i++)
        name_new(&rp_arguments[i], arguments[i]);
    Value text;
    string_new(&text, "native_rig");
    from_type(TYPE(STRING))(&rp_key, &text);
    get_dtor(TYPE(STRING))(&text);
    rp_initialized = 1;
    rp_equal = rp_evaluator(GDEXTENSION_VARIANT_OP_EQUAL, TYPE(STRING_NAME), TYPE(STRING_NAME));
    const char *math[] = {"orthonormalized", "get_euler", "from_euler", "get_scale"};
    uint64_t hashes[] = {594669093, 1394941017, 2802321791, 1776574132};
    GDExtensionPtrBuiltInMethod *functions[] = {&rp_orthonormalized, &rp_euler, &rp_from_euler,
                                                &rp_scale};
    for (int i = 0; i < 4; i++) {
        Value name;
        name_new(&name, math[i]);
        *functions[i] = get_builtin(TYPE(BASIS), &name, hashes[i]);
        get_dtor(TYPE(STRING_NAME))(&name);
        if (!*functions[i])
            return;
    }
    if (!rp_equal)
        return;
    for (int part = 0; part < 2; part++) {
        GDExtensionClassCreationInfo4 info = {0};
        info.is_exposed = 1;
        info.class_userdata = (void *)(intptr_t)part;
        info.create_instance_func = rp_create;
        info.free_instance_func = rp_free;
        if (part) {
            info.get_func = rp_get;
            info.set_func = rp_set;
        }
        register_class(library, &rp_classes[part], &parent_name, &info);
    }
    rp_registered = 1;
    const int counts[] = {2, 1, 1, 0, 1, 0};
    const GDExtensionVariantType types[6][2] = {{TYPE(INT), TYPE(TRANSFORM3D)},
                                                {TYPE(PACKED_INT32_ARRAY)},
                                                {TYPE(ARRAY)},
                                                {},
                                                {TYPE(INT)},
                                                {}};
    const GDExtensionVariantType outputs[] = {TYPE(OBJECT), TYPE(BOOL),        TYPE(NIL),
                                              TYPE(NIL),    TYPE(TRANSFORM3D), TYPE(ARRAY)};
    const int names[6][2] = {{0, 1}, {2}, {3}, {}, {0}, {}};
    for (int i = 0; i < 6; i++) {
        GDExtensionPropertyInfo parameters[2];
        GDExtensionClassMethodArgumentMetadata metadata[2] = {0};
        for (int j = 0; j < counts[i]; j++)
            parameters[j] = (GDExtensionPropertyInfo){
                types[i][j], &rp_arguments[names[i][j]], &empty_name, 0, &empty_string, 6};
        GDExtensionPropertyInfo output = {outputs[i], &empty_name,   &empty_name,
                                          0,          &empty_string, 6};
        GDExtensionClassMethodInfo method = {0};
        method.name = &rp_rig_methods[i];
        method.method_userdata = (void *)(intptr_t)i;
        method.call_func = rp_rig_call;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.argument_count = counts[i];
        method.arguments_info = parameters;
        method.arguments_metadata = metadata;
        method.has_return_value = outputs[i] != TYPE(NIL);
        method.return_value_info = method.has_return_value ? &output : 0;
        register_method(library, &rp_classes[0], &method);
    }
    for (int i = 0; i < 2; i++) {
        GDExtensionPropertyInfo parameter = {
            TYPE(VECTOR3), &rp_fields[1], &empty_name, 0, &empty_string, 6};
        GDExtensionClassMethodArgumentMetadata metadata = 0;
        GDExtensionPropertyInfo output = {
            i ? TYPE(VECTOR3) : TYPE(OBJECT), &empty_name, &empty_name, 0, &empty_string, 6};
        GDExtensionClassMethodInfo method = {0};
        method.name = &rp_part_methods[i];
        method.method_userdata = (void *)(intptr_t)i;
        method.call_func = rp_part_call;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.argument_count = i;
        method.arguments_info = i ? &parameter : 0;
        method.arguments_metadata = i ? &metadata : 0;
        method.has_return_value = 1;
        method.return_value_info = &output;
        register_method(library, &rp_classes[1], &method);
    }
}
static void pose_rig_deinitialize(void) {
    if (!rp_initialized)
        return;
    if (rp_registered) {
        unregister_class(library, &rp_classes[1]);
        unregister_class(library, &rp_classes[0]);
    }
    rp_registered = 0;
    for (int i = 0; i < 2; i++) {
        get_dtor(TYPE(STRING_NAME))(&rp_classes[i]);
        get_dtor(TYPE(STRING_NAME))(&rp_part_methods[i]);
    }
    for (int i = 0; i < 8; i++)
        get_dtor(TYPE(STRING_NAME))(&rp_fields[i]);
    for (int i = 0; i < 6; i++)
        get_dtor(TYPE(STRING_NAME))(&rp_rig_methods[i]);
    for (int i = 0; i < 4; i++)
        get_dtor(TYPE(STRING_NAME))(&rp_arguments[i]);
    variant_destroy(&rp_key);
    rp_initialized = 0;
}
