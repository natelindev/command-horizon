/* Owned, iteration-scoped hierarchy over published convex navmesh polygons.
 * Main thread only; no retained engine array pointers or private engine ABI.
 * Plane/edge queries follow Godot 4.7 NavMeshQueries3D's polygon ordering and
 * float behavior, including its near-zero interior early exit. Reference:
 * https://github.com/godotengine/godot/blob/4.7-stable/modules/navigation_3d/3d/nav_mesh_queries_3d.cpp
 */
typedef struct {
    IpV low, high, normal, unit_normal;
    int first, count;
} NsPolygon;
typedef struct {
    IpV low, high;
    int first, count, left, right;
} NsNode;
typedef struct {
    IpV *vertices;
    NsPolygon *polygons;
    NsNode *nodes;
    int *order, *scratch;
    int polygon_count, node_count;
    int64_t iteration;
    uint64_t queries, tested, elapsed;
} NsSurface;
static IpV ns_cross(IpV a, IpV b) {
    return ipv(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
}
static IpV ns_min(IpV a, IpV b) { return ipv(fminf(a.x, b.x), fminf(a.y, b.y), fminf(a.z, b.z)); }
static IpV ns_max(IpV a, IpV b) { return ipv(fmaxf(a.x, b.x), fmaxf(a.y, b.y), fmaxf(a.z, b.z)); }
static float ns_axis(IpV a, int axis) { return axis == 0 ? a.x : (axis == 1 ? a.y : a.z); }
static void ns_clear(NsSurface *s) {
    free(s->vertices);
    free(s->polygons);
    free(s->nodes);
    free(s->order);
    free(s->scratch);
    s->vertices = 0;
    s->polygons = 0;
    s->nodes = 0;
    s->order = 0;
    s->scratch = 0;
    s->polygon_count = s->node_count = 0;
    s->iteration = -1;
}
static int ns_build(NsSurface *s, int first, int count, int depth) {
    int id = s->node_count++;
    NsNode *node = &s->nodes[id];
    node->first = first;
    node->count = count;
    node->left = node->right = -1;
    node->low = ipv(INFINITY, INFINITY, INFINITY);
    node->high = ipv(-INFINITY, -INFINITY, -INFINITY);
    IpV low = node->low, high = node->high;
    for (int i = first; i < first + count; i++) {
        NsPolygon *p = &s->polygons[s->order[i]];
        node->low = ns_min(node->low, p->low);
        node->high = ns_max(node->high, p->high);
        IpV centre = ipm(ipa(p->low, p->high), .5);
        low = ns_min(low, centre);
        high = ns_max(high, centre);
    }
    if (count <= 8 || depth >= 60)
        return id;
    IpV size = ips(high, low);
    int axis = size.y > size.x ? 1 : 0;
    if (size.z > ns_axis(size, axis))
        axis = 2;
    float middle = (ns_axis(low, axis) + ns_axis(high, axis)) * .5f;
    int split = first;
    for (int i = first; i < first + count; i++) {
        NsPolygon *p = &s->polygons[s->order[i]];
        if ((ns_axis(p->low, axis) + ns_axis(p->high, axis)) * .5f < middle) {
            int swap = s->order[split];
            s->order[split++] = s->order[i];
            s->order[i] = swap;
        }
    }
    if (split == first || split == first + count)
        split = first + count / 2;
    node->left = ns_build(s, first, split - first, depth + 1);
    node->right = ns_build(s, split, first + count - split, depth + 1);
    return id;
}
static int ns_configure(NsSurface *s, const IpV *vertices, int64_t vertex_count,
                        const void *polygons, IpT transform, int64_t iteration) {
    ns_clear(s);
    int64_t count = count_array((void *)polygons), total = 0;
    if (count <= 0 || count > 1000000 || vertex_count <= 0 || vertex_count > 10000000)
        return 0;
    for (int64_t i = 0; i < count; i++) {
        const void *v = array_index(polygons, i);
        if (get_type(v) != TYPE(PACKED_INT32_ARRAY))
            return 0;
        Value indices;
        to_type(TYPE(PACKED_INT32_ARRAY))(&indices, (void *)v);
        int64_t n = 0;
        ints_size(&indices, 0, &n, 0);
        get_dtor(TYPE(PACKED_INT32_ARRAY))(&indices);
        if (n < 3 || n > 10000 || total + n > 10000000)
            return 0;
        total += n;
    }
    s->vertices = calloc((size_t)total, sizeof(IpV));
    s->polygons = calloc((size_t)count, sizeof(NsPolygon));
    s->nodes = calloc((size_t)count * 2, sizeof(NsNode));
    s->order = calloc((size_t)count, sizeof(int));
    s->scratch = calloc((size_t)count, sizeof(int));
    if (!s->vertices || !s->polygons || !s->nodes || !s->order || !s->scratch) {
        ns_clear(s);
        return 0;
    }
    int cursor = 0;
    for (int i = 0; i < count; i++) {
        Value indices;
        to_type(TYPE(PACKED_INT32_ARRAY))(&indices, (void *)array_index(polygons, i));
        int64_t n = 0;
        ints_size(&indices, 0, &n, 0);
        const int32_t *ids = ints_index(&indices, 0);
        NsPolygon *p = &s->polygons[i];
        p->first = cursor;
        p->count = (int)n;
        p->low = ipv(INFINITY, INFINITY, INFINITY);
        p->high = ipv(-INFINITY, -INFINITY, -INFINITY);
        int valid = 1;
        for (int j = 0; j < n; j++) {
            if (ids[j] < 0 || ids[j] >= vertex_count) {
                valid = 0;
                break;
            }
            IpV point = ipa(ipxform(transform.b, vertices[ids[j]]), transform.p);
            if (!isfinite(point.x) || !isfinite(point.y) || !isfinite(point.z)) {
                valid = 0;
                break;
            }
            s->vertices[cursor++] = point;
            p->low = ns_min(p->low, point);
            p->high = ns_max(p->high, point);
        }
        get_dtor(TYPE(PACKED_INT32_ARRAY))(&indices);
        if (!valid) {
            ns_clear(s);
            return 0;
        }
        IpV *v = s->vertices + p->first;
        p->normal = ns_cross(ips(v[1], v[0]), ips(v[2], v[0]));
        p->unit_normal = ipnorm(p->normal);
        if (!isfinite(ipdot(p->normal, p->normal)) || ipdot(p->normal, p->normal) < 1e-20f) {
            ns_clear(s);
            return 0;
        }
        /* Include the plane-projected corners as well as the original edges.
         * These bounds cover both query branches on slightly nonplanar polygons. */
        for (int j = 0; j < n; j++) {
            IpV projected = ips(v[j], ipm(p->unit_normal, ipdot(p->unit_normal, ips(v[j], v[0]))));
            p->low = ns_min(p->low, projected);
            p->high = ns_max(p->high, projected);
        }
        float padding = .0001f + iplen(ips(p->high, p->low)) * .00002f;
        p->low = ips(p->low, ipv(padding, padding, padding));
        p->high = ipa(p->high, ipv(padding, padding, padding));
        s->order[i] = i;
    }
    s->polygon_count = (int)count;
    s->iteration = iteration;
    ns_build(s, 0, (int)count, 0);
    return 1;
}
static float ns_bound(const NsNode *n, IpV point) {
    IpV d = ipv(fmaxf(fmaxf(n->low.x - point.x, point.x - n->high.x), 0),
                fmaxf(fmaxf(n->low.y - point.y, point.y - n->high.y), 0),
                fmaxf(fmaxf(n->low.z - point.z, point.z - n->high.z), 0));
    return ipdot(d, d);
}
static float ns_polygon(NsSurface *s, int id, IpV point, IpV *out, int *zero_inside) {
    s->tested++;
    NsPolygon *p = &s->polygons[id];
    const IpV *v = s->vertices + p->first;
    IpV previous = v[p->count - 1], closest = ipv(0, 0, 0);
    float best = INFINITY;
    int inside = 1;
    for (int i = 0; i < p->count; i++) {
        IpV edge = ips(v[i], previous), offset = ips(point, previous);
        if (ipdot(ns_cross(edge, offset), p->normal) <= 0) {
            inside = 0;
            float along = ipdot(edge, offset), length = ipdot(edge, edge);
            if (along > length) {
                float distance = ipdot(ips(v[i], point), ips(v[i], point));
                if (distance < best) {
                    best = distance;
                    closest = v[i];
                }
            } else if (along < 0) {
                float distance = ipdot(ips(previous, point), ips(previous, point));
                if (distance < best) {
                    best = distance;
                    closest = previous;
                }
            } else {
                closest = ipa(previous, ipm(edge, along / length));
                break;
            }
        }
        previous = v[i];
    }
    *zero_inside = 0;
    if (inside) {
        float distance = ipdot(p->unit_normal, ips(point, v[0]));
        *out = ips(point, ipm(p->unit_normal, distance));
        *zero_inside = fabsf(distance) < .00001f;
        return distance * distance;
    }
    *out = closest;
    return ipdot(ips(closest, point), ips(closest, point));
}
static int ns_int_compare(const void *a, const void *b) {
    int x = *(const int *)a, y = *(const int *)b;
    return (x > y) - (x < y);
}
static IpV ns_closest(NsSurface *s, IpV point) {
    s->queries++;
    int stack[128], top = 0, best_id = INT32_MAX;
    stack[top++] = 0;
    float best = INFINITY;
    IpV result = ipv(0, 0, 0);
    while (top) {
        NsNode *node = &s->nodes[stack[--top]];
        if (ns_bound(node, point) > best + fmaxf(1, best) * .00001f)
            continue;
        if (node->left < 0) {
            for (int i = node->first; i < node->first + node->count; i++) {
                int id = s->order[i], zero;
                IpV candidate;
                float distance = ns_polygon(s, id, point, &candidate, &zero);
                if (distance < best || (distance == best && id < best_id)) {
                    best = distance;
                    best_id = id;
                    result = candidate;
                }
            }
        } else {
            float a = ns_bound(&s->nodes[node->left], point),
                  b = ns_bound(&s->nodes[node->right], point);
            stack[top++] = a < b ? node->right : node->left;
            stack[top++] = a < b ? node->left : node->right;
        }
    }
    /* The engine exits at the first improving, near-zero interior polygon.
     * Revisit the tiny near-point candidate set in publication order, so a
     * later exact zero cannot displace that earlier result. */
    if (best <= 1e-10f) {
        int count = 0;
        stack[top++] = 0;
        while (top) {
            NsNode *node = &s->nodes[stack[--top]];
            if (ns_bound(node, point) > 2e-10f)
                continue;
            if (node->left < 0)
                for (int i = node->first; i < node->first + node->count; i++)
                    s->scratch[count++] = s->order[i];
            else {
                stack[top++] = node->left;
                stack[top++] = node->right;
            }
        }
        qsort(s->scratch, count, sizeof(int), ns_int_compare);
        best = INFINITY;
        for (int i = 0; i < count; i++) {
            int zero;
            IpV candidate;
            float distance = ns_polygon(s, s->scratch[i], point, &candidate, &zero);
            if (distance < best) {
                best = distance;
                result = candidate;
                if (zero)
                    break;
            }
        }
    }
    return result;
}
