/* Native observation searches and obstruction geometry. Gameplay facts remain
 * live at query time. Only blocker geometry and script type relationships are
 * retained; successful observer hints are revalidated, never cached results. */
typedef struct CiIndex CiIndex;
typedef struct {
    uint64_t id;
    IpV centre;
    double radius, height;
    uint32_t visited;
} CvBlock;
typedef struct {
    uint64_t player, target, witness;
} CvHint;
typedef struct {
    uint64_t script;
    int unit;
} CvType;
typedef struct {
    uint64_t field, unit_script;
    Value terrain;
    int has_terrain;
    CvBlock *blocks;
    CrCell *cells;
    int *links;
    int block_count, cell_count, link_count;
    uint32_t epoch;
    CvHint hints[2048];
    CvType types[256];
    uint64_t statistics[5];
    uint64_t exploration[3]; /* observer batches, candidate cells, point queries */
    uint64_t combat[3];      /* requests, resolved natively, fallback */
    CiIndex *index;
    int profiling;
    uint64_t profile[10]; /* configure/observed/point/line/fire us, then call counts */
} CvRuntime;
typedef struct {
    int columns, rows, open;
    Value heights, flags;
    const float *height;
    const uint8_t *flag;
    float size[2];
    double tier;
} CvHeight;
static int native_combat_fire(CvRuntime *r, void *source, void *target, const void *cells,
                              double reach, double step);
static void native_combat_initialize(void);
static void native_combat_deinitialize(void);
static void ci_free(CvRuntime *r);
static int ci_active(CvRuntime *r);
static void ci_clear(CvRuntime *r);
static void ci_rebuild(CvRuntime *r, const void *observers, double delta, void *output);
static void ci_nearby(CvRuntime *r, IpV point, double radius, void *include, void *exclude,
                      void *output);
static int ci_observe_scan(CvRuntime *r, void *player, void *target, IpV point, double reach,
                           double step, CvHint *hint);
static void ci_statistics(CvRuntime *r, void *ret);
static Value cv_class, cv_methods[15], cv_arguments[18], cv_fields[17], cv_helpers[7];
static Value cv_keys[4], cv_groups[2], cv_obstacle_path;
static GDExtensionMethodBindPtr cv_bind[8];
static GDExtensionPtrBuiltInMethod cv_vectors_size;
static GDExtensionInterfacePackedVector2ArrayOperatorIndexConst cv_vector_read;
static int cv_initialized, cv_registered;
enum {
    CV_SIGHT,
    CV_HP,
    CV_PROGRESS,
    CV_PLAYER,
    CV_TEAM,
    CV_TRAIT,
    CV_FOOTPRINT,
    CV_COLUMNS,
    CV_ROWS,
    CV_HEIGHTS,
    CV_FLAGS,
    CV_TIER,
    CV_SIZE,
    CV_FLIGHT,
    CV_MOVEMENT_DOMAIN,
    CV_MATCH,
    CV_UNUSED
};
enum { CV_BASE_SCRIPT, CV_CONSTRUCTED, CV_EFFECTIVE, CV_COMBAT_DOMAIN, CV_ALLIED, CV_REFRESH };
enum {
    CV_INSIDE,
    CV_HAS_METHOD,
    CV_GROUP,
    CV_ANCESTOR,
    CV_GET_SCRIPT,
    CV_NODE,
    CV_CLOSEST_SEGMENT,
    CV_READY
};

static int cv_read(const void *object, const Value *field, Value *result) {
    GDExtensionBool valid = 0;
    get_named(object, field, result, &valid);
    return valid;
}
static int cv_field(void *object, int field, Value *result) {
    Value v;
    cr_variant(object, &v);
    int valid = cv_read(&v, &cv_fields[field], result);
    variant_destroy(&v);
    return valid;
}
static int cv_number(void *object, int field, double *out) {
    int scalar =
        field == CV_HP
            ? US_HP
            : (field == CV_SIGHT ? US_SIGHT : (field == CV_PROGRESS ? US_CONSTRUCTION : -1));
    int present = 0;
    if (scalar >= 0 && native_unit_scalar(object, scalar, out, &present))
        return present && isfinite(*out);
    Value v;
    int valid = cv_field(object, field, &v);
    int ok = valid && index_number(&v, out);
    variant_destroy(&v);
    return ok;
}
static int cv_has(void *object, const Value *name) {
    const void *args[] = {name};
    GDExtensionBool result = 0;
    ptrcall(cv_bind[CV_HAS_METHOD], object, args, &result);
    return result;
}
static Value cv_call(void *object, int helper, const void **arguments, int count) {
    Value v, result;
    cr_variant(object, &v);
    GDExtensionCallError error = {0};
    variant_call(&v, &cv_helpers[helper], arguments, count, &result, &error);
    variant_destroy(&v);
    return result;
}
static int cv_group(void *object, int group) {
    if (!object)
        return 0;
    const void *args[] = {&cv_groups[group]};
    GDExtensionBool result = 0;
    ptrcall(cv_bind[CV_GROUP], object, args, &result);
    return result;
}
static int cv_live(void *node, int inside) {
    if (!node || !object_cast(node, node_tag))
        return 0;
    GDExtensionBool queued = 0;
    ptrcall(queued_for_deletion, node, 0, &queued);
    GDExtensionBool in_tree = 1;
    if (inside)
        ptrcall(cv_bind[CV_INSIDE], node, 0, &in_tree);
    return !queued && in_tree;
}
static int cv_inside(void *node) {
    GDExtensionBool inside = 0;
    ptrcall(cv_bind[CV_INSIDE], node, 0, &inside);
    return inside;
}
static int cv_unit(CvRuntime *r, void *node) {
    Value script;
    variant_nil(&script);
    ptrcall(cv_bind[CV_GET_SCRIPT], node, 0, &script);
    uint64_t first = get_type(&script) == TYPE(OBJECT) ? object_id(&script) : 0;
    if (!first) {
        variant_destroy(&script);
        return 0;
    }
    unsigned hash = cr_hash(first) & 255;
    CvType *cached = &r->types[hash];
    if (cached->script == first) {
        variant_destroy(&script);
        return cached->unit;
    }
    int unit = 0;
    for (int depth = 0; depth < 64 && get_type(&script) == TYPE(OBJECT); depth++) {
        uint64_t id = object_id(&script);
        if (id == r->unit_script) {
            unit = 1;
            break;
        }
        void *resource = object_from_id(id);
        if (!resource)
            break;
        Value next = cv_call(resource, CV_BASE_SCRIPT, 0, 0);
        variant_destroy(&script);
        script = next;
    }
    variant_destroy(&script);
    *cached = (CvType){first, unit};
    return unit;
}
static void *cv_object_field(void *node, int field, int *present) {
    Value v;
    int valid = cv_field(node, field, &v);
    void *result = valid && get_type(&v) == TYPE(OBJECT) ? object_from_id(object_id(&v)) : 0;
    if (present)
        *present = valid;
    variant_destroy(&v);
    return result;
}
static void *cv_trait(void *node) {
    void *trait = cv_object_field(node, CV_TRAIT, 0);
    if (trait)
        return trait;
    Value v;
    cr_variant(node, &v);
    GDExtensionCallError error = {0};
    Value value;
    variant_call(&v, &trait_method, 0, 0, &value, &error);
    trait = error.error == GDEXTENSION_CALL_OK && get_type(&value) == TYPE(OBJECT)
                ? object_from_id(object_id(&value))
                : 0;
    variant_destroy(&value);
    variant_destroy(&v);
    return trait;
}
static double cv_domain(void *node, int unit) {
    double resident = -1;
    int present = 0;
    if (unit && native_unit_domain(node, &resident, &present))
        return present ? resident : -1;
    int flight = 0;
    if (unit)
        cv_object_field(node, CV_FLIGHT, &flight);
    if (!unit || flight) {
        if (cv_has(node, &cv_helpers[CV_COMBAT_DOMAIN])) {
            Value result = cv_call(node, CV_COMBAT_DOMAIN, 0, 0);
            double n = -1;
            index_number(&result, &n);
            variant_destroy(&result);
            return n;
        }
        double n = -1;
        cv_number(node, CV_MOVEMENT_DOMAIN, &n);
        return n;
    }
    void *trait = cv_trait(node);
    if (!trait)
        return -1;
    Value v;
    cr_variant(trait, &v);
    double domain = number_property(&v, &domain_name);
    variant_destroy(&v);
    return domain;
}
static int cv_constructed(CvRuntime *r, void *node, int unit) {
    if (unit) {
        double progress;
        if (cv_number(node, CV_PROGRESS, &progress))
            return progress >= 1;
    }
    if (!cv_has(node, &cv_helpers[CV_CONSTRUCTED]))
        return 1;
    Value result = cv_call(node, CV_CONSTRUCTED, 0, 0);
    GDExtensionBool constructed = 0;
    if (get_type(&result) == TYPE(BOOL))
        to_type(TYPE(BOOL))(&constructed, &result);
    variant_destroy(&result);
    return constructed;
}
static void *cv_meta_host(void *node) {
    if (!node || !cr_meta(node, &cr_garrison))
        return 0;
    Value result;
    Value object;
    cr_variant(node, &object);
    Value key;
    from_type(TYPE(STRING_NAME))(&key, &cr_garrison);
    const void *values[] = {&key};
    GDExtensionCallError error = {0};
    variant_call(&object, &index_meta_method, values, 1, &result, &error);
    void *host = error.error == GDEXTENSION_CALL_OK && get_type(&result) == TYPE(OBJECT)
                     ? object_from_id(object_id(&result))
                     : 0;
    variant_destroy(&result);
    variant_destroy(&object);
    variant_destroy(&key);
    return host;
}
static double cv_radius(void *node) {
    if (!node)
        return 0;
    double resident = 0;
    if (native_unit_radius(node, &resident))
        return resident;
    Value object;
    cr_variant(node, &object);
    double radius = number_property(&object, &radius_name);
    variant_destroy(&object);
    return radius;
}
static int cv_open_height(CvRuntime *r, CvHeight *h) {
    if (h->open)
        return 1;
    if (!r->has_terrain)
        return 0;
    void *model = object_from_id(object_id(&r->terrain));
    if (!model)
        return 0;
    double columns, rows, tier = 3;
    Value heights, flags;
    if (!cv_number(model, CV_COLUMNS, &columns) || !cv_number(model, CV_ROWS, &rows) ||
        columns <= 0 || rows <= 0 || columns > 32768 || rows > 32768)
        return 0;
    int valid = cv_field(model, CV_HEIGHTS, &heights);
    if (!valid || get_type(&heights) != TYPE(PACKED_FLOAT32_ARRAY)) {
        variant_destroy(&heights);
        return 0;
    }
    valid = cv_field(model, CV_FLAGS, &flags);
    if (!valid || get_type(&flags) != TYPE(PACKED_BYTE_ARRAY)) {
        variant_destroy(&flags);
        variant_destroy(&heights);
        return 0;
    }
    to_type(TYPE(PACKED_FLOAT32_ARRAY))(&h->heights, &heights);
    to_type(TYPE(PACKED_BYTE_ARRAY))(&h->flags, &flags);
    variant_destroy(&heights);
    variant_destroy(&flags);
    int64_t height_count = 0, flag_count = 0;
    sight_float_size(&h->heights, 0, &height_count, 0);
    sight_byte_size(&h->flags, 0, &flag_count, 0);
    h->columns = (int)columns;
    h->rows = (int)rows;
    if (height_count < (int64_t)(h->columns + 1) * (h->rows + 1) ||
        flag_count < (int64_t)h->columns * h->rows) {
        get_dtor(TYPE(PACKED_FLOAT32_ARRAY))(&h->heights);
        get_dtor(TYPE(PACKED_BYTE_ARRAY))(&h->flags);
        return 0;
    }
    h->height = sight_float_index(&h->heights, 0);
    h->flag = sight_byte_index(&h->flags, 0);
    h->open = 1;
    cv_number(model, CV_TIER, &tier);
    h->tier = tier;
    Value size;
    valid = cv_field(model, CV_SIZE, &size);
    if (valid && get_type(&size) == TYPE(VECTOR2))
        to_type(TYPE(VECTOR2))(h->size, &size);
    else {
        h->size[0] = (float)columns * .5f;
        h->size[1] = (float)rows * .5f;
    }
    variant_destroy(&size);
    return 1;
}
static void cv_close_height(CvHeight *h) {
    if (h->open) {
        get_dtor(TYPE(PACKED_FLOAT32_ARRAY))(&h->heights);
        get_dtor(TYPE(PACKED_BYTE_ARRAY))(&h->flags);
        h->open = 0;
    }
}
static double cv_height(CvHeight *h, IpV p) {
    double x = ipclamp((double)p.x / .5, 0, h->columns), z = ipclamp((double)p.z / .5, 0, h->rows);
    int i = (int)fmin((int)x, h->columns - 1), j = (int)fmin((int)z, h->rows - 1),
        stride = h->columns + 1, k = j * stride + i;
    return ipmix(ipmix(h->height[k], h->height[k + 1], x - i),
                 ipmix(h->height[k + stride], h->height[k + stride + 1], x - i), z - j);
}
static int cv_plateau(CvRuntime *r, CvHeight *h, void *observer, IpV position, void *host) {
    if (!r->has_terrain || host)
        return 0;
    void *trait = cv_trait(observer);
    if (!trait)
        return 0;
    void *match = cv_object_field(observer, CV_MATCH, 0);
    GDExtensionBool ready = 0;
    if (match)
        ptrcall(cv_bind[CV_READY], match, 0, &ready);
    if (!ready)
        return 0;
    Value v;
    cr_variant(trait, &v);
    double domain = number_property(&v, &domain_name);
    variant_destroy(&v);
    if (domain != 1) /* MatchConstants.Navigation.Domain.TERRAIN */
        return 0;
    if (!cv_open_height(r, h) || position.x < 0 || position.z < 0 || position.x >= h->size[0] ||
        position.z >= h->size[1])
        return 0;
    int i = (int)fmin((int)(position.x / .5f), h->columns - 1),
        j = (int)fmin((int)(position.z / .5f), h->rows - 1), stride = h->columns + 1,
        k = j * stride + i;
    int flag = h->flag[j * h->columns + i];
    if (flag & (1 | 2 | 8 | 16 | 32 | 64))
        return 0;
    float height = h->height[k];
    return height >= h->tier * .75 && cr_eq(height, h->height[k + 1]) &&
           cr_eq(height, h->height[k + stride]) && cr_eq(height, h->height[k + stride + 1]);
}
static int cv_terrain(CvRuntime *r, CvHeight *h, void *observer, IpV origin, IpV point,
                      void *target, int shots) {
    if (!r->has_terrain || cv_domain(observer, cv_unit(r, observer)) == 0)
        return 1;
    if (!cv_open_height(r, h))
        return 0;
    int airborne = target && cv_domain(target, cv_unit(r, target)) == 0;
    double source_height = cv_height(h, origin), target_height = cv_height(h, point);
    IpV flat = cr_flat(ips(origin, point));
    if (!shots && !airborne && target_height - source_height >= 1.5 && iplen(flat) > 1.5)
        return 0;
    IpV start = ipv(origin.x, source_height + .8, origin.z),
        end = airborne ? point : ipv(point.x, target_height + .8, point.z);
    r->statistics[4]++;
    return terrain_sight_core(&r->terrain, (const float *)&start, (const float *)&end, !shots);
}
static int cv_cylinder(IpV origin, IpV end, CvBlock *block) {
    IpV d = ips(end, origin), o = ips(origin, block->centre);
    double a = (double)d.x * d.x + (double)d.z * d.z,
           b = 2 * ((double)o.x * d.x + (double)o.z * d.z),
           c = (double)o.x * o.x + (double)o.z * o.z - block->radius * block->radius;
    double low = 0, high = 1;
    if (a < .000001) {
        if (c > 0)
            return 0;
    } else {
        double disc = b * b - 4 * a * c;
        if (disc < 0)
            return 0;
        double root = sqrt(disc);
        low = fmax(low, (-b - root) / (2 * a));
        high = fmin(high, (-b + root) / (2 * a));
    }
    if (fabs(d.y) < .000001) {
        if (o.y < 0 || o.y > block->height)
            return 0;
    } else {
        double bottom = -(double)o.y / d.y, top = (block->height - o.y) / d.y;
        low = fmax(low, fmin(bottom, top));
        high = fmin(high, fmax(bottom, top));
    }
    return low <= high;
}
static void cv_prepare(CvRuntime *r) {
    void *field = object_from_id(r->field);
    if (field) {
        Value value = cv_call(field, CV_REFRESH, 0, 0);
        variant_destroy(&value);
    }
}
static int cv_line(CvRuntime *r, IpV origin, IpV end, void *source, void *target, int prepare) {
    if (!isfinite(origin.x) || !isfinite(origin.y) || !isfinite(origin.z) || !isfinite(end.x) ||
        !isfinite(end.y) || !isfinite(end.z) || fabs(origin.x) > 1000000 ||
        fabs(origin.z) > 1000000 || fabs(end.x) > 1000000 || fabs(end.z) > 1000000)
        return 0;
    if (prepare)
        cv_prepare(r);
    r->statistics[2]++;
    void *host = cv_meta_host(source);
    if (host)
        source = host;
    uint64_t source_id = 0, target_id = 0;
    Value value;
    if (source) {
        cr_variant(source, &value);
        source_id = object_id(&value);
        variant_destroy(&value);
    }
    if (target) {
        cr_variant(target, &value);
        target_id = object_id(&value);
        variant_destroy(&value);
    }
    uint32_t epoch = ++r->epoch;
    if (!epoch) {
        for (int i = 0; i < r->block_count; i++)
            r->blocks[i].visited = 0;
        epoch = ++r->epoch;
    }
    int lx = (int)floor(fmin(origin.x, end.x) / 12), hx = (int)floor(fmax(origin.x, end.x) / 12),
        lz = (int)floor(fmin(origin.z, end.z) / 12), hz = (int)floor(fmax(origin.z, end.z) / 12);
    for (int x = lx; x <= hx; x++)
        for (int z = lz; z <= hz; z++) {
            CrCell key = {x, z, 0, 0};
            CrCell *cell = r->cell_count ? bsearch(&key, r->cells, r->cell_count, sizeof(CrCell),
                                                   cr_cell_compare)
                                         : 0;
            if (!cell)
                continue;
            for (int i = cell->first; i < cell->first + cell->count; i++) {
                CvBlock *block = &r->blocks[r->links[i]];
                if (block->visited == epoch || block->id == source_id || block->id == target_id)
                    continue;
                void *body = object_from_id(block->id);
                if (!cv_live(body, 0))
                    continue;
                GDExtensionBool ancestor = 0;
                const void *args[] = {&source};
                if (source)
                    ptrcall(cv_bind[CV_ANCESTOR], body, args, &ancestor);
                if (ancestor)
                    continue;
                args[0] = &target;
                if (target)
                    ptrcall(cv_bind[CV_ANCESTOR], body, args, &ancestor);
                if (ancestor)
                    continue;
                block->visited = epoch;
                if (!cv_constructed(r, body, cv_unit(r, body)))
                    continue;
                if (cv_cylinder(origin, end, block))
                    return 0;
            }
        }
    return 1;
}
static int cv_point(CvRuntime *r, void *observer, IpV point, void *target) {
    r->statistics[1]++;
    if (!cv_live(observer, 0) || !cv_inside(observer))
        return 0;
    double sight, hp;
    if (!cv_number(observer, CV_SIGHT, &sight) || !cv_number(observer, CV_HP, &hp) || hp <= 0)
        return 0;
    int unit = cv_unit(r, observer);
    if (!cv_constructed(r, observer, unit))
        return 0;
    IpT root;
    ptrcall(global_transform, observer, 0, &root);
    IpV origin = ipa(root.p, ipv(0, .8, 0));
    void *host = cv_meta_host(observer);
    IpV ground_target = ips(point, ipv(0, .8, 0));
    double reach = sight;
    CvHeight heights = {0};
    if (unit) {
        if ((double)root.p.y - ground_target.y >= 1.5 &&
            cv_plateau(r, &heights, observer, root.p, host))
            reach *= 1.3;
    } else if (cv_has(observer, &cv_helpers[CV_EFFECTIVE])) {
        Value argument;
        from_type(TYPE(VECTOR3))(&argument, &ground_target);
        const void *args[] = {&argument};
        Value result = cv_call(observer, CV_EFFECTIVE, args, 1);
        index_number(&result, &reach);
        variant_destroy(&argument);
        variant_destroy(&result);
    }
    if (host)
        reach += cv_radius(host) + 2;
    if (target && cv_group(target, 1))
        reach += cv_radius(target);
    IpV offset = cr_flat(ips(point, origin));
    int visible = ipdot(offset, offset) <= reach * reach &&
                  cv_terrain(r, &heights, observer, origin, point, target, 0);
    cv_close_height(&heights);
    return visible && cv_line(r, origin, point, observer, target, 1);
}

/* Iterate the complete exploration disk in native code. The caller publishes
 * newly seen cells to allies before visiting the next observer, preserving the
 * ordered dictionary/save contract. Map and custom observer methods stay live;
 * there is no terrain or visibility-result cache. */
static void cv_explore(CvRuntime *r, void *observer, const void *known, const int32_t *size,
                       double cell, double reach, void *map, void *output) {
    r->exploration[0]++;
    if (!cv_live(observer, 1) || !map || size[0] <= 0 || size[1] <= 0 || size[0] > 65536 ||
        size[1] > 65536 || !isfinite(cell) || cell <= 0 || !isfinite(reach) || reach < 0)
        return;
    IpT root;
    ptrcall(global_transform, observer, 0, &root);
    if (!isfinite(root.p.x) || !isfinite(root.p.z))
        return;
    int x0 = (int)fmin(size[0], fmax(0, floor(((double)root.p.x - reach) / cell)));
    int x1 = (int)fmax(0, fmin(size[0], ceil(((double)root.p.x + reach) / cell)));
    int z0 = (int)fmin(size[1], fmax(0, floor(((double)root.p.z - reach) / cell)));
    int z1 = (int)fmax(0, fmin(size[1], ceil(((double)root.p.z + reach) / cell)));
    for (int x = x0; x < x1; x++) {
        for (int z = z0; z < z1; z++) {
            r->exploration[1]++;
            int64_t index = (int64_t)z * size[0] + x;
            Value key;
            from_type(TYPE(INT))(&key, &index);
            const void *key_args[] = {&key};
            GDExtensionBool found = 0;
            dictionary_has((void *)known, key_args, &found, 1);
            if (!found) {
                float flat[] = {(float)((float)(x + .5) * (float)cell),
                                (float)((float)(z + .5) * (float)cell)};
                float dx = flat[0] - root.p.x, dz = flat[1] - root.p.z;
                float distance = dx * dx + dz * dz;
                if ((double)distance <= reach * reach) {
                    Value argument;
                    from_type(TYPE(VECTOR2))(&argument, flat);
                    const void *args[] = {&argument};
                    Value ground = cv_call(map, 6, args, 1);
                    if (get_type(&ground) == TYPE(VECTOR3)) {
                        IpV point;
                        to_type(TYPE(VECTOR3))(&point, &ground);
                        point.y += .8f;
                        r->exploration[2]++;
                        if (cv_point(r, observer, point, 0))
                            array_append(output, key_args, 0, 1);
                    }
                    variant_destroy(&ground);
                    variant_destroy(&argument);
                }
            }
            variant_destroy(&key);
        }
    }
}
static IpV cv_footprint_point(void *target, IpV observer, int *has_outline) {
    *has_outline = 0;
    IpT root;
    ptrcall(global_transform, target, 0, &root);
    void *obstacle = 0;
    const void *path[] = {&cv_obstacle_path};
    ptrcall(cv_bind[CV_NODE], target, path, &obstacle);
    if (!obstacle)
        return root.p;
    Value value;
    if (!cv_field(obstacle, CV_FOOTPRINT, &value)) {
        variant_destroy(&value);
        return root.p;
    }
    if (get_type(&value) != TYPE(PACKED_VECTOR2_ARRAY)) {
        variant_destroy(&value);
        return root.p;
    }
    Value local, world;
    to_type(TYPE(PACKED_VECTOR2_ARRAY))(&local, &value);
    variant_destroy(&value);
    int64_t count = 0;
    cv_vectors_size(&local, 0, &count, 0);
    if (count <= 0 || count > 65536) {
        get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&local);
        return root.p;
    }
    *has_outline = 1;
    get_ctor(TYPE(PACKED_VECTOR2_ARRAY), 0)(&world, 0);
    int64_t error = 0;
    const void *resize[] = {&count};
    outline_resize(&world, resize, &error, 1);
    if (error) {
        get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&local);
        get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&world);
        return root.p;
    }
    const float *points = cv_vector_read(&local, 0);
    float *p = outline_vector_write(&world, 0);
    for (int64_t i = 0; i < count; i++) {
        IpV v = ipa(ipxform(root.b, ipv(points[i * 2], 0, points[i * 2 + 1])), root.p);
        p[i * 2] = v.x;
        p[i * 2 + 1] = v.z;
    }
    float flat[] = {observer.x, observer.z};
    GDExtensionBool inside = 0;
    const void *check[] = {flat, &world};
    ptrcall(cr_bind[CR_POINT_IN_POLYGON], cr_geometry, check, &inside);
    float best[] = {p[0], p[1]};
    double best_distance = INFINITY;
    if (inside) {
        best[0] = flat[0];
        best[1] = flat[1];
    } else
        for (int64_t i = 0; i < count; i++) {
            float next[2];
            const void *args[] = {flat, p + i * 2, p + ((i + 1) % count) * 2};
            ptrcall(cv_bind[CV_CLOSEST_SEGMENT], cr_geometry, args, next);
            float dx = next[0] - flat[0], dz = next[1] - flat[1];
            double distance = dx * dx + dz * dz;
            if (distance < best_distance) {
                best_distance = distance;
                memcpy(best, next, sizeof(best));
            }
        }
    IpV result = ipv(best[0], root.p.y, best[1]);
    get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&world);
    get_dtor(TYPE(PACKED_VECTOR2_ARRAY))(&local);
    return result;
}
static IpV cv_target_point(void *target, IpV observer) {
    if (cv_group(target, 0)) {
        int outlined;
        return cv_footprint_point(target, observer, &outlined);
    }
    IpT root;
    ptrcall(global_transform, target, 0, &root);
    return root.p;
}
static int cv_observe(CvRuntime *r, void *observer, void *target) {
    if (!cv_live(target, 0) || !cv_inside(target) || !cv_live(observer, 0))
        return 0;
    IpT root;
    ptrcall(global_transform, observer, 0, &root);
    return cv_point(r, observer, ipa(cv_target_point(target, root.p), ipv(0, .8, 0)), target);
}
static void *cv_player(CvRuntime *r, void *node) {
    if (cv_unit(r, node)) {
        void *owner = 0;
        ptrcall(cr_bind[CR_GET_PARENT], node, 0, &owner);
        return owner;
    }
    return cv_object_field(node, CV_PLAYER, 0);
}
static int cv_allied(void *first, void *second) {
    if (first == second)
        return 1;
    if (!first || !cv_has(first, &cv_helpers[CV_ALLIED]))
        return 0;
    Value target;
    cr_variant(second, &target);
    const void *args[] = {&target};
    Value result = cv_call(first, CV_ALLIED, args, 1);
    GDExtensionBool allied = 0;
    if (get_type(&result) == TYPE(BOOL))
        to_type(TYPE(BOOL))(&allied, &result);
    variant_destroy(&result);
    variant_destroy(&target);
    return allied;
}
static CvHint *cv_hint(CvRuntime *r, uint64_t player, uint64_t target) {
    unsigned key = (cr_hash(player) ^ cr_hash(target)) & 2047;
    for (unsigned i = 0; i < 2048; i++) {
        CvHint *h = &r->hints[(key + i) & 2047];
        if (!h->target || (h->target == target && h->player == player))
            return h;
    }
    memset(r->hints, 0, sizeof(r->hints));
    return &r->hints[key];
}
static int cv_observed(CvRuntime *r, void *player, void *target, const void *grids, double maximum,
                       double step) {
    r->statistics[0]++;
    if (!cv_live(target, 0))
        return 0;
    if (cv_allied(cv_player(r, target), player))
        return 1;
    Value player_value, target_value;
    cr_variant(player, &player_value);
    cr_variant(target, &target_value);
    uint64_t player_id = object_id(&player_value), target_id = object_id(&target_value);
    variant_destroy(&player_value);
    variant_destroy(&target_value);
    CvHint *hint = cv_hint(r, player_id, target_id);
    void *witness = object_from_id(hint->witness);
    if (cv_live(witness, 1) && cv_allied(cv_player(r, witness), player) &&
        cv_observe(r, witness, target))
        return 1;
    hint->witness = 0;
    IpT root;
    ptrcall(global_transform, target, 0, &root);
    double reach =
        maximum + (cv_group(target, 1) ? cv_radius(target) : 0) + (cv_group(target, 0) ? 13 : 0);
    if (!isfinite(reach) || !isfinite(step) || reach < 0 || reach + step > 1000000 ||
        !isfinite(root.p.x) || !isfinite(root.p.z))
        return 0;
    if (ci_active(r))
        return ci_observe_scan(r, player, target, root.p, reach, step, hint);
    Value key;
    GDExtensionBool valid = 0;
    if (player) {
        Value object;
        cr_variant(player, &object);
        get_named(&object, &cv_fields[CV_TEAM], &key, &valid);
        variant_destroy(&object);
    } else
        variant_nil(&key);
    double team = -1;
    if (!valid || !index_number(&key, &team) || team < 0) {
        variant_destroy(&key);
        cr_variant(player, &key);
    }
    void *cells_value = dictionary_lookup(grids, &key);
    variant_destroy(&key);
    if (!cells_value || get_type(cells_value) != TYPE(DICTIONARY))
        return 0;
    Value cells;
    to_type(TYPE(DICTIONARY))(&cells, cells_value);
    int found = 0;
    int lx = (int)floor(((double)root.p.x - reach - step) / 12),
        hx = (int)floor(((double)root.p.x + reach + step) / 12),
        lz = (int)floor(((double)root.p.z - reach - step) / 12),
        hz = (int)floor(((double)root.p.z + reach + step) / 12);
    for (int x = lx; x <= hx && !found; x++)
        for (int z = lz; z <= hz && !found; z++) {
            int32_t coords[] = {x, z};
            Value cell_key;
            from_type(TYPE(VECTOR2I))(&cell_key, coords);
            void *value = dictionary_lookup(&cells, &cell_key);
            variant_destroy(&cell_key);
            if (!value || get_type(value) != TYPE(ARRAY))
                continue;
            Value allies;
            to_type(TYPE(ARRAY))(&allies, value);
            int64_t count = count_array(&allies);
            for (int64_t i = 0; i < count; i++) {
                const void *ally_value = array_index(&allies, i);
                if (get_type(ally_value) != TYPE(OBJECT))
                    continue;
                void *ally = object_from_id(object_id(ally_value));
                if (!ally || !cv_allied(cv_player(r, ally), player))
                    continue;
                IpT transform;
                ptrcall(global_transform, ally, 0, &transform);
                IpV offset = cr_flat(ips(transform.p, root.p));
                if (ipdot(offset, offset) > reach * reach)
                    continue;
                r->statistics[3]++;
                if (cv_observe(r, ally, target)) {
                    CvHint *h = cv_hint(r, player_id, target_id);
                    *h = (CvHint){player_id, target_id, object_id(ally_value)};
                    found = 1;
                    break;
                }
            }
            get_dtor(TYPE(ARRAY))(&allies);
        }
    get_dtor(TYPE(DICTIONARY))(&cells);
    return found;
}
static void cv_clear(CvRuntime *r) {
    free(r->blocks);
    free(r->cells);
    free(r->links);
    r->blocks = 0;
    r->cells = 0;
    r->links = 0;
    r->block_count = r->cell_count = r->link_count = 0;
}
static int cv_configure(CvRuntime *r, const void *field, const void *unit_script,
                        const void *terrain, const void *cells) {
    r->field = object_id(field);
    r->unit_script = object_id(unit_script);
    variant_destroy(&r->terrain);
    void *model = get_type(terrain) == TYPE(OBJECT) ? object_from_id(object_id(terrain)) : 0;
    cr_variant(model, &r->terrain);
    r->has_terrain = model != 0;
    cv_clear(r);
    Value keys;
    get_ctor(TYPE(ARRAY), 0)(&keys, 0);
    cr_keys((void *)cells, 0, &keys, 0);
    int64_t n = count_array(&keys), total = 0;
    if (n > 1000000) {
        get_dtor(TYPE(ARRAY))(&keys);
        return 0;
    }
    for (int64_t i = 0; i < n; i++) {
        void *v = dictionary_lookup(cells, array_index(&keys, i));
        if (v && get_type(v) == TYPE(ARRAY)) {
            Value array;
            to_type(TYPE(ARRAY))(&array, v);
            total += count_array(&array);
            get_dtor(TYPE(ARRAY))(&array);
        }
    }
    if (total < 0 || total > 10000000) {
        get_dtor(TYPE(ARRAY))(&keys);
        return 0;
    }
    r->cells = calloc((size_t)n, sizeof(CrCell));
    r->blocks = calloc((size_t)total, sizeof(CvBlock));
    r->links = calloc((size_t)total, sizeof(int));
    if ((n && !r->cells) || (total && (!r->blocks || !r->links))) {
        get_dtor(TYPE(ARRAY))(&keys);
        return 0;
    }
    for (int64_t i = 0; i < n; i++) {
        const void *key = array_index(&keys, i);
        if (get_type(key) != TYPE(VECTOR2I))
            continue;
        int32_t coordinate[2];
        to_type(TYPE(VECTOR2I))(coordinate, (void *)key);
        void *value = dictionary_lookup(cells, key);
        if (!value || get_type(value) != TYPE(ARRAY))
            continue;
        Value entries;
        to_type(TYPE(ARRAY))(&entries, value);
        CrCell cell = {coordinate[0], coordinate[1], r->link_count, 0};
        for (int64_t j = 0; j < count_array(&entries); j++) {
            const void *entry_value = array_index(&entries, j);
            if (get_type(entry_value) != TYPE(DICTIONARY))
                continue;
            Value entry;
            to_type(TYPE(DICTIONARY))(&entry, (void *)entry_value);
            void *body = dictionary_lookup(&entry, &cv_keys[0]),
                 *centre = dictionary_lookup(&entry, &cv_keys[1]),
                 *radius = dictionary_lookup(&entry, &cv_keys[2]),
                 *height = dictionary_lookup(&entry, &cv_keys[3]);
            double rad, h;
            if (body && centre && radius && height && get_type(body) == TYPE(OBJECT) &&
                get_type(centre) == TYPE(VECTOR3) && index_number(radius, &rad) &&
                index_number(height, &h)) {
                uint64_t id = object_id(body);
                int index = 0;
                while (index < r->block_count && r->blocks[index].id != id)
                    index++;
                if (index == r->block_count) {
                    CvBlock *b = &r->blocks[r->block_count++];
                    b->id = id;
                    b->radius = rad;
                    b->height = h;
                    to_type(TYPE(VECTOR3))(&b->centre, centre);
                }
                r->links[r->link_count++] = index;
                cell.count++;
            }
            get_dtor(TYPE(DICTIONARY))(&entry);
        }
        get_dtor(TYPE(ARRAY))(&entries);
        r->cells[r->cell_count++] = cell;
    }
    get_dtor(TYPE(ARRAY))(&keys);
    qsort(r->cells, r->cell_count, sizeof(CrCell), cr_cell_compare);
    return 1;
}
static GDExtensionObjectPtr cv_create(void *userdata, GDExtensionBool notify) {
    (void)userdata;
    (void)notify;
    CvRuntime *r = calloc(1, sizeof(CvRuntime));
    if (!r)
        return 0;
    variant_nil(&r->terrain);
    void *owner = construct(&parent_name);
    set_instance(owner, &cv_class, r);
    return owner;
}
static void cv_free(void *userdata, void *instance) {
    (void)userdata;
    CvRuntime *r = instance;
    variant_destroy(&r->terrain);
    cv_clear(r);
    ci_free(r);
    free(r);
}
static int cv_object_argument(const void *v) {
    return get_type(v) == TYPE(OBJECT) || get_type(v) == TYPE(NIL);
}
static void *cv_argument(const void *v) {
    return get_type(v) == TYPE(OBJECT) ? object_from_id(object_id(v)) : 0;
}
static void cv_dispatch(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                        GDExtensionInt count, GDExtensionVariantPtr ret,
                        GDExtensionCallError *error) {
    CvRuntime *r = instance;
    int method = (int)(intptr_t)userdata;
    uint64_t started = r->profiling && method < 5 ? profile_now() : 0;
    GDExtensionBool result = 0;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (method == 0 && count == 4 && get_type(args[0]) == TYPE(OBJECT) &&
        get_type(args[1]) == TYPE(OBJECT) && cv_object_argument(args[2]) &&
        get_type(args[3]) == TYPE(DICTIONARY)) {
        Value cells;
        to_type(TYPE(DICTIONARY))(&cells, (void *)args[3]);
        result = cv_configure(r, args[0], args[1], args[2], &cells);
        get_dtor(TYPE(DICTIONARY))(&cells);
    } else if (method == 1 && count == 5 && cv_object_argument(args[0]) &&
               cv_object_argument(args[1]) && get_type(args[2]) == TYPE(DICTIONARY) &&
               get_type(args[3]) == TYPE(FLOAT) && get_type(args[4]) == TYPE(FLOAT)) {
        Value cells;
        double reach, step;
        to_type(TYPE(DICTIONARY))(&cells, (void *)args[2]);
        to_type(TYPE(FLOAT))(&reach, (void *)args[3]);
        to_type(TYPE(FLOAT))(&step, (void *)args[4]);
        result = cv_observed(r, cv_argument(args[0]), cv_argument(args[1]), &cells, reach, step);
        get_dtor(TYPE(DICTIONARY))(&cells);
    } else if (method == 2 && count == 3 && cv_object_argument(args[0]) &&
               get_type(args[1]) == TYPE(VECTOR3) && cv_object_argument(args[2])) {
        IpV point;
        to_type(TYPE(VECTOR3))(&point, (void *)args[1]);
        result = cv_point(r, cv_argument(args[0]), point, cv_argument(args[2]));
    } else if (method == 3 && count == 4 && get_type(args[0]) == TYPE(VECTOR3) &&
               get_type(args[1]) == TYPE(VECTOR3) && cv_object_argument(args[2]) &&
               cv_object_argument(args[3])) {
        IpV origin, end;
        to_type(TYPE(VECTOR3))(&origin, (void *)args[0]);
        to_type(TYPE(VECTOR3))(&end, (void *)args[1]);
        result = cv_line(r, origin, end, cv_argument(args[2]), cv_argument(args[3]), 0);
    } else if (method == 4 && count == 2 && cv_object_argument(args[0]) &&
               cv_object_argument(args[1])) {
        void *source = cv_argument(args[0]), *target = cv_argument(args[1]);
        if (cv_live(source, 0) && cv_live(target, 0)) {
            IpT a, b;
            ptrcall(global_transform, source, 0, &a);
            ptrcall(global_transform, target, 0, &b);
            CvHeight height = {0};
            IpV start = ipa(a.p, ipv(0, .8, 0)), end = ipa(b.p, ipv(0, .8, 0));
            result = cv_terrain(r, &height, source, start, end, target, 1);
            cv_close_height(&height);
            if (result)
                result = cv_line(r, start, end, source, target, 1);
        }
    } else if (method == 5 && count == 0) {
        Value array;
        get_ctor(TYPE(ARRAY), 0)(&array, 0);
        for (int i = 0; i < 5; i++) {
            Value v;
            int64_t n = (int64_t)r->statistics[i];
            from_type(TYPE(INT))(&v, &n);
            const void *a[] = {&v};
            array_append(&array, a, 0, 1);
            variant_destroy(&v);
        }
        from_type(TYPE(ARRAY))(ret, &array);
        get_dtor(TYPE(ARRAY))(&array);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 7 && count == 6 && cv_object_argument(args[0]) &&
               get_type(args[1]) == TYPE(DICTIONARY) && get_type(args[2]) == TYPE(VECTOR2I) &&
               get_type(args[3]) == TYPE(FLOAT) && get_type(args[4]) == TYPE(FLOAT) &&
               get_type(args[5]) == TYPE(OBJECT)) {
        Value known, output;
        int32_t size[2];
        double cell, reach;
        to_type(TYPE(DICTIONARY))(&known, (void *)args[1]);
        to_type(TYPE(VECTOR2I))(size, (void *)args[2]);
        to_type(TYPE(FLOAT))(&cell, (void *)args[3]);
        to_type(TYPE(FLOAT))(&reach, (void *)args[4]);
        get_ctor(TYPE(ARRAY), 0)(&output, 0);
        cv_explore(r, cv_argument(args[0]), &known, size, cell, reach, cv_argument(args[5]),
                   &output);
        from_type(TYPE(ARRAY))(ret, &output);
        get_dtor(TYPE(ARRAY))(&output);
        get_dtor(TYPE(DICTIONARY))(&known);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 9 && count == 5 && cv_object_argument(args[0]) &&
               cv_object_argument(args[1]) && get_type(args[2]) == TYPE(DICTIONARY) &&
               get_type(args[3]) == TYPE(FLOAT) && get_type(args[4]) == TYPE(FLOAT)) {
        Value cells;
        double reach, step;
        to_type(TYPE(DICTIONARY))(&cells, (void *)args[2]);
        to_type(TYPE(FLOAT))(&reach, (void *)args[3]);
        to_type(TYPE(FLOAT))(&step, (void *)args[4]);
        r->combat[0]++;
        int64_t answer =
            native_combat_fire(r, cv_argument(args[0]), cv_argument(args[1]), &cells, reach, step);
        r->combat[answer < 0 ? 2 : 1]++;
        get_dtor(TYPE(DICTIONARY))(&cells);
        from_type(TYPE(INT))(ret, &answer);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 11 && count == 2 && get_type(args[0]) == TYPE(ARRAY) &&
               get_type(args[1]) == TYPE(FLOAT)) {
        Value observers, output;
        double delta;
        to_type(TYPE(ARRAY))(&observers, (void *)args[0]);
        to_type(TYPE(FLOAT))(&delta, (void *)args[1]);
        ci_rebuild(r, &observers, delta, &output);
        from_type(TYPE(ARRAY))(ret, &output);
        get_dtor(TYPE(ARRAY))(&output);
        get_dtor(TYPE(ARRAY))(&observers);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 12 && count == 4 && get_type(args[0]) == TYPE(VECTOR3) &&
               get_type(args[1]) == TYPE(FLOAT) && cv_object_argument(args[2]) &&
               cv_object_argument(args[3])) {
        IpV point;
        double radius;
        Value output;
        to_type(TYPE(VECTOR3))(&point, (void *)args[0]);
        to_type(TYPE(FLOAT))(&radius, (void *)args[1]);
        ci_nearby(r, point, radius, cv_argument(args[2]), cv_argument(args[3]), &output);
        from_type(TYPE(ARRAY))(ret, &output);
        get_dtor(TYPE(ARRAY))(&output);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 13 && count == 0) {
        ci_statistics(r, ret);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 14 && count == 0) {
        ci_clear(r);
        result = 1;
    } else if (method == 10 && count == 0) {
        profile_array(r->combat, 3, ret);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 8 && count == 0) {
        profile_array(r->exploration, 3, ret);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else if (method == 6 && count == 1 && get_type(args[0]) == TYPE(BOOL)) {
        GDExtensionBool enabled;
        to_type(TYPE(BOOL))(&enabled, (void *)args[0]);
        r->profiling = enabled && profile_time && profile_clock;
        profile_array(r->profile, 10, ret);
        error->error = GDEXTENSION_CALL_OK;
        return;
    } else {
        variant_nil(ret);
        return;
    }
    if (r->profiling && method < 5) {
        r->profile[method] += profile_now() - started;
        r->profile[method + 5]++;
    }
    from_type(TYPE(BOOL))(ret, &result);
    error->error = GDEXTENSION_CALL_OK;
}
static int visibility_load(GDExtensionInterfaceGetProcAddress proc) {
    cv_vector_read = (GDExtensionInterfacePackedVector2ArrayOperatorIndexConst)proc(
        "packed_vector2_array_operator_index_const");
    return cv_vector_read != 0;
}
static void visibility_initialize(void) {
    name_new(&cv_class, "CopperfinVisibilityRuntime");
    const char *methods[] = {"configure",      "observed",          "can_observe_point",
                             "line_clear",     "has_line_of_fire",  "statistics",
                             "profile",        "explore_cells",     "exploration_statistics",
                             "can_fire",       "combat_statistics", "rebuild_index",
                             "nearby_indexed", "index_statistics",  "clear_index"};
    const char *arguments[] = {"field",  "unit_type", "terrain", "blockers",   "player",
                               "target", "cells",     "reach",   "step",       "point",
                               "source", "enabled",   "known",   "dimensions", "cell_size",
                               "map",    "observers", "excluded"};
    const char *fields[] = {"sight_range", "hp",      "_construction_progress",
                            "player",      "team",    "_navigation_trait",
                            "footprint",   "columns", "rows",
                            "heights",     "flags",   "tier_step",
                            "size",        "_flight", "movement_domain",
                            "_match",      ""};
    const char *helpers[] = {"get_base_script", "is_constructed", "effective_sight_range",
                             "combat_domain",   "is_allied_with", "_refresh",
                             "ground_point"};
    for (int i = 0; i < 6; i++) {
        name_new(&cv_methods[i], methods[i]);
        name_new(&cv_helpers[i], helpers[i]);
    }
    name_new(&cv_methods[6], methods[6]);
    name_new(&cv_methods[7], methods[7]);
    name_new(&cv_methods[8], methods[8]);
    name_new(&cv_methods[9], methods[9]);
    name_new(&cv_methods[10], methods[10]);
    for (int i = 11; i < 15; i++)
        name_new(&cv_methods[i], methods[i]);
    native_combat_initialize();
    name_new(&cv_helpers[6], helpers[6]);
    for (int i = 0; i < 18; i++)
        name_new(&cv_arguments[i], arguments[i]);
    for (int i = 0; i < 17; i++)
        name_new(&cv_fields[i], fields[i]);
    const char *keys[] = {"body", "center", "radius", "height"};
    for (int i = 0; i < 4; i++) {
        Value s;
        string_new(&s, keys[i]);
        from_type(TYPE(STRING))(&cv_keys[i], &s);
        get_dtor(TYPE(STRING))(&s);
    }
    name_new(&cv_groups[0], "footprinted_structures");
    name_new(&cv_groups[1], "neutral_buildings");
    Value path;
    string_new(&path, "MovementObstacle");
    const void *path_arg[] = {&path};
    get_ctor(TYPE(NODE_PATH), 2)(&cv_obstacle_path, path_arg);
    get_dtor(TYPE(STRING))(&path);
    cv_initialized = 1;
    cv_vectors_size = get_builtin(TYPE(PACKED_VECTOR2_ARRAY), &size_name, 3173160232LL);
    if (!cv_vectors_size)
        return;
    const char *binds[] = {"is_inside_tree",
                           "has_method",
                           "is_in_group",
                           "is_ancestor_of",
                           "get_script",
                           "get_node_or_null",
                           "get_closest_point_to_segment",
                           "is_node_ready"};
    const uint64_t hashes[] = {36873697,   2619796661, 2619796661, 3093956946,
                               1214101251, 2734337346, 4172901909, 36873697};
    for (int i = 0; i < 8; i++) {
        Value name;
        name_new(&name, binds[i]);
        const Value *klass =
            i == 1 || i == 4 ? &object_name : (i == 6 ? &cr_geometry_name : &cr_tree_name);
        cv_bind[i] = method_bind(klass, &name, hashes[i]);
        get_dtor(TYPE(STRING_NAME))(&name);
        if (!cv_bind[i])
            return;
    }
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = cv_create;
    info.free_instance_func = cv_free;
    register_class(library, &cv_class, &parent_name, &info);
    cv_registered = 1;
    const int counts[] = {4, 5, 3, 4, 2, 0, 1, 6, 0, 5, 0, 2, 4, 0, 0};
    const GDExtensionVariantType types[15][6] = {
        {TYPE(OBJECT), TYPE(OBJECT), TYPE(OBJECT), TYPE(DICTIONARY)},
        {TYPE(OBJECT), TYPE(OBJECT), TYPE(DICTIONARY), TYPE(FLOAT), TYPE(FLOAT)},
        {TYPE(OBJECT), TYPE(VECTOR3), TYPE(OBJECT)},
        {TYPE(VECTOR3), TYPE(VECTOR3), TYPE(OBJECT), TYPE(OBJECT)},
        {TYPE(OBJECT), TYPE(OBJECT)},
        {},
        {TYPE(BOOL)},
        {TYPE(OBJECT), TYPE(DICTIONARY), TYPE(VECTOR2I), TYPE(FLOAT), TYPE(FLOAT), TYPE(OBJECT)},
        {},
        {TYPE(OBJECT), TYPE(OBJECT), TYPE(DICTIONARY), TYPE(FLOAT), TYPE(FLOAT)},
        {},
        {TYPE(ARRAY), TYPE(FLOAT)},
        {TYPE(VECTOR3), TYPE(FLOAT), TYPE(OBJECT), TYPE(OBJECT)},
        {},
        {}};
    const int names[15][6] = {{0, 1, 2, 3},
                              {4, 5, 6, 7, 8},
                              {10, 9, 5},
                              {9, 5, 10, 5},
                              {10, 5},
                              {},
                              {11},
                              {10, 12, 13, 14, 7, 15},
                              {},
                              {10, 5, 6, 7, 8},
                              {},
                              {16, 8},
                              {9, 7, 4, 17},
                              {},
                              {}};
    for (int i = 0; i < 15; i++) {
        GDExtensionPropertyInfo parameters[6];
        GDExtensionClassMethodArgumentMetadata metadata[6] = {0};
        for (int j = 0; j < counts[i]; j++)
            parameters[j] = (GDExtensionPropertyInfo){
                types[i][j], &cv_arguments[names[i][j]], &empty_name, 0, &empty_string, 6};
        GDExtensionPropertyInfo output = {i == 9 ? TYPE(INT)
                                                 : (i >= 5 && i != 14 ? TYPE(ARRAY) : TYPE(BOOL)),
                                          &empty_name,
                                          &empty_name,
                                          0,
                                          &empty_string,
                                          6};
        GDExtensionClassMethodInfo method = {0};
        method.name = &cv_methods[i];
        method.method_userdata = (void *)(intptr_t)i;
        method.call_func = cv_dispatch;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.has_return_value = 1;
        method.return_value_info = &output;
        method.argument_count = counts[i];
        method.arguments_info = parameters;
        method.arguments_metadata = metadata;
        register_method(library, &cv_class, &method);
    }
}
static void visibility_deinitialize(void) {
    if (!cv_initialized)
        return;
    if (cv_registered)
        unregister_class(library, &cv_class);
    cv_registered = 0;
    get_dtor(TYPE(STRING_NAME))(&cv_class);
    get_dtor(TYPE(NODE_PATH))(&cv_obstacle_path);
    for (int i = 0; i < 6; i++) {
        get_dtor(TYPE(STRING_NAME))(&cv_methods[i]);
        get_dtor(TYPE(STRING_NAME))(&cv_helpers[i]);
    }
    get_dtor(TYPE(STRING_NAME))(&cv_methods[6]);
    get_dtor(TYPE(STRING_NAME))(&cv_methods[7]);
    get_dtor(TYPE(STRING_NAME))(&cv_methods[8]);
    get_dtor(TYPE(STRING_NAME))(&cv_methods[9]);
    get_dtor(TYPE(STRING_NAME))(&cv_methods[10]);
    for (int i = 11; i < 15; i++)
        get_dtor(TYPE(STRING_NAME))(&cv_methods[i]);
    native_combat_deinitialize();
    get_dtor(TYPE(STRING_NAME))(&cv_helpers[6]);
    for (int i = 0; i < 18; i++)
        get_dtor(TYPE(STRING_NAME))(&cv_arguments[i]);
    for (int i = 0; i < 17; i++)
        get_dtor(TYPE(STRING_NAME))(&cv_fields[i]);
    for (int i = 0; i < 4; i++)
        variant_destroy(&cv_keys[i]);
    for (int i = 0; i < 2; i++)
        get_dtor(TYPE(STRING_NAME))(&cv_groups[i]);
    cv_initialized = 0;
}
