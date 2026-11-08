/* Resident presentation coordination. Main-thread node reads, owned rig refs,
 * weak scene IDs, and no scene/dictionary traversal for individual palette rows.
 * Simulation roots are captured before each physics tick, not each draw. */
#include <float.h>
#define PB_LIMIT 2048
typedef struct {
    uint32_t generation;
    int live, offset, count, cell_x, cell_z, first, scene_geometry;
    uint64_t unit, geometry, owner, pulse, visual, worker, *anchors;
    Value rig_owner;
    RpRig *rig;
    IpT physics, sampled, geometry_pose;
    IpV previous;
    float radius, low, high;
    double elapsed, step_delta;
    int pose_stage;
    float *track_travel;
} PbSlot;
typedef struct {
    PbSlot *slots;
    int high_water, live, capacity;
    int order[PB_LIMIT], order_count, frame_count;
    int64_t frame[PB_LIMIT];
    Value last;
    uint64_t statistics[7]; /* bound, captures, roots, packs, parts, checks, changes */
} PbBatch;
static Value pb_class, pb_methods[16], pb_args[15], pb_pulse_names[2], pb_pose_names[7];
static GDExtensionMethodBindPtr pb_parent, pb_shader_parameter;
static void *pb_shader_tag;
static GDExtensionPtrBuiltInMethod pb_inverse, pb_linear;
static int pb_initialized, pb_registered;

static int64_t pb_handle(PbBatch *b, PbSlot *s) {
    return ((int64_t)s->generation << 14) | (s - b->slots);
}
static PbSlot *pb_slot(PbBatch *b, int64_t handle) {
    int index = (int)(handle & 16383);
    if (index >= b->high_water || handle < 0)
        return 0;
    PbSlot *s = &b->slots[index];
    return s->live && s->generation == (uint32_t)(handle >> 14) ? s : 0;
}
static void pb_release(PbBatch *b, PbSlot *s) {
    if (!s->live)
        return;
    variant_destroy(&s->rig_owner);
    free(s->anchors);
    free(s->track_travel);
    s->track_travel = 0;
    s->anchors = 0;
    s->live = 0;
    b->live--;
    for (int i = 0; i < b->order_count; i++)
        if (b->order[i] == s - b->slots) {
            memmove(b->order + i, b->order + i + 1,
                    sizeof(int) * (size_t)(--b->order_count - i));
            break;
        }
}
static void pb_append(void *array, int64_t n) {
    Value value;
    from_type(TYPE(INT))(&value, &n);
    array_append(array, (const void *[]){&value}, 0, 1);
    variant_destroy(&value);
}
static void pb_resize(void *bytes, int capacity) {
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 0)(bytes, 0);
    int64_t length = (int64_t)capacity * 64, result;
    bytes_resize(bytes, (const void *[]){&length}, &result, 1);
    if (length)
        memset(bytes_index(bytes, 0), 0, (size_t)length);
}
static void pb_identity_row(float *pixels) { pixels[0] = pixels[5] = pixels[10] = 1; }
static void pb_publish_root(PbSlot *s, void *geometry, IpT root) {
    IpT posed = rp_multiply(root, s->geometry_pose);
    if (s->scene_geometry) {
        IpT shown;
        ptrcall(global_transform, geometry, 0, &shown);
        if (memcmp(&shown, &posed, sizeof(IpT)))
            ptrcall(cr_bind[CR_SET_TRANSFORM], geometry, (const void *[]){&posed}, 0);
    }
    if (s->rig->count > 0 && memcmp(&s->rig->poses[0].local, &posed, sizeof(IpT))) {
        s->rig->poses[0].local = posed;
        s->rig->poses[0].local_revision = ++s->rig->revision;
        s->rig->writes++;
    }
}
static int64_t pb_bind(PbBatch *b, void *unit, void *geometry, const void *anchors, void *rig_owner,
                       int64_t offset, double radius) {
    if (!b->capacity || !unit || !geometry || !rig_owner || !object_cast(unit, node_tag) ||
        !object_cast(geometry, node_tag) || !isfinite(radius) || radius < 0)
        return -1;
    RpRig *rig = rp_get_binding(rig_owner, library, 0);
    int64_t count = count_array((void *)anchors);
    if (!rig || rig->kind != RP_RIG || count <= 0 || count != rig->anchor_count || offset < 1 ||
        offset > b->capacity - count)
        return -1;
    int index = -1;
    for (int i = 0; i < b->high_water; i++) {
        PbSlot *s = &b->slots[i];
        if (!s->live) {
            if (index < 0)
                index = i;
            continue;
        }
        if (s->unit == rp_object_id(unit) ||
            (offset < s->offset + s->count && s->offset < offset + count))
            return -1;
    }
    if (index < 0) {
        if (b->high_water >= PB_LIMIT)
            return -1;
        index = b->high_water++;
    }
    uint64_t *ids = calloc((size_t)count, sizeof(uint64_t));
    if (!ids)
        return -1;
    for (int i = 0; i < count; i++) {
        const void *v = array_index(anchors, i);
        void *node = get_type(v) == TYPE(OBJECT) ? object_from_id(object_id(v)) : 0;
        if (!node || !object_cast(node, node_tag)) {
            free(ids);
            return -1;
        }
        ids[i] = rp_object_id(node);
    }
    PbSlot *s = &b->slots[index];
    uint32_t generation = s->generation + 1;
    if (!generation)
        generation = 1;
    memset(s, 0, sizeof(*s));
    s->generation = generation;
    s->live = 1;
    s->offset = (int)offset;
    s->count = (int)count;
    s->anchors = ids;
    s->track_travel = malloc((size_t)count * sizeof(float));
    if (!s->track_travel) {
        free(ids);
        s->anchors = 0;
        s->live = 0;
        return -1;
    }
    for (int part = 0; part < count; part++)
        s->track_travel[part] = NAN;
    s->unit = rp_object_id(unit);
    s->geometry = rp_object_id(geometry);
    void *parent = 0;
    ptrcall(pb_parent, unit, 0, &parent);
    s->owner = parent ? rp_object_id(parent) : 0;
    s->rig = rig;
    cr_variant(rig_owner, &s->rig_owner);
    ptrcall(global_transform, unit, 0, &s->physics);
    s->sampled = s->physics;
    s->geometry_pose = rp_identity();
    s->first = 1;
    s->radius = (float)radius;
    s->cell_x = (int)floor(s->physics.p.x / 24);
    s->cell_z = (int)floor(s->physics.p.z / 24);
    s->low = s->physics.p.y - s->radius - 1;
    s->high = s->physics.p.y + s->radius + 1;
    b->live++;
    b->order[b->order_count++] = index;
    return pb_handle(b, s);
}
/* The same script animation/effect callbacks run in insertion order. Only the
 * coordinator is native: elapsed state and weak bindings stay resident instead
 * of crossing several script/dictionary/property boundaries per unit. Snapshot
 * generation handles protect every phase against deletion/rebinding callbacks. */
static Value pb_pose_call(uint64_t id, int method, const void **args, int count) {
    Value result;
    void *object = object_from_id(id);
    if (!object) {
        variant_nil(&result);
        return result;
    }
    Value value;
    cr_variant(object, &value);
    GDExtensionCallError error = {0};
    variant_call(&value, &pb_pose_names[method], args, count, &result, &error);
    variant_destroy(&value);
    return result;
}
static void pb_prepare(PbBatch *b, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    b->frame_count = b->order_count;
    for (int i = 0; i < b->frame_count; i++)
        b->frame[i] = pb_handle(b, &b->slots[b->order[i]]);
    for (int i = 0; i < b->frame_count; i++) {
        int64_t handle = b->frame[i];
        PbSlot *s = pb_slot(b, handle);
        if (!s || !object_from_id(s->visual))
            continue;
        s->step_delta = s->elapsed;
        s->elapsed = 0;
        s->pose_stage = 1;
        Value delta;
        from_type(TYPE(FLOAT))(&delta, &s->step_delta);
        Value job = pb_pose_call(s->visual, 0, (const void *[]){&delta}, 1);
        if (pb_slot(b, handle) && get_type(&job) == TYPE(OBJECT))
            array_append(output, (const void *[]){&job}, 0, 1);
        variant_destroy(&job);
        variant_destroy(&delta);
    }
}
static void pb_finish(PbBatch *b, int workers, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    for (int i = 0; i < b->frame_count; i++) {
        int64_t handle = b->frame[i];
        PbSlot *s = pb_slot(b, handle);
        if (!s || s->pose_stage != 1 || !object_from_id(s->visual))
            continue;
        s->pose_stage = 2;
        if (workers && s->worker) {
            Value result = pb_pose_call(s->worker, 3, 0, 0);
            variant_destroy(&result);
        }
        s = pb_slot(b, handle);
        if (!s)
            continue;
        Value delta, finalize;
        GDExtensionBool no = 0;
        from_type(TYPE(FLOAT))(&delta, &s->step_delta);
        from_type(TYPE(BOOL))(&finalize, &no);
        Value result = pb_pose_call(s->visual, 1, (const void *[]){&delta, &finalize}, 2);
        variant_destroy(&result);
        variant_destroy(&delta);
        variant_destroy(&finalize);
        s = pb_slot(b, handle);
        void *worker = s && workers ? object_from_id(s->worker) : 0;
        if (!worker)
            continue;
        Value value, job, pending;
        cr_variant(worker, &value);
        GDExtensionBool valid = 0, ready = 0;
        get_named(&value, &pb_pose_names[5], &job, &valid);
        if (valid && get_type(&job) == TYPE(OBJECT)) {
            get_named(&job, &pb_pose_names[6], &pending, &valid);
            if (valid && get_type(&pending) == TYPE(BOOL))
                to_type(TYPE(BOOL))(&ready, &pending);
            variant_destroy(&pending);
        }
        if (ready)
            array_append(output, (const void *[]){&job}, 0, 1);
        variant_destroy(&job);
        variant_destroy(&value);
    }
}
static void pb_publish(PbBatch *b) {
    for (int i = 0; i < b->frame_count; i++) {
        int64_t handle = b->frame[i];
        PbSlot *s = pb_slot(b, handle);
        if (!s || s->pose_stage != 2 || !object_from_id(s->visual))
            continue;
        s->pose_stage = 3;
        if (s->worker) {
            Value result = pb_pose_call(s->worker, 4, 0, 0);
            variant_destroy(&result);
        }
        s = pb_slot(b, handle);
        if (!s)
            continue;
        Value delta;
        from_type(TYPE(FLOAT))(&delta, &s->step_delta);
        Value result = pb_pose_call(s->visual, 2, (const void *[]){&delta}, 1);
        variant_destroy(&result);
        variant_destroy(&delta);
    }
    b->frame_count = 0;
}
static void pb_capture(PbBatch *b, double delta) {
    if (!isfinite(delta) || delta < 0)
        return;
    b->statistics[1]++;
    for (int i = 0; i < b->high_water; i++) {
        PbSlot *s = &b->slots[i];
        void *unit = s->live ? object_from_id(s->unit) : 0;
        if (!unit)
            continue;
        ptrcall(global_transform, unit, 0, &s->physics);
        s->elapsed += delta;
        b->statistics[2]++;
    }
}
static void pb_changes(PbBatch *b, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    for (int i = 0; i < b->high_water; i++) {
        PbSlot *s = &b->slots[i];
        if (!s->live)
            continue;
        b->statistics[5]++;
        void *unit = object_from_id(s->unit), *geometry = object_from_id(s->geometry), *parent = 0;
        if (!unit || !geometry) {
            pb_append(output, pb_handle(b, s));
            continue;
        }
        ptrcall(pb_parent, unit, 0, &parent);
        IpT root;
        ptrcall(global_transform, unit, 0, &root);
        int x = (int)floor(root.p.x / 24), z = (int)floor(root.p.z / 24);
        if ((parent ? rp_object_id(parent) : 0) != s->owner || x != s->cell_x || z != s->cell_z ||
            root.p.y - s->radius < s->low || root.p.y + s->radius > s->high) {
            pb_append(output, pb_handle(b, s));
            b->statistics[6]++;
            int changed_cell = x != s->cell_x || z != s->cell_z;
            s->cell_x = x;
            s->cell_z = z;
            s->low =
                changed_cell ? root.p.y - s->radius - 1 : fminf(s->low, root.p.y - s->radius - 1);
            s->high =
                changed_cell ? root.p.y + s->radius + 1 : fmaxf(s->high, root.p.y + s->radius + 1);
        }
    }
}
static void pb_write(float *row, const float *transform) {
    for (int axis = 0; axis < 3; axis++) {
        memcpy(row + axis * 4, transform + axis * 3, sizeof(float) * 3);
        row[axis * 4 + 3] = transform[9 + axis];
    }
}
static void pb_pack(PbBatch *b, int paused, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    if (!b->capacity)
        return;
    Value current, previous;
    pb_resize(&current, b->capacity);
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 1)(&previous, (const void *[]){&b->last});
    float *pixels = (float *)bytes_index(&current, 0);
    float *old_pixels = (float *)bytes_index(&previous, 0);
    pb_identity_row(pixels);
    b->statistics[3]++;
    for (int i = 0; i < b->high_water; i++) {
        PbSlot *s = &b->slots[i];
        void *unit = s->live ? object_from_id(s->unit) : 0;
        void *geometry = s->live ? object_from_id(s->geometry) : 0;
        if (!unit || !geometry)
            continue;
        IpT root;
        ptrcall(global_transform, unit, 0, &root);
        int reset = s->first || iplen(ips(root.p, s->previous)) > 4;
        s->previous = root.p;
        s->first = 0;
        GDExtensionBool shown = 0;
        ptrcall(visible_in_tree, geometry, 0, &shown);
        float pulse[4] = {0};
        void *material = object_from_id(s->pulse);
        if (material) {
            Value color, strength;
            variant_nil(&color);
            variant_nil(&strength);
            ptrcall(pb_shader_parameter, material, (const void *[]){&pb_pulse_names[0]}, &color);
            ptrcall(pb_shader_parameter, material, (const void *[]){&pb_pulse_names[1]}, &strength);
            if (get_type(&color) == TYPE(COLOR)) {
                float srgb[4];
                to_type(TYPE(COLOR))(srgb, &color);
                pb_linear(srgb, 0, pulse, 0);
            }
            double value = 0;
            if (index_number(&strength, &value))
                pulse[3] = (float)value;
            variant_destroy(&color);
            variant_destroy(&strength);
        }
        IpT inverse, rebase = rp_identity();
        if (!paused) {
            pb_inverse(&s->sampled, 0, &inverse, 0);
            rebase = rp_multiply(s->physics, inverse);
        }
        pb_publish_root(s, geometry, root);
        rp_worlds(s->rig, s->rig->count - 1);
        for (int part = 0; part < s->count; part++) {
            float *row = pixels + (s->offset + part) * 16;
            float *old = old_pixels + (s->offset + part) * 16;
            void *anchor = object_from_id(s->anchors[part]);
            GDExtensionBool visible = 0;
            if (shown && anchor)
                ptrcall(visible_in_tree, anchor, 0, &visible);
            float transform[12];
            if (visible && resident_rig_pose(s->rig, part, transform)) {
                pb_write(row, transform);
                memcpy(row + 12, pulse, sizeof(pulse));
                /* Root row retains the shared hit pulse. Non-root belt rows
                 * carry exact current travel; compute never interpolates col3. */
                if (part > 0 && isfinite(s->track_travel[part]))
                    row[12] = s->track_travel[part];
                b->statistics[4]++;
            }
            if (!paused) {
                int old_shown = 0;
                for (int axis = 0; axis < 3; axis++) {
                    memcpy(transform + axis * 3, old + axis * 4, sizeof(float) * 3);
                    transform[9 + axis] = old[axis * 4 + 3];
                    for (int col = 0; col < 3; col++)
                        old_shown |= old[axis * 4 + col] != 0;
                }
                if (old_shown) {
                    float advanced[12];
                    compose_pose((const float *)&rebase, transform, advanced);
                    pb_write(old, advanced);
                }
            }
            if (reset)
                memcpy(old, row, sizeof(float) * 16);
        }
        s->sampled = root;
    }
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&b->last);
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 1)(&b->last, (const void *[]){&current});
    for (int i = 0; i < 2; i++) {
        Value value;
        from_type(TYPE(PACKED_BYTE_ARRAY))(&value, i ? &previous : &current);
        array_append(output, (const void *[]){&value}, 0, 1);
        variant_destroy(&value);
    }
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&current);
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&previous);
}
static void *pb_create(void *userdata, GDExtensionBool notify) {
    (void)userdata;
    (void)notify;
    PbBatch *b = calloc(1, sizeof(PbBatch));
    if (!b)
        return 0;
    b->slots = calloc(PB_LIMIT, sizeof(PbSlot));
    if (!b->slots) {
        free(b);
        return 0;
    }
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 0)(&b->last, 0);
    void *owner = construct(&parent_name);
    set_instance(owner, &pb_class, b);
    return owner;
}
static void pb_free(void *userdata, void *instance) {
    (void)userdata;
    PbBatch *b = instance;
    for (int i = 0; i < b->high_water; i++)
        pb_release(b, &b->slots[i]);
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&b->last);
    free(b->slots);
    free(b);
}
static void pb_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                    GDExtensionInt count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    PbBatch *b = instance;
    int method = (int)(intptr_t)userdata;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    int64_t handle = -1;
    if (count && get_type(args[0]) == TYPE(INT))
        to_type(TYPE(INT))(&handle, (void *)args[0]);
    PbSlot *s = pb_slot(b, handle);
    variant_nil(ret);
    if (method == 0 && count == 1 && handle > 0 && handle <= 8192 && !b->live) {
        b->capacity = (int)handle;
        get_dtor(TYPE(PACKED_BYTE_ARRAY))(&b->last);
        pb_resize(&b->last, b->capacity);
        pb_identity_row((float *)bytes_index(&b->last, 0));
        GDExtensionBool yes = 1;
        variant_destroy(ret);
        from_type(TYPE(BOOL))(ret, &yes);
    } else if (method == 1 && count == 6 && get_type(args[2]) == TYPE(ARRAY) &&
               get_type(args[4]) == TYPE(INT)) {
        Value anchors;
        to_type(TYPE(ARRAY))(&anchors, (void *)args[2]);
        int64_t offset;
        double radius;
        to_type(TYPE(INT))(&offset, (void *)args[4]);
        int64_t result = -1;
        if (index_number(args[5], &radius))
            result = pb_bind(b, cv_argument(args[0]), cv_argument(args[1]), &anchors,
                             cv_argument(args[3]), offset, radius);
        get_dtor(TYPE(ARRAY))(&anchors);
        variant_destroy(ret);
        from_type(TYPE(INT))(ret, &result);
    } else if (method == 2 && count == 1) {
        GDExtensionBool valid = s != 0;
        if (s)
            pb_release(b, s);
        variant_destroy(ret);
        from_type(TYPE(BOOL))(ret, &valid);
    } else if (method == 3 && count == 1) {
        double delta;
        if (!index_number(args[0], &delta))
            return;
        pb_capture(b, delta);
    } else if (method == 4 && count == 1) {
        double elapsed = s ? s->elapsed : 0;
        variant_destroy(ret);
        from_type(TYPE(FLOAT))(ret, &elapsed);
    } else if (method == 5 && count == 2) {
        double elapsed;
        if (!index_number(args[1], &elapsed) || !isfinite(elapsed) || elapsed < 0)
            return;
        if (s)
            s->elapsed = elapsed;
    } else if (method == 6 && count == 2 && cv_object_argument(args[1])) {
        void *material = cv_argument(args[1]);
        if (material && !object_cast(material, pb_shader_tag))
            return;
        if (s)
            s->pulse = material ? object_id(args[1]) : 0;
    } else if (method == 7 && count == 0) {
        Value array;
        pb_changes(b, &array);
        variant_destroy(ret);
        from_type(TYPE(ARRAY))(ret, &array);
        get_dtor(TYPE(ARRAY))(&array);
    } else if (method == 8 && count == 1 && get_type(args[0]) == TYPE(BOOL)) {
        GDExtensionBool paused;
        to_type(TYPE(BOOL))(&paused, (void *)args[0]);
        Value array;
        pb_pack(b, paused, &array);
        variant_destroy(ret);
        from_type(TYPE(ARRAY))(ret, &array);
        get_dtor(TYPE(ARRAY))(&array);
    } else if (method == 9 && count == 0) {
        b->statistics[0] = (uint64_t)b->live;
        variant_destroy(ret);
        profile_array(b->statistics, 7, ret);
    } else if (method == 10 && count == 3 && get_type(args[1]) == TYPE(TRANSFORM3D) &&
               get_type(args[2]) == TYPE(BOOL)) {
        if (s) {
            to_type(TYPE(TRANSFORM3D))(&s->geometry_pose, (void *)args[1]);
            GDExtensionBool publish;
            to_type(TYPE(BOOL))(&publish, (void *)args[2]);
            s->scene_geometry = publish;
            void *unit = object_from_id(s->unit), *geometry = object_from_id(s->geometry);
            if (unit && geometry) {
                IpT root;
                ptrcall(global_transform, unit, 0, &root);
                /* Aim and weapon sockets read the rig before palette packing.
                 * Publish their authoritative root during this same call. */
                pb_publish_root(s, geometry, root);
            }
        }
    } else if (method == 11 && count == 3 && get_type(args[1]) == TYPE(INT)) {
        int64_t part;
        double travel;
        to_type(TYPE(INT))(&part, (void *)args[1]);
        if (!s || part <= 0 || part >= s->count || !index_number(args[2], &travel) ||
            !isfinite(travel) || fabs(travel) > FLT_MAX)
            return;
        s->track_travel[part] = (float)travel;
    } else if (method == 12 && count == 3 && cv_object_argument(args[1]) &&
               cv_object_argument(args[2])) {
        if (s) {
            s->visual = object_id(args[1]);
            s->worker = object_id(args[2]);
        }
    } else if ((method == 13 && count == 0) ||
               (method == 14 && count == 1 && get_type(args[0]) == TYPE(BOOL))) {
        Value array;
        if (method == 13)
            pb_prepare(b, &array);
        else {
            GDExtensionBool workers;
            to_type(TYPE(BOOL))(&workers, (void *)args[0]);
            pb_finish(b, workers, &array);
        }
        variant_destroy(ret);
        from_type(TYPE(ARRAY))(ret, &array);
        get_dtor(TYPE(ARRAY))(&array);
    } else if (method == 15 && count == 0) {
        pb_publish(b);
    } else
        return;
    error->error = GDEXTENSION_CALL_OK;
}
static void presentation_initialize(void) {
    name_new(&pb_class, "CopperfinPresentationBatch");
    const char *methods[] = {"configure", "bind_unit",   "unbind",      "capture",
                             "elapsed",   "set_elapsed", "set_pulse",   "changes",
                             "pack",      "statistics",  "set_geometry", "set_track",
                             "set_pose_owner", "prepare_poses", "finish_poses", "publish_poses"};
    const char *arguments[] = {"capacity", "unit",   "geometry", "anchors", "rig",
                               "offset",   "radius", "handle",   "value", "part", "travel", "scene_geometry",
                               "visual", "worker", "workers"};
    for (int i = 0; i < 16; i++)
        name_new(&pb_methods[i], methods[i]);
    for (int i = 0; i < 15; i++)
        name_new(&pb_args[i], arguments[i]);
    const char *pose_names[] = {"prepare_gpu_pose", "finish_gpu_pose", "publish_gpu_pose",
                                "begin", "end", "job", "pending"};
    for (int i = 0; i < 7; i++)
        name_new(&pb_pose_names[i], pose_names[i]);
    name_new(&pb_pulse_names[0], "hit_color");
    name_new(&pb_pulse_names[1], "hit_strength");
    pb_initialized = 1;
    Value name, klass;
    name_new(&name, "affine_inverse");
    pb_inverse = get_builtin(TYPE(TRANSFORM3D), &name, 3816817146LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&name, "srgb_to_linear");
    pb_linear = get_builtin(TYPE(COLOR), &name, 3334027602LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&name, "get_parent");
    pb_parent = method_bind(&cr_tree_name, &name, 3160264692LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&klass, "ShaderMaterial");
    pb_shader_tag = class_tag(&klass);
    name_new(&name, "get_shader_parameter");
    pb_shader_parameter = method_bind(&klass, &name, 2760726917LL);
    get_dtor(TYPE(STRING_NAME))(&name);
    get_dtor(TYPE(STRING_NAME))(&klass);
    if (!pb_inverse || !pb_linear || !pb_parent || !pb_shader_parameter || !pb_shader_tag)
        return;
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = pb_create;
    info.free_instance_func = pb_free;
    register_class(library, &pb_class, &parent_name, &info);
    pb_registered = 1;
    const int counts[] = {1, 6, 1, 1, 1, 2, 2, 0, 1, 0, 3, 3, 3, 0, 1, 0};
    const GDExtensionVariantType types[16][6] = {
        {TYPE(INT)},
        {TYPE(OBJECT), TYPE(OBJECT), TYPE(ARRAY), TYPE(OBJECT), TYPE(INT), TYPE(FLOAT)},
        {TYPE(INT)},
        {TYPE(FLOAT)},
        {TYPE(INT)},
        {TYPE(INT), TYPE(FLOAT)},
        {TYPE(INT), TYPE(OBJECT)},
        {},
        {TYPE(BOOL)},
        {},
        {TYPE(INT), TYPE(TRANSFORM3D), TYPE(BOOL)},
        {TYPE(INT), TYPE(INT), TYPE(FLOAT)},
        {TYPE(INT), TYPE(OBJECT), TYPE(OBJECT)}, {}, {TYPE(BOOL)}, {}};
    const GDExtensionVariantType outputs[] = {TYPE(BOOL),  TYPE(INT),   TYPE(BOOL), TYPE(NIL),
                                              TYPE(FLOAT), TYPE(NIL),   TYPE(NIL),  TYPE(ARRAY),
                                              TYPE(ARRAY), TYPE(ARRAY), TYPE(NIL), TYPE(NIL),
                                              TYPE(NIL), TYPE(ARRAY), TYPE(ARRAY), TYPE(NIL)};
    const int names[16][6] = {{0},   {1, 2, 3, 4, 5, 6}, {7}, {8}, {7}, {7, 8}, {7, 8}, {}, {8}, {},
                              {7, 2, 11}, {7, 9, 10}, {7, 12, 13}, {}, {14}, {}};
    for (int i = 0; i < 16; i++) {
        GDExtensionPropertyInfo parameters[6];
        GDExtensionClassMethodArgumentMetadata metadata[6] = {0};
        for (int j = 0; j < counts[i]; j++)
            parameters[j] = (GDExtensionPropertyInfo){
                types[i][j], &pb_args[names[i][j]], &empty_name, 0, &empty_string, 6};
        GDExtensionPropertyInfo output = {outputs[i], &empty_name,   &empty_name,
                                          0,          &empty_string, 6};
        GDExtensionClassMethodInfo method = {0};
        method.name = &pb_methods[i];
        method.method_userdata = (void *)(intptr_t)i;
        method.call_func = pb_call;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.argument_count = counts[i];
        method.arguments_info = parameters;
        method.arguments_metadata = metadata;
        method.has_return_value = outputs[i] != TYPE(NIL);
        method.return_value_info = method.has_return_value ? &output : 0;
        register_method(library, &pb_class, &method);
    }
}
static void presentation_deinitialize(void) {
    if (!pb_initialized)
        return;
    if (pb_registered)
        unregister_class(library, &pb_class);
    for (int i = 0; i < 16; i++)
        get_dtor(TYPE(STRING_NAME))(&pb_methods[i]);
    for (int i = 0; i < 15; i++)
        get_dtor(TYPE(STRING_NAME))(&pb_args[i]);
    for (int i = 0; i < 7; i++)
        get_dtor(TYPE(STRING_NAME))(&pb_pose_names[i]);
    for (int i = 0; i < 2; i++)
        get_dtor(TYPE(STRING_NAME))(&pb_pulse_names[i]);
    get_dtor(TYPE(STRING_NAME))(&pb_class);
    pb_initialized = pb_registered = 0;
}
