/* Match-owned native ground movement. Public ABI only, main thread only.
 * Slots retain movement/filter state; inner crowd/projection loops use native
 * arrays rather than script objects. Unit nodes remain the gameplay facade. */
#define CR_LIMIT 4096
#define CR_HASH 8192
typedef struct {
    int x, z, first, count;
} CrCell;
typedef struct {
    Value polygon;
    double height;
    float plane[4];
    int slope;
} CrPolygon;
typedef struct {
    int x, z, order, slot;
} CrBody;
typedef struct {
    uint64_t unit_id, agent_id, owner_id, map;
    uint32_t generation;
    int live, vehicle, ghost, has_destination, revision, synchronized, passive;
    int recovery_checked, previous_valid, window_count, hint;
    int64_t last_iteration;
    double speed, radius, delta, progress_elapsed, recovery_left, alignment;
    IpV position, progress_position, recovery_direction, window[10], direction_total;
    IpT previous;
} CrSlot;
typedef struct {
    CrSlot *slots;
    uint64_t ids[CR_HASH];
    int lookup[CR_HASH], high_water;
    CrBody bodies[CR_LIMIT];
    int body_count;
    uint64_t platforms[CR_LIMIT];
    int platform_count;
    CrCell *cells;
    CrPolygon *polygons;
    int cell_count, polygon_count, columns, rows, elevated, projection_valid;
    int64_t projection_iteration;
    Value heights;
    int has_heights;
    double maximum_step, maximum_radius, simulation_time;
    uint64_t frame, processed, callbacks, server_projections;
    int profiling;
    uint64_t profile[8]; /* begin/step/callback/projection us, then their call counts */
    NsSurface surface;
} CrRuntime;
static Value cr_class, cr_method[12], cr_args[21], cr_field[22], cr_helpers[7];
static Value cr_engine_name, cr_navigation_name, cr_geometry_name, cr_tree_name, cr_scene_name;
static GDExtensionMethodBindPtr cr_bind[30];
static GDExtensionPtrBuiltInMethod cr_keys, cr_vectors_size;
static GDExtensionInterfacePackedVector3ArrayOperatorIndexConst cr_vector_read;
static GDExtensionInterfaceGlobalGetSingleton cr_singleton;
static void *cr_navigation, *cr_geometry, *cr_engine;
static int cr_initialized, cr_registered;
enum {
    CR_TARGET,
    CR_NEXT,
    CR_FINISHED,
    CR_FINAL,
    CR_PATH,
    CR_PATH_INDEX,
    CR_GET_VELOCITY,
    CR_SET_VELOCITY,
    CR_FORCE_VELOCITY,
    CR_GET_RADIUS,
    CR_GET_MAX_SPEED,
    CR_SET_MAX_SPEED,
    CR_DISTANCE,
    CR_GET_HEIGHT,
    CR_SET_HEIGHT,
    CR_GET_PRIORITY,
    CR_SET_PRIORITY,
    CR_GET_MAP,
    CR_CLOSEST,
    CR_ITERATION,
    CR_SET_TRANSFORM,
    CR_POINT_IN_POLYGON,
    CR_HAS_META,
    CR_GET_PARENT,
    CR_CAN_PROCESS,
    CR_PHYSICS_PROCESSING,
    CR_FRAME,
    CR_SET_TARGET,
    CR_GET_TREE,
    CR_TREE_PAUSED
};
enum {
    CR_SPEED,
    CR_GHOST,
    CR_DESTINATION,
    CR_REVISION,
    CR_SYNC,
    CR_PROGRESS_TIME,
    CR_PROGRESS_POSITION,
    CR_RECOVERY_TIME,
    CR_RECOVERY_DIRECTION,
    CR_RECOVERY_CHECKED,
    CR_ALIGNMENT,
    CR_PLATFORM,
    CR_PHYSICS_DELTA,
    CR_PASSIVE,
    CR_PREVIOUS,
    CR_LAST_ITERATION,
    CR_CLEARANCE_TARGET,
    CR_CLEARANCE_UNTIL,
    CR_AIM_TARGET,
    CR_HP,
    CR_PAUSED,
    CR_PLACEHOLDER
};
enum {
    CR_FINISH_COMMAND,
    CR_CALL_DEFERRED,
    CR_EMIT,
    CR_BLOCKED,
    CR_IS_CONSTRUCTED,
    CR_DECK_HEIGHT,
    CR_TYPE
};
static Value cr_garrison, cr_breach, cr_movement_done, cr_passive_start, cr_passive_stop;

static int cr_eq(float a, float b) {
    return a == b || fabsf(a - b) < fmaxf(.00001f, .00001f * fabsf(a));
}
static int cr_veq(IpV a, IpV b) { return cr_eq(a.x, b.x) && cr_eq(a.y, b.y) && cr_eq(a.z, b.z); }
static int cr_zero(IpV a) {
    return fabsf(a.x) < .00001f && fabsf(a.y) < .00001f && fabsf(a.z) < .00001f;
}
static int cr_teq(IpT a, IpT b) {
    const float *x = (const float *)&a, *y = (const float *)&b;
    for (int i = 0; i < 12; i++)
        if (!cr_eq(x[i], y[i]))
            return 0;
    return 1;
}
static IpV cr_flat(IpV p) {
    p.y = 0;
    return p;
}
static IpV cr_toward(IpV a, IpV b, double distance) {
    IpV offset = ips(b, a);
    float length = iplen(offset);
    return length <= distance || length < .00001f
               ? b
               : ipa(a,
                     ipm(ipv(offset.x / length, offset.y / length, offset.z / length), distance));
}
static IpV cr_limit(IpV v, double maximum) {
    float length = iplen(v);
    return length > maximum && length > 0
               ? ipm(ipv(v.x / length, v.y / length, v.z / length), maximum)
               : v;
}
static IpV cr_yaw(IpV v, double angle) {
    float c = cosf((float)angle), s = sinf((float)angle);
    return ipv(c * v.x + s * v.z, v.y, -s * v.x + c * v.z);
}
static void cr_variant(void *object, Value *value) { from_type(TYPE(OBJECT))(value, &object); }
static double cr_number(void *object, int field) {
    double resident = 0;
    int present = 0;
    if (field == CR_SPEED && native_agent_speed(object, &resident))
        return resident;
    if (field == CR_HP && native_unit_scalar(object, US_HP, &resident, &present))
        return present ? resident : 0;
    Value v;
    cr_variant(object, &v);
    double n = number_property(&v, &cr_field[field]);
    variant_destroy(&v);
    return n;
}
static int cr_read(void *object, int field, GDExtensionVariantType type, void *out) {
    Value v, result;
    cr_variant(object, &v);
    GDExtensionBool valid = 0;
    get_named(&v, &cr_field[field], &result, &valid);
    int ok = valid && get_type(&result) == type;
    if (ok)
        to_type(type)(out, &result);
    variant_destroy(&result);
    variant_destroy(&v);
    return ok;
}
static void cr_write(void *object, int field, GDExtensionVariantType type, const void *data) {
    Value v, value;
    cr_variant(object, &v);
    from_type(type)(&value, (void *)data);
    GDExtensionBool valid = 0;
    ip_set_named(&v, &cr_field[field], &value, &valid);
    variant_destroy(&value);
    variant_destroy(&v);
}
static void cr_write_number(void *object, int field, double n) {
    cr_write(object, field, TYPE(FLOAT), &n);
}
static void cr_write_bool(void *object, int field, int b) {
    GDExtensionBool v = b != 0;
    cr_write(object, field, TYPE(BOOL), &v);
}
static Value cr_call(void *object, int method, const void **args, int count) {
    Value v, result;
    cr_variant(object, &v);
    GDExtensionCallError error = {0};
    variant_call(&v, &cr_helpers[method], args, count, &result, &error);
    variant_destroy(&v);
    return result;
}
static int cr_meta(void *object, const Value *key) {
    const void *a[] = {key};
    GDExtensionBool value = 0;
    ptrcall(cr_bind[CR_HAS_META], object, a, &value);
    return value;
}
static int cr_bool(void *object, int bind) {
    GDExtensionBool b = 0;
    ptrcall(cr_bind[bind], object, 0, &b);
    return b;
}
static double cr_real(void *object, int bind) {
    double n = 0;
    ptrcall(cr_bind[bind], object, 0, &n);
    return n;
}
static IpV cr_vector(void *object, int bind) {
    IpV v;
    ptrcall(cr_bind[bind], object, 0, &v);
    return v;
}
static void cr_set_vector(void *object, int bind, IpV v) {
    const void *a[] = {&v};
    ptrcall(cr_bind[bind], object, a, 0);
}
static void cr_set_real(void *object, int bind, double v) {
    const void *a[] = {&v};
    ptrcall(cr_bind[bind], object, a, 0);
}
static uint64_t cr_frame_number(void) {
    uint64_t n = 0;
    ptrcall(cr_bind[CR_FRAME], cr_engine, 0, &n);
    return n;
}
static CrSlot *cr_slot(CrRuntime *r, int64_t handle) {
    int index = (int)(handle & 65535);
    uint32_t generation = (uint32_t)((uint64_t)handle >> 16);
    if (index < 0 || index >= r->high_water)
        return 0;
    CrSlot *s = &r->slots[index];
    return s->live && s->generation == generation ? s : 0;
}
static unsigned cr_hash(uint64_t id) {
    return (unsigned)(((id >> 32) ^ id) * 2654435761u) & (CR_HASH - 1);
}
static void cr_rehash(CrRuntime *r) {
    memset(r->ids, 0, sizeof(r->ids));
    for (int i = 0; i < r->high_water; i++)
        if (r->slots[i].live) {
            uint64_t id = r->slots[i].unit_id;
            unsigned h = cr_hash(id);
            while (r->ids[h])
                h = (h + 1) & (CR_HASH - 1);
            r->ids[h] = id;
            r->lookup[h] = i;
        }
}
static int cr_find(CrRuntime *r, uint64_t id) {
    unsigned h = cr_hash(id);
    while (r->ids[h]) {
        if (r->ids[h] == id)
            return r->lookup[h];
        h = (h + 1) & (CR_HASH - 1);
    }
    return -1;
}
static int cr_body_compare(const void *a, const void *b) {
    const CrBody *x = a, *y = b;
    if (x->x != y->x)
        return x->x < y->x ? -1 : 1;
    if (x->z != y->z)
        return x->z < y->z ? -1 : 1;
    return (x->order > y->order) - (x->order < y->order);
}
static int cr_cell_compare(const void *a, const void *b) {
    const CrCell *x = a, *y = b;
    if (x->x != y->x)
        return x->x < y->x ? -1 : 1;
    return (x->z > y->z) - (x->z < y->z);
}
static CrCell *cr_cell(CrRuntime *r, int x, int z) {
    CrCell key = {x, z, 0, 0};
    return r->cell_count ? bsearch(&key, r->cells, r->cell_count, sizeof(CrCell), cr_cell_compare)
                         : 0;
}
static int cr_first_body(CrRuntime *r, int x, int z) {
    int low = 0, high = r->body_count;
    while (low < high) {
        int mid = (low + high) / 2;
        CrBody *b = &r->bodies[mid];
        if (b->x < x || (b->x == x && b->z < z))
            low = mid + 1;
        else
            high = mid;
    }
    return low;
}
static double cr_height(CrRuntime *r, IpV p) {
    if (!r->has_heights)
        return 0;
    const float *height = sight_float_index(&r->heights, 0);
    double x = ipclamp((double)p.x / .5, 0, r->columns), z = ipclamp((double)p.z / .5, 0, r->rows);
    int i = (int)fmin((int)x, r->columns - 1), j = (int)fmin((int)z, r->rows - 1),
        stride = r->columns + 1, index = j * stride + i;
    double top = ipmix(height[index], height[index + 1], x - i),
           bottom = ipmix(height[index + stride], height[index + stride + 1], x - i);
    return ipmix(top, bottom, z - j);
}
static double cr_polygon_height(CrPolygon *polygon, IpV p) {
    if (!polygon->slope)
        return polygon->height;
    /* Match script scalar (double) arithmetic on the float Plane components. */
    return ((double)polygon->plane[3] - (double)polygon->plane[0] * p.x -
            (double)polygon->plane[2] * p.z) /
           polygon->plane[1];
}
static int cr_contains(CrPolygon *polygon, IpV p) {
    float point[] = {p.x, p.z};
    const void *a[] = {point, &polygon->polygon};
    GDExtensionBool inside = 0;
    ptrcall(cr_bind[CR_POINT_IN_POLYGON], cr_geometry, a, &inside);
    return inside;
}
static IpV cr_project(CrRuntime *r, CrSlot *s, IpV point) {
    double surface = r->elevated ? cr_height(r, point) + .5 : 0;
    if (r->projection_valid) {
        if (r->elevated && s->hint >= 0 && s->hint < r->polygon_count) {
            CrPolygon *p = &r->polygons[s->hint];
            double height = cr_polygon_height(p, point);
            if (fabs(height - surface) <= .35 && cr_contains(p, point))
                return ipv(point.x, height, point.z);
        }
        CrCell *cell = cr_cell(r, (int)floor((double)point.x / 6), (int)floor((double)point.z / 6));
        if (cell)
            for (int i = cell->first; i < cell->first + cell->count; i++) {
                CrPolygon *p = &r->polygons[i];
                double height = cr_polygon_height(p, point);
                if ((r->elevated ? fabs(height - surface) <= .35 : height >= point.y) &&
                    cr_contains(p, point)) {
                    s->hint = i;
                    return ipv(point.x, height, point.z);
                }
            }
    }
    s->hint = -1;
    if (r->elevated)
        point.y = (float)surface;
    if (r->projection_valid && r->surface.polygon_count > 0 &&
        r->surface.iteration == r->projection_iteration) {
        uint64_t started = r->profiling ? profile_now() : 0;
        IpV result = ns_closest(&r->surface, point);
        if (r->profiling)
            r->surface.elapsed += profile_now() - started;
        return result;
    }
    const void *a[] = {&s->map, &point};
    IpV result;
    uint64_t started = r->profiling ? profile_now() : 0;
    ptrcall(cr_bind[CR_CLOSEST], cr_navigation, a, &result);
    if (r->profiling) {
        r->profile[3] += profile_now() - started;
        r->profile[7]++;
    }
    r->server_projections++;
    return result;
}
static IpV cr_navigation_position(CrRuntime *r, CrSlot *s, void *agent, IpV point, int platform) {
    IpV p = cr_project(r, s, point);
    p.y -= (float)cr_real(agent, CR_GET_HEIGHT);
    if (r->elevated || platform)
        p.y = (float)cr_height(r, p);
    return p;
}
static void cr_import(CrSlot *s, void *agent) {
    s->has_destination = cr_number(agent, CR_DESTINATION) != 0;
    s->revision = (int)cr_number(agent, CR_REVISION);
    s->progress_elapsed = cr_number(agent, CR_PROGRESS_TIME);
    cr_read(agent, CR_PROGRESS_POSITION, TYPE(VECTOR3), &s->progress_position);
    s->recovery_left = cr_number(agent, CR_RECOVERY_TIME);
    cr_read(agent, CR_RECOVERY_DIRECTION, TYPE(VECTOR3), &s->recovery_direction);
    s->recovery_checked = cr_number(agent, CR_RECOVERY_CHECKED) != 0;
}
static void cr_publish(CrSlot *s, void *agent) {
    cr_write_bool(agent, CR_DESTINATION, s->has_destination);
    cr_write_number(agent, CR_PROGRESS_TIME, s->progress_elapsed);
    cr_write(agent, CR_PROGRESS_POSITION, TYPE(VECTOR3), &s->progress_position);
    cr_write_number(agent, CR_RECOVERY_TIME, s->recovery_left);
    cr_write(agent, CR_RECOVERY_DIRECTION, TYPE(VECTOR3), &s->recovery_direction);
    cr_write_bool(agent, CR_RECOVERY_CHECKED, s->recovery_checked);
}
static void cr_emit(void *agent, const Value *signal) {
    Value name, result;
    from_type(TYPE(STRING_NAME))(&name, (void *)signal);
    const void *a[] = {&name};
    result = cr_call(agent, CR_EMIT, a, 1);
    variant_destroy(&result);
    variant_destroy(&name);
}
static void cr_passive(CrSlot *s, void *agent, IpV velocity) {
    int passive = !s->has_destination && !cr_zero(velocity);
    if (passive != s->passive) {
        s->passive = passive;
        cr_write_bool(agent, CR_PASSIVE, passive);
        cr_emit(agent, passive ? &cr_passive_start : &cr_passive_stop);
    }
}
static int cr_blocked(void *agent, double speed) {
    if (speed > 0)
        return 0;
    Value result = cr_call(agent, CR_BLOCKED, 0, 0);
    GDExtensionBool blocked = 0;
    if (get_type(&result) == TYPE(BOOL))
        to_type(TYPE(BOOL))(&blocked, &result);
    variant_destroy(&result);
    return blocked;
}
static void cr_begin(CrRuntime *r, const void *units, const void *platforms) {
    r->body_count = 0;
    r->maximum_step = 0;
    int64_t count = count_array((void *)units);
    for (int64_t i = 0; i < count; i++) {
        const void *value = array_index(units, i);
        if (get_type(value) != TYPE(OBJECT))
            continue;
        int index = cr_find(r, object_id(value));
        if (index < 0)
            continue;
        CrSlot *s = &r->slots[index];
        void *unit = object_from_id(s->unit_id), *agent = object_from_id(s->agent_id);
        if (!unit || !agent)
            continue;
        IpT root;
        ptrcall(global_transform, unit, 0, &root);
        s->position = root.p;
        s->speed = cr_number(agent, CR_SPEED);
        s->radius = cr_real(agent, CR_GET_RADIUS);
        s->ghost = cr_number(agent, CR_GHOST) != 0;
        void *owner = 0;
        ptrcall(cr_bind[CR_GET_PARENT], unit, 0, &owner);
        Value owner_value;
        cr_variant(owner, &owner_value);
        s->owner_id = object_id(&owner_value);
        variant_destroy(&owner_value);
        r->maximum_step = fmax(r->maximum_step, s->speed * s->delta);
        r->bodies[r->body_count++] = (CrBody){(int)floor((double)root.p.x / 3),
                                              (int)floor((double)root.p.z / 3), (int)i, index};
    }
    qsort(r->bodies, r->body_count, sizeof(CrBody), cr_body_compare);
    r->platform_count = 0;
    count = count_array((void *)platforms);
    for (int64_t i = 0; i < count && r->platform_count < CR_LIMIT; i++) {
        const void *value = array_index(platforms, i);
        if (get_type(value) == TYPE(OBJECT))
            r->platforms[r->platform_count++] = object_id(value);
    }
    r->frame = cr_frame_number();
}
/* Returns a short ordered neighbor list with the same 3 m cell traversal as
 * Battlefield. Live transforms retain sequential callback/teleport semantics. */
static int cr_neighbors(CrRuntime *r, IpV point, double radius, int *out) {
    double reach = radius + r->maximum_step;
    int count = 0;
    int lx = (int)floor(((double)point.x - reach) / 3),
        lz = (int)floor(((double)point.z - reach) / 3);
    int hx = (int)floor(((double)point.x + reach) / 3),
        hz = (int)floor(((double)point.z + reach) / 3);
    for (int x = lx; x <= hx; x++)
        for (int z = lz; z <= hz; z++) {
            for (int i = cr_first_body(r, x, z); i < r->body_count; i++) {
                CrBody *b = &r->bodies[i];
                if (b->x != x || b->z != z)
                    break;
                CrSlot *s = &r->slots[b->slot];
                if (!s->live)
                    continue;
                void *unit = object_from_id(s->unit_id);
                if (!unit)
                    continue;
                GDExtensionBool queued = 0;
                ptrcall(queued_for_deletion, unit, 0, &queued);
                if (queued)
                    continue;
                IpT root;
                ptrcall(global_transform, unit, 0, &root);
                s->position = root.p;
                IpV d = cr_flat(ips(root.p, point));
                if (ipdot(d, d) <= radius * radius)
                    out[count++] = b->slot;
            }
        }
    return count;
}
static void cr_contact(CrRuntime *r, CrSlot *s, IpV origin, IpV next, const int *neighbors,
                       int count, float *result) {
    result[0] = result[1] = result[2] = 0;
    result[3] = 1;
    IpV step = cr_flat(ips(next, origin));
    double length = ipdot(step, step), best = 1;
    if (length < .00000001)
        return;
    for (int i = 0; i < count; i++) {
        CrSlot *other = &r->slots[neighbors[i]];
        if (other == s || !(other->speed > 0) || other->ghost)
            continue;
        IpV offset = cr_flat(ips(origin, other->position));
        double toward = ipdot(offset, step);
        if (toward >= 0)
            continue;
        double separation = s->radius + other->radius - .02,
               outside = (double)ipdot(offset, offset) - separation * separation, fraction = 0;
        if (outside > 0) {
            double discriminant = toward * toward - length * outside;
            if (discriminant < 0)
                continue;
            fraction = (-toward - sqrt(discriminant)) / length;
        }
        if (fraction >= 0 && fraction < best) {
            best = fraction;
            IpV normal = ipnorm(offset);
            result[0] = normal.x;
            result[2] = normal.z;
        }
    }
    result[3] = (float)best;
}
static IpV cr_clip(CrRuntime *r, CrSlot *s, void *agent, IpV origin, IpV next, double speed,
                   int platform) {
    IpV step = cr_flat(ips(next, origin));
    if (s->ghost || ipdot(step, step) < .00000001)
        return next;
    int neighbors[CR_LIMIT];
    int count =
        cr_neighbors(r, origin, s->radius + r->maximum_radius + speed * s->delta + .25, neighbors);
    float contact[4];
    cr_contact(r, s, origin, next, neighbors, count, contact);
    if (contact[3] >= 1)
        return next;
    IpV clipped = iplerp(origin, next, contact[3]),
        normal = ipv(contact[0], contact[1], contact[2]);
    IpV slide = ips(step, ipm(normal, fmin(0, ipdot(step, normal))));
    IpV navigable = cr_navigation_position(r, s, agent, ipa(origin, slide), platform),
        alternative = cr_toward(origin, navigable, speed * s->delta);
    cr_contact(r, s, origin, alternative, neighbors, count, contact);
    alternative = iplerp(origin, alternative, contact[3]);
    IpV a = ips(alternative, origin), c = ips(clipped, origin);
    return ipdot(a, a) > ipdot(c, c) ? alternative : clipped;
}
static int cr_occupied(CrRuntime *r, CrSlot *s, void *agent, int short_route) {
    Value path;
    get_ctor(TYPE(PACKED_VECTOR3_ARRAY), 0)(&path, 0);
    ptrcall(cr_bind[CR_PATH], agent, 0, &path);
    int64_t count = 0;
    cr_vectors_size(&path, 0, &count, 0);
    int occupied = 0;
    if (!count)
        goto done;
    const IpV *points = (const IpV *)cr_vector_read(&path, 0);
    IpV end = cr_flat(points[count - 1]), origin = cr_flat(s->position);
    double reach = s->radius + r->maximum_radius;
    IpV offset = ips(origin, end);
    if (ipdot(offset, offset) > (reach + .2) * (reach + .2))
        goto done;
    double remaining = 0;
    if (short_route) {
        int64_t index = 0;
        ptrcall(cr_bind[CR_PATH_INDEX], agent, 0, &index);
        IpV previous = origin;
        for (int64_t i = index; i < count; i++) {
            IpV p = cr_flat(points[i]);
            remaining += iplen(ips(previous, p));
            previous = p;
        }
    }
    int neighbors[CR_LIMIT];
    int n = cr_neighbors(r, end, reach, neighbors);
    for (int i = 0; i < n; i++) {
        CrSlot *other = &r->slots[neighbors[i]];
        if (other == s || other->owner_id != s->owner_id || !(other->speed > 0) || other->ghost)
            continue;
        void *other_agent = object_from_id(other->agent_id), *unit = object_from_id(other->unit_id);
        if (!other_agent || !unit || cr_number(unit, CR_HP) <= 0 ||
            cr_number(other_agent, CR_DESTINATION))
            continue;
        IpV velocity = cr_vector(other_agent, CR_GET_VELOCITY);
        if (ipdot(velocity, velocity) >= .01)
            continue;
        double spacing = s->radius + other->radius;
        if (iplen(cr_flat(ips(other->position, end))) < spacing && iplen(offset) <= spacing + .2 &&
            (!short_route || remaining <= spacing + .2)) {
            occupied = 1;
            break;
        }
    }
done:
    get_dtor(TYPE(PACKED_VECTOR3_ARRAY))(&path);
    return occupied;
}
static double cr_clearance(CrRuntime *r, CrSlot *s, IpV direction) {
    double clearance = 0;
    for (int step = 0; step < 4; step++) {
        double d = (step + 1) * .5;
        IpV p = ipa(s->position, ipm(direction, d)), projected = cr_project(r, s, p);
        if (iplen(cr_flat(ips(projected, p))) > .15)
            break;
        clearance = d;
    }
    return clearance;
}
static IpV cr_recovery(CrRuntime *r, CrSlot *s, IpV direction) {
    const double pi = 3.14159265358979323846;
    const double angles[] = {pi / 2, -pi / 2, pi / 4, -pi / 4, 3 * pi / 4, -3 * pi / 4, pi};
    IpV best = cr_yaw(direction, pi / 2);
    double clearance = -1, free_distance = -1;
    int neighbors[CR_LIMIT], count = 0;
    if (!s->ghost)
        count = cr_neighbors(r, s->position, s->radius + r->maximum_radius + 2 + .25, neighbors);
    for (int i = 0; i < 7; i++) {
        if (fabs(angles[i]) > pi / 2 && free_distance >= 2)
            break;
        IpV candidate = cr_yaw(direction, angles[i]);
        double distance = cr_clearance(r, s, candidate);
        float contact[4];
        cr_contact(r, s, s->position, ipa(s->position, ipm(candidate, distance)), neighbors, count,
                   contact);
        double free = distance * contact[3];
        int usable = free >= .02, previous = free_distance >= .02;
        if ((usable && !previous) ||
            (usable == previous &&
             (free > free_distance ||
              (fabs(free - free_distance) < fmax(.00001, .00001 * fabs(free)) &&
               distance > clearance)))) {
            best = candidate;
            clearance = distance;
            free_distance = free;
        }
    }
    return best;
}
static int cr_aiming(void *unit) {
    Value object, value;
    cr_variant(unit, &object);
    GDExtensionBool valid = 0;
    get_named(&object, &cr_field[CR_AIM_TARGET], &value, &valid);
    int aiming = valid && get_type(&value) == TYPE(OBJECT) && object_from_id(object_id(&value));
    variant_destroy(&value);
    variant_destroy(&object);
    return aiming;
}
static void cr_tick_slot(CrRuntime *r, CrSlot *s, double delta) {
    void *agent = object_from_id(s->agent_id), *unit = object_from_id(s->unit_id);
    if (!agent || !unit || !cr_bool(agent, CR_CAN_PROCESS) ||
        !cr_bool(agent, CR_PHYSICS_PROCESSING))
        return;
    if (!cr_number(agent, CR_SYNC))
        return;
    cr_import(s, agent);
    s->delta = delta;
    cr_write_number(agent, CR_PHYSICS_DELTA, delta);
    double speed = cr_number(agent, CR_SPEED);
    s->speed = speed;
    if (cr_meta(unit, &cr_breach) || cr_blocked(agent, speed)) {
        cr_set_vector(agent, CR_SET_VELOCITY, ipv(0, 0, 0));
        return;
    }
    if (cr_real(agent, CR_GET_MAX_SPEED) != speed)
        cr_set_real(agent, CR_SET_MAX_SPEED, speed);
    double priority = !s->has_destination && cr_aiming(unit) ? .8 : .5;
    if (cr_real(agent, CR_GET_PRIORITY) != priority)
        cr_set_real(agent, CR_SET_PRIORITY, priority);
    IpT root;
    ptrcall(global_transform, unit, 0, &root);
    s->position = root.p;
    IpV clearance = ipv(INFINITY, INFINITY, INFINITY);
    cr_read(agent, CR_CLEARANCE_TARGET, TYPE(VECTOR3), &clearance);
    if (isfinite(clearance.x) && isfinite(clearance.y) && isfinite(clearance.z)) {
        IpV offset = cr_flat(ips(clearance, s->position));
        double length = iplen(offset);
        if (length < .15 || r->simulation_time >= cr_number(agent, CR_CLEARANCE_UNTIL)) {
            clearance = ipv(INFINITY, INFINITY, INFINITY);
            cr_write(agent, CR_CLEARANCE_TARGET, TYPE(VECTOR3), &clearance);
        } else {
            cr_set_vector(agent, CR_SET_VELOCITY, ipm(ipnorm(offset), fmin(speed, length / delta)));
            return;
        }
    }
    if (!s->has_destination) {
        cr_set_vector(agent, CR_SET_VELOCITY, ipv(0, 0, 0));
        return;
    }
    IpV next = cr_vector(agent, CR_NEXT);
    if (cr_bool(agent, CR_FINISHED)) {
        s->has_destination = 0;
        cr_write_bool(agent, CR_DESTINATION, 0);
        cr_set_vector(agent, CR_SET_VELOCITY, ipv(0, 0, 0));
        Value name, revision;
        from_type(TYPE(STRING_NAME))(&name, &cr_helpers[CR_FINISH_COMMAND]);
        int64_t rev = s->revision;
        from_type(TYPE(INT))(&revision, &rev);
        const void *a[] = {&name, &revision};
        Value result = cr_call(agent, CR_CALL_DEFERRED, a, 2);
        variant_destroy(&result);
        variant_destroy(&name);
        variant_destroy(&revision);
        return;
    }
    IpV offset = cr_flat(ips(next, s->position)), direction = ipnorm(offset);
    s->progress_elapsed += delta;
    if (s->progress_elapsed >= 1 && s->recovery_left <= 0) {
        double traveled = iplen(ips(s->position, s->progress_position));
        s->progress_position = s->position;
        s->progress_elapsed = 0;
        if (traveled < .2) {
            s->recovery_direction = cr_yaw(direction, 1.5707963267948966);
            s->recovery_left = .6;
            if (!cr_occupied(r, s, agent, 0)) {
                s->recovery_direction = cr_recovery(r, s, direction);
                s->recovery_left = 2;
            }
            s->recovery_checked = 1;
            cr_set_vector(agent, CR_SET_TARGET, cr_vector(agent, CR_TARGET));
        }
    }
    if (s->recovery_left > 0) {
        s->recovery_left -= delta;
        if (!cr_occupied(r, s, agent, 0)) {
            if (!s->recovery_checked) {
                if (cr_clearance(r, s, s->recovery_direction) < 2) {
                    s->recovery_direction = cr_recovery(r, s, direction);
                    s->recovery_left = 2;
                }
                s->recovery_checked = 1;
            }
            if (iplen(ips(s->position, s->progress_position)) >= 2)
                s->recovery_left = 0;
            if (s->recovery_left <= 0)
                cr_set_vector(agent, CR_SET_TARGET, cr_vector(agent, CR_TARGET));
            else
                direction = s->recovery_direction;
        } else {
            s->recovery_left = fmin(s->recovery_left, .6);
            direction = ipnorm(ipa(ipm(direction, .35), s->recovery_direction));
        }
    }
    double desired = fmin(speed, iplen(offset) / fmax(delta, .001));
    if (!s->ghost && s->vehicle && s->recovery_left <= 0) {
        double remaining = iplen(cr_flat(ips(s->position, cr_vector(agent, CR_FINAL)))),
               target_distance = cr_real(agent, CR_DISTANCE);
        if (remaining < speed * speed / 26 + target_distance + .1) {
            Value path;
            get_ctor(TYPE(PACKED_VECTOR3_ARRAY), 0)(&path, 0);
            ptrcall(cr_bind[CR_PATH], agent, 0, &path);
            int64_t count = 0, index = 0;
            cr_vectors_size(&path, 0, &count, 0);
            ptrcall(cr_bind[CR_PATH_INDEX], agent, 0, &index);
            if (count && index >= count - 1)
                desired = fmin(desired, sqrt(26 * fmax(0, remaining - target_distance + .02)));
            get_dtor(TYPE(PACKED_VECTOR3_ARRAY))(&path);
        }
        double current = fmax(0, ipdot(cr_vector(agent, CR_GET_VELOCITY), direction));
        desired = ipmove(current, desired, (desired > current ? 9 : 13) * delta);
    }
    cr_set_vector(agent, CR_SET_VELOCITY, ipm(direction, desired));
    cr_publish(s, agent);
    r->processed++;
}
static void cr_velocity(CrRuntime *r, CrSlot *s, IpV safe) {
    void *agent = object_from_id(s->agent_id), *unit = object_from_id(s->unit_id);
    if (!agent || !unit || !cr_number(agent, CR_SYNC) || cr_meta(unit, &cr_garrison))
        return;
    void *tree = 0;
    ptrcall(cr_bind[CR_GET_TREE], agent, 0, &tree);
    if (!tree || cr_bool(tree, CR_TREE_PAUSED))
        return;
    cr_import(s, agent);
    s->delta = cr_number(agent, CR_PHYSICS_DELTA);
    double speed = cr_number(agent, CR_SPEED);
    s->speed = speed;
    if (cr_blocked(agent, speed)) {
        cr_set_vector(agent, CR_SET_VELOCITY, ipv(0, 0, 0));
        cr_passive(s, agent, ipv(0, 0, 0));
        return;
    }
    int64_t iteration = 0;
    const void *map_args[] = {&s->map};
    ptrcall(cr_bind[CR_ITERATION], cr_navigation, map_args, &iteration);
    if (iteration != r->projection_iteration)
        r->projection_valid = 0;
    IpT root;
    ptrcall(global_transform, unit, 0, &root);
    IpV origin = root.p;
    s->position = origin;
    int platform = cr_number(agent, CR_PLATFORM) != 0;
    int changing = isfinite(s->alignment) && fabs((double)origin.y - s->alignment) > .005;
    if (cr_zero(safe) && s->previous_valid &&
        memcmp(&s->previous.p, &origin, sizeof(origin)) == 0 && iteration == s->last_iteration &&
        !changing) {
        cr_passive(s, agent, ipv(0, 0, 0));
        return;
    }
    s->last_iteration = iteration;
    if (!platform && !r->elevated && origin.y > .01) {
        platform = 1;
        cr_write_bool(agent, CR_PLATFORM, 1);
    }
    double maximum = speed * s->delta;
    IpV candidate = ipa(origin, ipm(cr_limit(safe, speed), s->delta));
    IpV navigable = cr_navigation_position(r, s, agent, candidate, platform);
    s->alignment = navigable.y;
    IpV next = cr_clip(r, s, agent, origin, cr_toward(origin, navigable, maximum), speed, platform);
    IpV projection_delta = cr_flat(ips(navigable, candidate)), traveled = ips(next, origin);
    if (s->has_destination && s->recovery_left > 0 &&
        ipdot(projection_delta, projection_delta) > .000001 &&
        ipdot(traveled, traveled) < .000001 && !cr_occupied(r, s, agent, 0)) {
        IpV recovery =
            ipa(origin, ipm(cr_limit(cr_vector(agent, CR_GET_VELOCITY), speed), s->delta));
        IpV recovery_nav = cr_navigation_position(r, s, agent, recovery, platform),
            step = cr_clip(r, s, agent, origin, cr_toward(origin, recovery_nav, maximum), speed,
                           platform);
        IpV d = ips(step, origin);
        if (ipdot(d, d) > ipdot(traveled, traveled))
            next = step;
    }
    if (r->elevated) {
        next.y = (float)cr_height(r, next);
        s->alignment = next.y;
    }
    for (int i = 0; i < r->platform_count; i++) {
        void *body = object_from_id(r->platforms[i]);
        if (!body)
            continue;
        GDExtensionBool queued = 0;
        ptrcall(queued_for_deletion, body, 0, &queued);
        if (queued)
            continue;
        IpT transform;
        ptrcall(global_transform, body, 0, &transform);
        IpV distance = cr_flat(ips(next, transform.p));
        if (ipdot(distance, distance) > 4)
            continue;
        Value constructed = cr_call(body, CR_IS_CONSTRUCTED, 0, 0);
        GDExtensionBool complete = 0;
        if (get_type(&constructed) == TYPE(BOOL))
            to_type(TYPE(BOOL))(&complete, &constructed);
        variant_destroy(&constructed);
        if (!complete)
            continue;
        Value point;
        from_type(TYPE(VECTOR3))(&point, &next);
        const void *a[] = {&point};
        Value value = cr_call(body, CR_DECK_HEIGHT, a, 1);
        double height = 0;
        index_number(&value, &height);
        variant_destroy(&value);
        variant_destroy(&point);
        if (height > 0) {
            platform = 1;
            cr_write_bool(agent, CR_PLATFORM, 1);
        }
        next.y = (float)fmax(next.y, (double)transform.p.y + height);
        s->alignment = fmax(s->alignment, (double)transform.p.y + height);
    }
    IpV actual = ipm(ips(next, origin), 1.0 / fmax(s->delta, .001));
    if (iplen(ips(actual, safe)) > .1)
        cr_set_vector(agent, CR_FORCE_VELOCITY, actual);
    IpT advanced = root;
    advanced.p = next;
    IpV heading = cr_flat(actual);
    if (iplen(heading) >= .01 && (s->has_destination || !cr_aiming(unit))) {
        IpV direction = ipnorm(heading);
        if (s->previous_valid && !cr_teq(s->previous, advanced)) {
            s->window_count = 0;
            s->direction_total = ipv(0, 0, 0);
        }
        if (iplen(heading) >= .01) {
            s->direction_total = ipa(s->direction_total, direction);
            if (s->window_count == 10) {
                s->direction_total = ips(s->direction_total, s->window[0]);
                memmove(s->window, s->window + 1, 9 * sizeof(IpV));
                s->window_count = 9;
            }
            s->window[s->window_count++] = direction;
        }
        if (s->window_count == 10)
            direction = ipm(s->direction_total, .1);
        IpV target = ipa(advanced.p, direction);
        if (iplen(direction) >= .00001f && !cr_veq(target, advanced.p)) {
            IpV z = ipm(ipnorm(ips(target, advanced.p)), -1), x = ipnorm(ipv(z.z, 0, -z.x)),
                y = ipv(z.y * x.z - z.z * x.y, z.z * x.x - z.x * x.z, z.x * x.y - z.y * x.x);
            advanced.b = (IpB){{x.x, y.x, z.x, x.y, y.y, z.y, x.z, y.z, z.z}};
        }
    }
    if (memcmp(&advanced, &root, sizeof(root))) {
        const void *a[] = {&advanced};
        ptrcall(cr_bind[CR_SET_TRANSFORM], unit, a, 0);
    }
    s->position = next;
    if (r->elevated || platform)
        cr_set_real(agent, CR_SET_HEIGHT, (double)cr_project(r, s, next).y - next.y);
    s->previous = advanced;
    s->previous_valid = 1;
    cr_write(agent, CR_PREVIOUS, TYPE(TRANSFORM3D), &advanced);
    cr_write_number(agent, CR_ALIGNMENT, s->alignment);
    r->callbacks++;
    cr_passive(s, agent, actual);
}

/* ABI boundary and setup are below the hot loops. */
static void cr_clear_projection(CrRuntime *r) {
    ns_clear(&r->surface);
    for (int i = 0; i < r->polygon_count; i++)
        get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&r->polygons[i].polygon);
    free(r->polygons);
    free(r->cells);
    r->polygons = 0;
    r->cells = 0;
    r->polygon_count = r->cell_count = 0;
    if (r->has_heights)
        get_dtor(TYPE(PACKED_FLOAT32_ARRAY))(&r->heights);
    r->has_heights = 0;
}
static int cr_configure(CrRuntime *r, const void *cells, const void *height, int columns, int rows,
                        int elevated, int64_t iteration) {
    cr_clear_projection(r);
    r->projection_valid = 0;
    r->elevated = elevated;
    r->columns = columns;
    r->rows = rows;
    int64_t height_count = 0;
    sight_float_size((void *)height, 0, &height_count, 0);
    if (elevated && (columns <= 0 || rows <= 0 || columns > 32768 || rows > 32768 ||
                     height_count != (int64_t)(columns + 1) * (rows + 1)))
        return 0;
    if (elevated) {
        const void *a[] = {height};
        get_ctor(TYPE(PACKED_FLOAT32_ARRAY), 1)(&r->heights, a);
        r->has_heights = 1;
    }
    Value keys;
    get_ctor(TYPE(ARRAY), 0)(&keys, 0);
    cr_keys((void *)cells, 0, &keys, 0);
    int64_t count = count_array(&keys);
    if (count > 1000000) {
        get_dtor(TYPE(ARRAY))(&keys);
        return 0;
    }
    r->cells = calloc((size_t)count, sizeof(CrCell));
    int total = 0;
    for (int64_t i = 0; i < count; i++) {
        void *value = dictionary_lookup(cells, array_index(&keys, i));
        if (!value || get_type(value) != TYPE(ARRAY))
            continue;
        Value entries;
        to_type(TYPE(ARRAY))(&entries, value);
        total += (int)count_array(&entries);
        get_dtor(TYPE(ARRAY))(&entries);
    }
    if (total > 10000000 || total < 0) {
        get_dtor(TYPE(ARRAY))(&keys);
        return 0;
    }
    r->polygons = calloc((size_t)total, sizeof(CrPolygon));
    if ((count && !r->cells) || (total && !r->polygons)) {
        get_dtor(TYPE(ARRAY))(&keys);
        return 0;
    }
    for (int64_t i = 0; i < count; i++) {
        void *key = array_index(&keys, i);
        if (get_type(key) != TYPE(VECTOR2I))
            continue;
        int32_t coordinate[2];
        to_type(TYPE(VECTOR2I))(coordinate, key);
        void *value = dictionary_lookup(cells, key);
        if (!value || get_type(value) != TYPE(ARRAY))
            continue;
        Value entries;
        to_type(TYPE(ARRAY))(&entries, value);
        CrCell cell = {coordinate[0], coordinate[1], r->polygon_count, 0};
        for (int64_t j = 0; j < count_array(&entries); j++) {
            void *entry_value = array_index(&entries, j);
            if (get_type(entry_value) != TYPE(ARRAY))
                continue;
            Value entry;
            to_type(TYPE(ARRAY))(&entry, entry_value);
            int64_t n = count_array(&entry);
            if ((n == 2 || n == 3) &&
                get_type(array_index(&entry, 0)) == TYPE(PACKED_VECTOR2_ARRAY)) {
                CrPolygon *polygon = &r->polygons[r->polygon_count];
                double y = 0;
                int valid = index_number(array_index(&entry, 1), &y);
                if (valid && n == 3) {
                    valid = get_type(array_index(&entry, 2)) == TYPE(PLANE);
                    if (valid) {
                        to_type(TYPE(PLANE))(polygon->plane, array_index(&entry, 2));
                        valid = fabsf(polygon->plane[1]) >= .001f;
                    }
                }
                if (valid) {
                    to_type(TYPE(PACKED_VECTOR2_ARRAY))(&polygon->polygon, array_index(&entry, 0));
                    polygon->height = y;
                    polygon->slope = n == 3;
                    r->polygon_count++;
                    cell.count++;
                }
            }
            get_dtor(TYPE(ARRAY))(&entry);
        }
        get_dtor(TYPE(ARRAY))(&entries);
        r->cells[r->cell_count++] = cell;
    }
    get_dtor(TYPE(ARRAY))(&keys);
    qsort(r->cells, r->cell_count, sizeof(CrCell), cr_cell_compare);
    r->projection_iteration = iteration;
    r->projection_valid = 1;
    for (int i = 0; i < r->high_water; i++)
        r->slots[i].hint = -1;
    return 1;
}
static GDExtensionObjectPtr cr_create(void *userdata, GDExtensionBool notify) {
    (void)userdata;
    (void)notify;
    CrRuntime *r = calloc(1, sizeof(CrRuntime));
    if (!r)
        return 0;
    r->slots = calloc(CR_LIMIT, sizeof(CrSlot));
    if (!r->slots) {
        free(r);
        return 0;
    }
    r->maximum_radius = .9;
    r->frame = UINT64_MAX;
    void *owner = construct(&parent_name);
    set_instance(owner, &cr_class, r);
    return owner;
}
static void cr_free(void *userdata, void *instance) {
    (void)userdata;
    CrRuntime *r = instance;
    cr_clear_projection(r);
    free(r->slots);
    free(r);
}
static void cr_dispatch(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                        GDExtensionInt argc, GDExtensionVariantPtr ret,
                        GDExtensionCallError *error) {
    CrRuntime *r = instance;
    int operation = (int)(intptr_t)userdata;
    variant_nil(ret);
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (operation == 0) {
        int64_t invalid = -1;
        variant_destroy(ret);
        from_type(TYPE(INT))(ret, &invalid);
    }
    if (operation == 0 && argc == 3 && get_type(args[0]) == TYPE(OBJECT) &&
        get_type(args[1]) == TYPE(OBJECT) && get_type(args[2]) == TYPE(BOOL)) {
        void *agent = object_from_id(object_id(args[0])),
             *unit = object_from_id(object_id(args[1]));
        if (!agent || !unit || !object_cast(agent, agent_tag) || !object_cast(unit, node_tag))
            return;
        int index = 0;
        while (index < r->high_water && r->slots[index].live)
            index++;
        if (index == CR_LIMIT) {
            error->error = GDEXTENSION_CALL_OK;
            return;
        }
        if (index == r->high_water)
            r->high_water++;
        CrSlot *s = &r->slots[index];
        uint32_t generation = s->generation + 1;
        memset(s, 0, sizeof(*s));
        s->generation = generation;
        s->live = 1;
        s->unit_id = object_id(args[1]);
        s->agent_id = object_id(args[0]);
        GDExtensionBool vehicle = 0;
        to_type(TYPE(BOOL))(&vehicle, (void *)args[2]);
        s->vehicle = vehicle;
        s->hint = -1;
        s->alignment = INFINITY;
        s->last_iteration = 0;
        ptrcall(cr_bind[CR_GET_MAP], agent, 0, &s->map);
        s->radius = cr_real(agent, CR_GET_RADIUS);
        s->delta = cr_number(agent, CR_PHYSICS_DELTA);
        cr_import(s, agent);
        s->passive = cr_number(agent, CR_PASSIVE) != 0;
        s->previous_valid = cr_read(agent, CR_PREVIOUS, TYPE(TRANSFORM3D), &s->previous);
        s->alignment = cr_number(agent, CR_ALIGNMENT);
        int64_t handle = ((int64_t)generation << 16) | index;
        variant_destroy(ret);
        from_type(TYPE(INT))(ret, &handle);
        cr_rehash(r);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 1 && argc == 1 && get_type(args[0]) == TYPE(INT)) {
        int64_t handle;
        to_type(TYPE(INT))(&handle, (void *)args[0]);
        CrSlot *s = cr_slot(r, handle);
        if (s) {
            s->live = 0;
            cr_rehash(r);
        }
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 2 && argc == 3 && get_type(args[0]) == TYPE(ARRAY) &&
        get_type(args[1]) == TYPE(ARRAY) && get_type(args[2]) == TYPE(BOOL)) {
        Value units, platforms;
        to_type(TYPE(ARRAY))(&units, (void *)args[0]);
        to_type(TYPE(ARRAY))(&platforms, (void *)args[1]);
        GDExtensionBool valid;
        to_type(TYPE(BOOL))(&valid, (void *)args[2]);
        r->projection_valid = valid;
        uint64_t started = r->profiling ? profile_now() : 0;
        cr_begin(r, &units, &platforms);
        if (r->profiling) {
            r->profile[0] += profile_now() - started;
            r->profile[4]++;
        }
        get_dtor(TYPE(ARRAY))(&units);
        get_dtor(TYPE(ARRAY))(&platforms);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 3 && argc == 3 && get_type(args[0]) == TYPE(FLOAT) &&
        get_type(args[1]) == TYPE(FLOAT) && get_type(args[2]) == TYPE(BOOL)) {
        double delta, time;
        GDExtensionBool valid;
        to_type(TYPE(FLOAT))(&delta, (void *)args[0]);
        to_type(TYPE(FLOAT))(&time, (void *)args[1]);
        to_type(TYPE(BOOL))(&valid, (void *)args[2]);
        if (!(delta > 0) || !isfinite(delta) || !isfinite(time))
            return;
        r->simulation_time = time;
        r->projection_valid = valid;
        uint64_t started = r->profiling ? profile_now() : 0;
        for (int i = 0; i < r->high_water; i++) {
            if (!r->slots[i].live)
                continue;
            int64_t iteration = 0;
            const void *map_args[] = {&r->slots[i].map};
            ptrcall(cr_bind[CR_ITERATION], cr_navigation, map_args, &iteration);
            r->projection_valid = r->projection_valid && iteration == r->projection_iteration;
            break;
        }
        for (int i = 0; i < r->high_water; i++)
            if (r->slots[i].live)
                cr_tick_slot(r, &r->slots[i], delta);
        if (r->profiling) {
            r->profile[1] += profile_now() - started;
            r->profile[5]++;
        }
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 4 && argc == 2 && get_type(args[0]) == TYPE(VECTOR3) &&
        get_type(args[1]) == TYPE(INT)) {
        int64_t handle;
        IpV velocity;
        to_type(TYPE(INT))(&handle, (void *)args[1]);
        to_type(TYPE(VECTOR3))(&velocity, (void *)args[0]);
        CrSlot *s = cr_slot(r, handle);
        uint64_t started = r->profiling ? profile_now() : 0;
        if (s) {
            cr_velocity(r, s, velocity);
            if (r->profiling) {
                r->profile[2] += profile_now() - started;
                r->profile[6]++;
            }
        }
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 5 && argc == 6 && get_type(args[0]) == TYPE(DICTIONARY) &&
        get_type(args[1]) == TYPE(PACKED_FLOAT32_ARRAY) && get_type(args[2]) == TYPE(INT) &&
        get_type(args[3]) == TYPE(INT) && get_type(args[4]) == TYPE(BOOL) &&
        get_type(args[5]) == TYPE(INT)) {
        Value cells, height;
        int64_t columns, rows, iteration;
        GDExtensionBool elevated;
        to_type(TYPE(DICTIONARY))(&cells, (void *)args[0]);
        to_type(TYPE(PACKED_FLOAT32_ARRAY))(&height, (void *)args[1]);
        to_type(TYPE(INT))(&columns, (void *)args[2]);
        to_type(TYPE(INT))(&rows, (void *)args[3]);
        to_type(TYPE(BOOL))(&elevated, (void *)args[4]);
        to_type(TYPE(INT))(&iteration, (void *)args[5]);
        GDExtensionBool ok =
            cr_configure(r, &cells, &height, (int)columns, (int)rows, elevated, iteration);
        get_dtor(TYPE(DICTIONARY))(&cells);
        get_dtor(TYPE(PACKED_FLOAT32_ARRAY))(&height);
        variant_destroy(ret);
        from_type(TYPE(BOOL))(ret, &ok);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 6 && argc == 2 && get_type(args[0]) == TYPE(VECTOR3) &&
        get_type(args[1]) == TYPE(INT)) {
        int64_t handle;
        IpV point;
        to_type(TYPE(INT))(&handle, (void *)args[1]);
        to_type(TYPE(VECTOR3))(&point, (void *)args[0]);
        CrSlot *s = cr_slot(r, handle);
        if (!s)
            return;
        int64_t iteration = 0;
        const void *map_args[] = {&s->map};
        ptrcall(cr_bind[CR_ITERATION], cr_navigation, map_args, &iteration);
        if (iteration != r->projection_iteration)
            r->projection_valid = 0;
        IpV result = cr_project(r, s, point);
        variant_destroy(ret);
        from_type(TYPE(VECTOR3))(ret, &result);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 7 && argc == 0) {
        Value array;
        get_ctor(TYPE(ARRAY), 0)(&array, 0);
        int64_t values[] = {(int64_t)r->processed, (int64_t)r->callbacks,
                            (int64_t)r->server_projections, r->body_count};
        for (int i = 0; i < 4; i++) {
            Value v;
            from_type(TYPE(INT))(&v, &values[i]);
            const void *a[] = {&v};
            array_append(&array, a, 0, 1);
            variant_destroy(&v);
        }
        variant_destroy(ret);
        from_type(TYPE(ARRAY))(ret, &array);
        get_dtor(TYPE(ARRAY))(&array);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 8 && argc == 1 && get_type(args[0]) == TYPE(INT)) {
        int64_t handle;
        to_type(TYPE(INT))(&handle, (void *)args[0]);
        CrSlot *s = cr_slot(r, handle);
        void *agent = s ? object_from_id(s->agent_id) : 0;
        if (agent) {
            s->speed = cr_number(agent, CR_SPEED);
            s->ghost = cr_number(agent, CR_GHOST) != 0;
            s->radius = cr_real(agent, CR_GET_RADIUS);
            r->maximum_step = fmax(r->maximum_step, s->speed * s->delta);
        }
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 9 && argc == 1 && get_type(args[0]) == TYPE(BOOL)) {
        GDExtensionBool enabled;
        to_type(TYPE(BOOL))(&enabled, (void *)args[0]);
        r->profiling = enabled && profile_time && profile_clock;
        variant_destroy(ret);
        profile_array(r->profile, 8, ret);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 10 && argc == 4 && get_type(args[0]) == TYPE(PACKED_VECTOR3_ARRAY) &&
        get_type(args[1]) == TYPE(ARRAY) && get_type(args[2]) == TYPE(TRANSFORM3D) &&
        get_type(args[3]) == TYPE(INT)) {
        Value vertices, polygons;
        IpT transform;
        int64_t iteration, count = 0;
        to_type(TYPE(PACKED_VECTOR3_ARRAY))(&vertices, (void *)args[0]);
        to_type(TYPE(ARRAY))(&polygons, (void *)args[1]);
        to_type(TYPE(TRANSFORM3D))(&transform, (void *)args[2]);
        to_type(TYPE(INT))(&iteration, (void *)args[3]);
        cr_vectors_size(&vertices, 0, &count, 0);
        GDExtensionBool configured = 0;
        if (count > 0 && iteration == r->projection_iteration)
            configured = ns_configure(&r->surface, (const IpV *)cr_vector_read(&vertices, 0), count,
                                      &polygons, transform, iteration);
        else
            ns_clear(&r->surface);
        get_dtor(TYPE(PACKED_VECTOR3_ARRAY))(&vertices);
        get_dtor(TYPE(ARRAY))(&polygons);
        variant_destroy(ret);
        from_type(TYPE(BOOL))(ret, &configured);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
    if (operation == 11 && argc == 0) {
        uint64_t values[] = {(uint64_t)r->surface.polygon_count,
                             (uint64_t)r->surface.node_count,
                             r->surface.queries,
                             r->surface.tested,
                             (uint64_t)r->surface.iteration,
                             r->surface.elapsed};
        variant_destroy(ret);
        profile_array(values, 6, ret);
        error->error = GDEXTENSION_CALL_OK;
        return;
    }
}
static int crowd_load(GDExtensionInterfaceGetProcAddress proc) {
    cr_singleton = (GDExtensionInterfaceGlobalGetSingleton)proc("global_get_singleton");
    cr_vector_read = (GDExtensionInterfacePackedVector3ArrayOperatorIndexConst)proc(
        "packed_vector3_array_operator_index_const");
    return cr_singleton && cr_vector_read;
}
static void crowd_initialize(void) {
    name_new(&cr_class, "CopperfinCrowdRuntime");
    name_new(&cr_engine_name, "Engine");
    name_new(&cr_navigation_name, "NavigationServer3D");
    name_new(&cr_geometry_name, "Geometry2D");
    name_new(&cr_tree_name, "Node");
    name_new(&cr_scene_name, "SceneTree");
    const char *methods[] = {"bind_agent",    "unbind_agent",      "begin_frame",
                             "step",          "receive_velocity",  "configure_projection",
                             "project_point", "statistics",        "refresh_agent",
                             "profile",       "configure_surface", "surface_statistics"};
    const char *fields[] = {"speed",
                            "ghosted",
                            "_has_destination",
                            "_command_revision",
                            "_synchronized",
                            "_progress_elapsed",
                            "_progress_position",
                            "_recovery_left",
                            "_recovery_direction",
                            "_recovery_checked",
                            "_ground_alignment_height",
                            "_uses_platform_height",
                            "_physics_delta",
                            "_passive_movement_detected",
                            "_previously_set_global_transform_of_unit",
                            "_last_navigation_iteration",
                            "_exit_clearance_target",
                            "_exit_clearance_until",
                            "aim_target",
                            "hp",
                            "paused",
                            ""};
    const char *helpers[] = {
        "_finish_command", "call_deferred", "emit_signal", "_abilities_prevent_movement",
        "is_constructed",  "deck_height",   "type"};
    const char *arguments[] = {"agent",     "unit",     "vehicle",          "units",    "platforms",
                               "delta",     "time",     "projection_valid", "point",    "handle",
                               "cells",     "heights",  "columns",          "rows",     "elevated",
                               "iteration", "velocity", "enabled",          "vertices", "polygons",
                               "transform"};
    for (int i = 0; i < 12; i++)
        name_new(&cr_method[i], methods[i]);
    for (int i = 0; i < 22; i++)
        name_new(&cr_field[i], fields[i]);
    for (int i = 0; i < 7; i++)
        name_new(&cr_helpers[i], helpers[i]);
    for (int i = 0; i < 21; i++)
        name_new(&cr_args[i], arguments[i]);
    name_new(&cr_garrison, "garrison_host");
    name_new(&cr_breach, "breach_pending");
    name_new(&cr_movement_done, "movement_finished");
    name_new(&cr_passive_start, "passive_movement_started");
    name_new(&cr_passive_stop, "passive_movement_finished");
    cr_initialized = 1;
    const char *bind_names[] = {"get_target_position",
                                "get_next_path_position",
                                "is_navigation_finished",
                                "get_final_position",
                                "get_current_navigation_path",
                                "get_current_navigation_path_index",
                                "get_velocity",
                                "set_velocity",
                                "set_velocity_forced",
                                "get_radius",
                                "get_max_speed",
                                "set_max_speed",
                                "get_target_desired_distance",
                                "get_path_height_offset",
                                "set_path_height_offset",
                                "get_avoidance_priority",
                                "set_avoidance_priority",
                                "get_navigation_map",
                                "map_get_closest_point",
                                "map_get_iteration_id",
                                "set_global_transform",
                                "is_point_in_polygon",
                                "has_meta",
                                "get_parent",
                                "can_process",
                                "is_physics_processing",
                                "get_physics_frames",
                                "set_target_position",
                                "get_tree",
                                "is_paused"};
    const uint64_t hashes[] = {3360562783, 3783033775, 2240911060, 3783033775, 497664490,
                               3905245786, 3783033775, 3460891852, 3460891852, 1740695150,
                               1740695150, 373806689,  1740695150, 1740695150, 373806689,
                               1740695150, 373806689,  2944877500, 2056183332, 2198884583,
                               2952846383, 738277916,  2619796661, 3160264692, 36873697,
                               36873697,   3905245786, 3460891852, 2958820483, 36873697};
    for (int i = 0; i < 30; i++) {
        Value name;
        name_new(&name, bind_names[i]);
        Value *klass =
            i < 18 || i == 27
                ? &agent_name
                : (i < 20
                       ? &cr_navigation_name
                       : (i == 20 ? &node_name
                                  : (i == 21 ? &cr_geometry_name
                                             : (i == 22 ? &object_name
                                                        : (i == 26 ? &cr_engine_name
                                                                   : (i == 29 ? &cr_scene_name
                                                                              : &cr_tree_name))))));
        cr_bind[i] = method_bind(klass, &name, hashes[i]);
        get_dtor(TYPE(STRING_NAME))(&name);
        if (!cr_bind[i])
            return;
    }
    cr_navigation = cr_singleton(&cr_navigation_name);
    cr_geometry = cr_singleton(&cr_geometry_name);
    cr_engine = cr_singleton(&cr_engine_name);
    Value keys_name;
    name_new(&keys_name, "keys");
    cr_keys = get_builtin(TYPE(DICTIONARY), &keys_name, 4144163970LL);
    get_dtor(TYPE(STRING_NAME))(&keys_name);
    cr_vectors_size = get_builtin(TYPE(PACKED_VECTOR3_ARRAY), &size_name, 3173160232LL);
    if (!cr_keys || !cr_vectors_size || !cr_navigation || !cr_geometry || !cr_engine)
        return;
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = cr_create;
    info.free_instance_func = cr_free;
    register_class(library, &cr_class, &parent_name, &info);
    cr_registered = 1;
    const int counts[] = {3, 1, 3, 3, 2, 6, 2, 0, 1, 1, 4, 0};
    const GDExtensionVariantType types[12][6] = {
        {TYPE(OBJECT), TYPE(OBJECT), TYPE(BOOL)},
        {TYPE(INT)},
        {TYPE(ARRAY), TYPE(ARRAY), TYPE(BOOL)},
        {TYPE(FLOAT), TYPE(FLOAT), TYPE(BOOL)},
        {TYPE(VECTOR3), TYPE(INT)},
        {TYPE(DICTIONARY), TYPE(PACKED_FLOAT32_ARRAY), TYPE(INT), TYPE(INT), TYPE(BOOL), TYPE(INT)},
        {TYPE(VECTOR3), TYPE(INT)},
        {},
        {TYPE(INT)},
        {TYPE(BOOL)},
        {TYPE(PACKED_VECTOR3_ARRAY), TYPE(ARRAY), TYPE(TRANSFORM3D), TYPE(INT)},
        {}};
    const GDExtensionVariantType outputs[] = {TYPE(INT), TYPE(NIL),   TYPE(NIL),     TYPE(NIL),
                                              TYPE(NIL), TYPE(BOOL),  TYPE(VECTOR3), TYPE(ARRAY),
                                              TYPE(NIL), TYPE(ARRAY), TYPE(BOOL),    TYPE(ARRAY)};
    const int argument_names[12][6] = {
        {0, 1, 2}, {9}, {3, 4, 7}, {5, 6, 7}, {16, 9},          {10, 11, 12, 13, 14, 15},
        {8, 9},    {},  {9},       {17},      {18, 19, 20, 15}, {}};
    for (int i = 0; i < 12; i++) {
        GDExtensionPropertyInfo arguments_info[6];
        GDExtensionClassMethodArgumentMetadata metadata[6] = {0};
        for (int j = 0; j < counts[i]; j++)
            arguments_info[j] = (GDExtensionPropertyInfo){
                types[i][j], &cr_args[argument_names[i][j]], &empty_name, 0, &empty_string, 6};
        GDExtensionPropertyInfo output = {outputs[i], &empty_name,   &empty_name,
                                          0,          &empty_string, 6};
        GDExtensionClassMethodInfo method = {0};
        method.name = &cr_method[i];
        method.method_userdata = (void *)(intptr_t)i;
        method.call_func = cr_dispatch;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.argument_count = counts[i];
        method.arguments_info = arguments_info;
        method.arguments_metadata = metadata;
        method.has_return_value = outputs[i] != TYPE(NIL);
        method.return_value_info = method.has_return_value ? &output : 0;
        register_method(library, &cr_class, &method);
    }
}
static void crowd_deinitialize(void) {
    if (!cr_initialized)
        return;
    if (cr_registered)
        unregister_class(library, &cr_class);
    cr_registered = 0;
    Value *names[] = {&cr_class,         &cr_engine_name,   &cr_navigation_name, &cr_geometry_name,
                      &cr_tree_name,     &cr_scene_name,    &cr_garrison,        &cr_breach,
                      &cr_movement_done, &cr_passive_start, &cr_passive_stop};
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++)
        get_dtor(TYPE(STRING_NAME))(names[i]);
    for (int i = 0; i < 12; i++)
        get_dtor(TYPE(STRING_NAME))(&cr_method[i]);
    for (int i = 0; i < 22; i++)
        get_dtor(TYPE(STRING_NAME))(&cr_field[i]);
    for (int i = 0; i < 7; i++)
        get_dtor(TYPE(STRING_NAME))(&cr_helpers[i]);
    for (int i = 0; i < 21; i++)
        get_dtor(TYPE(STRING_NAME))(&cr_args[i]);
    cr_initialized = 0;
}
