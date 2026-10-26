/* Persistent, ordered spatial storage shared by observation and body queries.
 * Cells retain weak IDs and insertion order. Narrow phases read live positions,
 * owners and gameplay facts, matching the existing once-per-tick broad phase. */
typedef struct {
    uint64_t owner;
    double team;
    int teamed;
} CiKey;
typedef struct {
    CiKey key;
    uint64_t id;
    int32_t x, z;
    int order;
} CiEntry;
struct CiIndex {
    CiEntry *vision, *coarse, *fine;
    int capacity, observers, bodies, active;
    double maxima[3];
    uint64_t statistics[6]; /* rebuilds, observers visited, nearby queries, vision scans,
                              allocations, native sight evaluations */
};

static int ci_active(CvRuntime *r) { return r->index && r->index->active; }
static void ci_clear(CvRuntime *r) {
    if (r->index)
        r->index->active = 0;
}
static void ci_free(CvRuntime *r) {
    if (!r->index)
        return;
    free(r->index->vision);
    free(r->index->coarse);
    free(r->index->fine);
    free(r->index);
    r->index = 0;
}
static int ci_reserve(CvRuntime *r, int count) {
    if (!r->index)
        r->index = calloc(1, sizeof(CiIndex));
    if (!r->index)
        return 0;
    CiIndex *index = r->index;
    if (index->capacity >= count)
        return 1;
    int capacity = index->capacity ? index->capacity : 64;
    while (capacity < count)
        capacity *= 2;
    CiEntry *vision = malloc(sizeof(CiEntry) * capacity),
            *coarse = malloc(sizeof(CiEntry) * capacity),
            *fine = malloc(sizeof(CiEntry) * capacity);
    if (!vision || !coarse || !fine) {
        free(vision);
        free(coarse);
        free(fine);
        return 0;
    }
    free(index->vision);
    free(index->coarse);
    free(index->fine);
    index->vision = vision;
    index->coarse = coarse;
    index->fine = fine;
    index->capacity = capacity;
    index->statistics[4]++;
    return 1;
}
static CiKey ci_key(void *owner) {
    CiKey key = {0};
    if (!owner)
        return key;
    key.owner = rp_object_id(owner);
    Value value;
    if (cv_field(owner, CV_TEAM, &value) && index_number(&value, &key.team) && key.team >= 0) {
        key.teamed = 1;
        key.owner = 0;
    }
    variant_destroy(&value);
    return key;
}
static int ci_key_compare(CiKey a, CiKey b) {
    if (a.teamed != b.teamed)
        return a.teamed < b.teamed ? -1 : 1;
    if (a.teamed)
        return a.team < b.team ? -1 : (a.team > b.team ? 1 : 0);
    return a.owner < b.owner ? -1 : (a.owner > b.owner ? 1 : 0);
}
static int ci_compare(const void *left, const void *right) {
    const CiEntry *a = left, *b = right;
    int key = ci_key_compare(a->key, b->key);
    if (key)
        return key;
    if (a->x != b->x)
        return a->x < b->x ? -1 : 1;
    if (a->z != b->z)
        return a->z < b->z ? -1 : 1;
    return a->order < b->order ? -1 : (a->order > b->order ? 1 : 0);
}
static int ci_lower(CiEntry *entries, int count, CiKey key, int32_t x, int32_t z) {
    CiEntry wanted = {.key = key, .x = x, .z = z, .order = -1};
    int low = 0, high = count;
    while (low < high) {
        int middle = low + (high - low) / 2;
        if (ci_compare(&entries[middle], &wanted) < 0)
            low = middle + 1;
        else
            high = middle;
    }
    return low;
}
static void *ci_owner(CvRuntime *r, void *node) {
    return us_for_unit(node) ? us_parent(node) : cv_player(r, node);
}
static void ci_rebuild(CvRuntime *r, const void *observers, double delta, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    ci_clear(r);
    int64_t count = count_array((void *)observers);
    if (count < 0 || count > 65536 || !isfinite(delta) || delta < 0 || !ci_reserve(r, (int)count))
        return;
    CiIndex *index = r->index;
    index->observers = index->bodies = 0;
    memset(index->maxima, 0, sizeof(index->maxima));
    index->statistics[0]++;
    CvHeight heights = {0};
    int valid = 1;
    for (int i = 0; i < count && valid; i++) {
        index->statistics[1]++;
        const void *value = array_index(observers, i);
        void *node = cv_argument(value);
        if (!node || !object_cast(node, node_tag) || !cv_live(node, 0))
            continue;
        double reach;
        if (!cv_number(node, CV_SIGHT, &reach))
            continue;
        void *owner = ci_owner(r, node);
        if (!owner)
            continue;
        uint64_t id = rp_object_id(node), owner_id = rp_object_id(owner);
        IpT root;
        ptrcall(global_transform, node, 0, &root);
        UsSlot *slot = us_slot(us_for_unit(node));
        if (slot && (slot->flags & US_STANDARD_SIGHT)) {
            if (cv_plateau(r, &heights, node, root.p, cv_meta_host(node)))
                reach *= 1.3;
            index->statistics[5]++;
        } else if (cv_has(node, &cv_helpers[CV_EFFECTIVE])) {
            Value result = cv_call(node, CV_EFFECTIVE, 0, 0);
            valid = index_number(&result, &reach);
            variant_destroy(&result);
        }
        node = object_from_id(id);
        owner = object_from_id(owner_id);
        if (!node || !owner || !valid)
            continue;
        void *host = cv_meta_host(node);
        if (host)
            reach += cv_radius(host) + 2;
        ptrcall(global_transform, node, 0, &root);
        if (!isfinite(reach) || !isfinite(root.p.x) || !isfinite(root.p.z) ||
            fabs(root.p.x) > 1e9 || fabs(root.p.z) > 1e9) {
            valid = 0;
            break;
        }
        CiEntry entry = {.key = ci_key(owner),
                         .id = id,
                         .x = (int32_t)floor((double)root.p.x / 12),
                         .z = (int32_t)floor((double)root.p.z / 12),
                         .order = i};
        index->vision[index->observers++] = entry;
        index->maxima[0] = fmax(index->maxima[0], reach);
        GDExtensionBool body = 0;
        const void *group[] = {&index_units_group};
        ptrcall(index_in_group, node, group, &body);
        if (body) {
            double radius, speed;
            if (!index_field_number(value, &index_fields[2], &radius) ||
                !index_field_number(value, &index_fields[3], &speed)) {
                valid = 0;
                break;
            }
            index->maxima[1] = fmax(index->maxima[1], radius);
            index->maxima[2] = fmax(index->maxima[2], speed * delta);
            entry.key = (CiKey){0};
            index->coarse[index->bodies] = entry;
            entry.x = (int32_t)floor((double)root.p.x / 3);
            entry.z = (int32_t)floor((double)root.p.z / 3);
            index->fine[index->bodies++] = entry;
        }
    }
    cv_close_height(&heights);
    if (!valid)
        return;
    if (index->observers > 1)
        qsort(index->vision, index->observers, sizeof(CiEntry), ci_compare);
    if (index->bodies > 1) {
        qsort(index->coarse, index->bodies, sizeof(CiEntry), ci_compare);
        qsort(index->fine, index->bodies, sizeof(CiEntry), ci_compare);
    }
    index->active = 1;
    for (int i = 0; i < 3; i++) {
        Value value;
        from_type(TYPE(FLOAT))(&value, &index->maxima[i]);
        array_append(output, (const void *[]){&value}, 0, 1);
        variant_destroy(&value);
    }
}
static int ci_bounds(IpV point, double reach, double size, int32_t *bounds) {
    if (!isfinite(reach) || !isfinite(point.x) || !isfinite(point.z))
        return 0;
    double values[] = {
        floor(((double)point.x - reach) / size), floor(((double)point.z - reach) / size),
        floor(((double)point.x + reach) / size), floor(((double)point.z + reach) / size)};
    for (int i = 0; i < 4; i++) {
        if (values[i] <= INT32_MIN || values[i] >= INT32_MAX)
            return 0;
        bounds[i] = (int32_t)values[i];
    }
    return 1;
}
static void ci_nearby(CvRuntime *r, IpV point, double radius, void *include, void *exclude,
                      void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    if (!ci_active(r) || !isfinite(radius))
        return;
    CiIndex *index = r->index;
    index->statistics[2]++;
    double size = radius >= 6 ? 12 : 3;
    CiEntry *entries = radius >= 6 ? index->coarse : index->fine;
    int32_t bounds[4];
    if (!ci_bounds(point, radius + index->maxima[2], size, bounds))
        return;
    for (int x = bounds[0]; x <= bounds[2]; x++)
        for (int z = bounds[1]; z <= bounds[3]; z++) {
            int first = ci_lower(entries, index->bodies, (CiKey){0}, x, z);
            for (int i = first; i < index->bodies && entries[i].x == x && entries[i].z == z; i++) {
                void *node = object_from_id(entries[i].id);
                if (!cv_live(node, 0))
                    continue;
                if (include || exclude) {
                    void *owner = ci_owner(r, node);
                    if (owner == exclude || (include && owner != include))
                        continue;
                }
                IpT root;
                ptrcall(global_transform, node, 0, &root);
                float dx = root.p.x - point.x, dz = root.p.z - point.z;
                if ((double)(dx * dx + dz * dz) <= radius * radius) {
                    Value value;
                    cr_variant(node, &value);
                    array_append(output, (const void *[]){&value}, 0, 1);
                    variant_destroy(&value);
                }
            }
        }
}
static int ci_observe_scan(CvRuntime *r, void *player, void *target, IpV point, double reach,
                           double step, CvHint *hint) {
    CiIndex *index = r->index;
    index->statistics[3]++;
    CiKey key = ci_key(player);
    int32_t bounds[4];
    if (!ci_bounds(point, reach + step, 12, bounds))
        return 0;
    for (int x = bounds[0]; x <= bounds[2]; x++)
        for (int z = bounds[1]; z <= bounds[3]; z++) {
            int first = ci_lower(index->vision, index->observers, key, x, z);
            for (int i = first; i < index->observers; i++) {
                CiEntry *entry = &index->vision[i];
                if (entry->x != x || entry->z != z || ci_key_compare(entry->key, key))
                    break;
                void *ally = object_from_id(entry->id);
                if (!ally)
                    continue;
                UsView *view = us_for_unit(ally);
                void *owner = ci_owner(r, ally);
                if (!(view ? us_allied(view->store, owner, player) : cv_allied(owner, player)))
                    continue;
                IpT root;
                ptrcall(global_transform, ally, 0, &root);
                IpV offset = cr_flat(ips(root.p, point));
                if (ipdot(offset, offset) > reach * reach)
                    continue;
                r->statistics[3]++;
                uint64_t witness_id = entry->id;
                if (cv_observe(r, ally, target)) {
                    hint->witness = witness_id;
                    return 1;
                }
            }
        }
    return 0;
}
static void ci_statistics(CvRuntime *r, void *ret) {
    uint64_t values[9] = {0};
    if (r->index) {
        values[0] = r->index->active;
        values[1] = r->index->observers;
        values[2] = r->index->bodies;
        memcpy(values + 3, r->index->statistics, sizeof(r->index->statistics));
    }
    profile_array(values, 9, ret);
}
