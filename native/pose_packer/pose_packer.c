/* Bulk pose packing using the public Godot GDExtension C ABI.
 * Scene-tree reads remain on the main thread; GPU interpolation is parallel.
 * No game state is modified. The returned buffer owns its memory. */
#include "gdextension_interface.h"
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdlib.h>

typedef union { uint64_t align; unsigned char data[64]; } Value;
#define TYPE(name) GDEXTENSION_VARIANT_TYPE_##name
#define DECL(name, suffix) static GDExtensionInterface##suffix name
DECL(name_new, StringNameNewWithUtf8Chars);
DECL(string_new, StringNewWithUtf8Chars);
DECL(from_type, GetVariantFromTypeConstructor);
DECL(to_type, GetVariantToTypeConstructor);
DECL(get_ctor, VariantGetPtrConstructor);
DECL(get_dtor, VariantGetPtrDestructor);
DECL(get_builtin, VariantGetPtrBuiltinMethod);
DECL(get_type, VariantGetType);
DECL(variant_destroy, VariantDestroy);
DECL(variant_nil, VariantNewNil);
DECL(get_named, VariantGetNamed);
DECL(variant_call, VariantCall);
DECL(array_index, ArrayOperatorIndexConst);
DECL(array_write, ArrayOperatorIndex);
DECL(ints_index, PackedInt32ArrayOperatorIndexConst);
DECL(dict_index, DictionaryOperatorIndexConst);
DECL(bytes_index, PackedByteArrayOperatorIndex);
DECL(object_id, VariantGetObjectInstanceId);
DECL(object_from_id, ObjectGetInstanceFromId);
DECL(object_cast, ObjectCastTo);
DECL(class_tag, ClassdbGetClassTag);
DECL(method_bind, ClassdbGetMethodBind);
DECL(ptrcall, ObjectMethodBindPtrcall);
DECL(construct, ClassdbConstructObject2);
DECL(set_instance, ObjectSetInstance);
DECL(register_class, ClassdbRegisterExtensionClass4);
DECL(register_method, ClassdbRegisterExtensionClassMethod);
DECL(unregister_class, ClassdbUnregisterExtensionClass);
static GDExtensionClassLibraryPtr library;
static Value class_name, parent_name, pack_name, node_name, transform_name;
static Value empty_name, empty_string, entries_name, capacity_name, size_name, resize_name;
static Value keys[5];
static Value query_name, object_name, queued_name, append_name, has_name, visible_name;
static Value query_args[5];
static Value filtered_name, contact_name, player_name, trait_name, trait_method;
static Value domain_name, speed_name, ghost_name, radius_name, agent_name;
static Value extra_args[9];
static Value hierarchy_name, local_name, hierarchy_args[4], global_pose_name, index_name;
static GDExtensionPtrBuiltInMethod ints_size;
static void *agent_tag;
static GDExtensionPtrBuiltInMethod array_append;
static GDExtensionPtrBuiltInMethod dictionary_has;
static GDExtensionMethodBindPtr queued_for_deletion;
static GDExtensionPtrBuiltInMethod array_size, bytes_resize;
static GDExtensionMethodBindPtr global_transform;
static GDExtensionMethodBindPtr visible_in_tree;
static void *node_tag;
static int class_registered;
static void *resident_rig_for_entry(const void *entry);
static int resident_rig_pose(void *rig, int index, float *transform);
#include "unit_state_api.h"

static void *dictionary_lookup(const void *dictionary, const void *key) {
    const void *args[] = {key};
    GDExtensionBool found = 0;
    dictionary_has((void *)dictionary, args, &found, 1);
    return found ? (void *)dict_index(dictionary, key) : 0;
}

static int64_t count_array(void *array) {
    int64_t size = 0;
    array_size(array, 0, &size, 0);
    return size;
}

#include "terrain_sight.h"
#include "terrain_outline.h"
#include "spatial_index.h"

static void pack_core(const void *entries, int64_t capacity, void *output) {
    get_ctor(TYPE(PACKED_BYTE_ARRAY), 0)(output, 0);
    if (capacity <= 0 || capacity > 8192) return;
    int64_t length = capacity * 64, result = 0;
    const void *resize_args[] = { &length };
    bytes_resize(output, resize_args, &result, 1);
    if (result != 0) return;
    float *pixels = (float *)bytes_index(output, 0);
    memset(pixels, 0, (size_t)length);
    int64_t entries_count = count_array((void *)entries);
    for (int64_t i = 0; i < entries_count; ++i) {
        void *entry_variant = array_index(entries, i);
        if (get_type(entry_variant) != TYPE(DICTIONARY)) continue;
        Value entry, anchors, poses;
        int has_poses = 0;
        to_type(TYPE(DICTIONARY))(&entry, entry_variant);
        void *anchor_value = dictionary_lookup(&entry, &keys[0]);
        void *offset_value = dictionary_lookup(&entry, &keys[1]);
        void *visible_value = dictionary_lookup(&entry, &keys[2]);
        void *pulse_value = dictionary_lookup(&entry, &keys[3]);
        if (!anchor_value || !offset_value || !visible_value || !pulse_value ||
            get_type(anchor_value) != TYPE(ARRAY) || get_type(offset_value) != TYPE(INT) ||
            get_type(visible_value) != TYPE(BOOL) || get_type(pulse_value) != TYPE(COLOR)) {
            get_dtor(TYPE(DICTIONARY))(&entry);
            continue;
        }
        int64_t offset = 0;
        GDExtensionBool shown = 0;
        float pulse[4];
        to_type(TYPE(ARRAY))(&anchors, anchor_value);
        to_type(TYPE(INT))(&offset, offset_value);
        to_type(TYPE(BOOL))(&shown, visible_value);
        to_type(TYPE(COLOR))(pulse, pulse_value);
        int64_t count = count_array(&anchors);
        void *resident_rig = resident_rig_for_entry(&entry);
        void *pose_value = dictionary_lookup(&entry, &keys[4]);
        if (pose_value && get_type(pose_value) == TYPE(ARRAY)) {
            to_type(TYPE(ARRAY))(&poses, pose_value);
            has_poses = 1;
        }
        if (offset >= 0 && count <= capacity && offset <= capacity - count && shown) {
            for (int64_t part = 0; part < count; ++part) {
                void *value = array_index(&anchors, part);
                if (get_type(value) != TYPE(OBJECT)) continue;
                void *object = object_from_id(object_id(value));
                if (!object || !object_cast(object, node_tag)) continue;
                GDExtensionBool visible = 0;
                ptrcall(visible_in_tree, object, 0, &visible);
                if (!visible) continue;
                float transform[12];
                if (resident_rig) {
                    if (!resident_rig_pose(resident_rig, (int)part, transform)) continue;
                } else if (has_poses) {
                    if (part >= count_array(&poses)) continue;
                    void *pose = array_index(&poses, part);
                    if (get_type(pose) != TYPE(TRANSFORM3D)) continue;
                    to_type(TYPE(TRANSFORM3D))(transform, pose);
                } else {
                    ptrcall(global_transform, object, 0, transform);
                }
                float *row = pixels + (offset + part) * 16;
                for (int axis = 0; axis < 3; ++axis) {
                    memcpy(row + axis * 4, transform + axis * 3, sizeof(float) * 3);
                    row[axis * 4 + 3] = transform[9 + axis];
                }
                memcpy(row + 12, pulse, sizeof(pulse));
            }
        }
        if (has_poses) get_dtor(TYPE(ARRAY))(&poses);
        get_dtor(TYPE(ARRAY))(&anchors);
        get_dtor(TYPE(DICTIONARY))(&entry);
    }
}

static void pack_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                      GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    if (argc != 2 || get_type(args[0]) != TYPE(ARRAY) || get_type(args[1]) != TYPE(INT)) {
        variant_nil(ret);
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        return;
    }
    Value entries, bytes;
    int64_t capacity = 0;
    to_type(TYPE(ARRAY))(&entries, (void *)args[0]);
    to_type(TYPE(INT))(&capacity, (void *)args[1]);
    pack_core(&entries, capacity, &bytes);
    from_type(TYPE(PACKED_BYTE_ARRAY))(ret, &bytes);
    get_dtor(TYPE(PACKED_BYTE_ARRAY))(&bytes);
    get_dtor(TYPE(ARRAY))(&entries);
    error->error = GDEXTENSION_CALL_OK;
}

static void pack_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    pack_core(args[0], *(const int64_t *)args[1], ret);
}

/* Same ordered spatial-cell traversal as Battlefield.nearby_units. Positions
 * and queued-deletion state are read live on the main thread, so sequential
 * avoidance callbacks and teleports retain their existing semantics. */
static void nearby_core(const void *cells, const float *point, double radius,
                        double cell_size, double indexed_reach, const void *owner_bits, int64_t allowed, void *output) {
    get_ctor(TYPE(ARRAY), 0)(output, 0);
    if (!(cell_size > 0) || !isfinite(radius) || !isfinite(indexed_reach) ||
        !isfinite(point[0]) || !isfinite(point[2])) return;
    double limits[] = {
        floor((point[0] - indexed_reach) / cell_size),
        floor((point[2] - indexed_reach) / cell_size),
        floor((point[0] + indexed_reach) / cell_size),
        floor((point[2] + indexed_reach) / cell_size)
    };
    for (int i = 0; i < 4; ++i)
        if (limits[i] <= INT32_MIN || limits[i] >= INT32_MAX) return;
    double squared_radius = radius * radius;
    for (int32_t x = (int32_t)limits[0]; x <= (int32_t)limits[2]; ++x) {
        for (int32_t z = (int32_t)limits[1]; z <= (int32_t)limits[3]; ++z) {
            int32_t coordinates[2] = {x, z};
            Value key;
            from_type(TYPE(VECTOR2I))(&key, coordinates);
            void *cell = dictionary_lookup(cells, &key);
            variant_destroy(&key);
            if (!cell || get_type(cell) != TYPE(ARRAY)) continue;
            Value bodies;
            to_type(TYPE(ARRAY))(&bodies, cell);
            int64_t count = count_array(&bodies);
            for (int64_t i = 0; i < count; ++i) {
                void *value = array_index(&bodies, i);
                if (get_type(value) != TYPE(OBJECT)) continue;
                void *body = object_from_id(object_id(value));
                if (!body || !object_cast(body, node_tag)) continue;
                GDExtensionBool queued = 0;
                ptrcall(queued_for_deletion, body, 0, &queued);
                if (queued) continue;
                if (owner_bits) {
                    Value owner;
                    GDExtensionBool valid = 0;
                    get_named(value, &player_name, &owner, &valid);
                    int64_t bit = INT64_MIN; /* Owners not assigned a bit still match exclusion queries. */
                    void *stored = valid ? dictionary_lookup(owner_bits, &owner) : 0;
                    if (stored && get_type(stored) == TYPE(INT)) to_type(TYPE(INT))(&bit, stored);
                    variant_destroy(&owner);
                    if (!(bit & allowed)) continue;
                }
                float transform[12];
                ptrcall(global_transform, body, 0, transform);
                float dx = transform[9] - point[0], dz = transform[11] - point[2];
                float distance_squared = dx * dx + dz * dz;
                if (distance_squared <= squared_radius) {
                    const void *args[] = {value};
                    array_append(output, args, 0, 1);
                }
            }
            get_dtor(TYPE(ARRAY))(&bodies);
        }
    }
}

static void nearby_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                        GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    if (argc != 5 || get_type(args[0]) != TYPE(DICTIONARY) || get_type(args[1]) != TYPE(VECTOR3) ||
        get_type(args[2]) != TYPE(FLOAT) || get_type(args[3]) != TYPE(FLOAT) || get_type(args[4]) != TYPE(FLOAT)) {
        variant_nil(ret);
        error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        return;
    }
    Value cells, output;
    float point[3];
    double radius, cell_size, indexed_reach;
    to_type(TYPE(DICTIONARY))(&cells, (void *)args[0]);
    to_type(TYPE(VECTOR3))(point, (void *)args[1]);
    to_type(TYPE(FLOAT))(&radius, (void *)args[2]);
    to_type(TYPE(FLOAT))(&cell_size, (void *)args[3]);
    to_type(TYPE(FLOAT))(&indexed_reach, (void *)args[4]);
    nearby_core(&cells, point, radius, cell_size, indexed_reach, 0, -1, &output);
    from_type(TYPE(ARRAY))(ret, &output);
    get_dtor(TYPE(ARRAY))(&output);
    get_dtor(TYPE(DICTIONARY))(&cells);
    error->error = GDEXTENSION_CALL_OK;
}

static void nearby_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    nearby_core(args[0], args[1], *(const double *)args[2], *(const double *)args[3], *(const double *)args[4], 0, -1, ret);
}

static void filtered_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                          GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    const GDExtensionVariantType types[] = {TYPE(DICTIONARY), TYPE(VECTOR3), TYPE(FLOAT), TYPE(FLOAT), TYPE(FLOAT), TYPE(DICTIONARY), TYPE(INT)};
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 7) { variant_nil(ret); return; }
    for (int i = 0; i < 7; ++i) if (get_type(args[i]) != types[i]) { variant_nil(ret); return; }
    Value cells, bits, output;
    float point[3];
    double radius, cell_size, reach;
    int64_t allowed;
    to_type(TYPE(DICTIONARY))(&cells, (void *)args[0]);
    to_type(TYPE(VECTOR3))(point, (void *)args[1]);
    to_type(TYPE(FLOAT))(&radius, (void *)args[2]);
    to_type(TYPE(FLOAT))(&cell_size, (void *)args[3]);
    to_type(TYPE(FLOAT))(&reach, (void *)args[4]);
    to_type(TYPE(DICTIONARY))(&bits, (void *)args[5]);
    to_type(TYPE(INT))(&allowed, (void *)args[6]);
    nearby_core(&cells, point, radius, cell_size, reach, &bits, allowed, &output);
    from_type(TYPE(ARRAY))(ret, &output);
    get_dtor(TYPE(ARRAY))(&output);
    get_dtor(TYPE(DICTIONARY))(&cells);
    get_dtor(TYPE(DICTIONARY))(&bits);
    error->error = GDEXTENSION_CALL_OK;
}

static void filtered_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    nearby_core(args[0], args[1], *(const double *)args[2], *(const double *)args[3],
                *(const double *)args[4], args[5], *(const int64_t *)args[6], ret);
}

static double number_property(const void *object, const Value *name) {
    Value result;
    GDExtensionBool valid = 0;
    get_named(object, name, &result, &valid);
    double value = 0;
    if (valid && get_type(&result) == TYPE(FLOAT)) to_type(TYPE(FLOAT))(&value, &result);
    else if (valid && get_type(&result) == TYPE(INT)) {
        int64_t integer = 0;
        to_type(TYPE(INT))(&integer, &result);
        value = (double)integer;
    } else if (valid && get_type(&result) == TYPE(BOOL)) {
        GDExtensionBool boolean = 0;
        to_type(TYPE(BOOL))(&boolean, &result);
        value = boolean;
    }
    variant_destroy(&result);
    return value;
}

/* Four contacts share vector arithmetic, followed by an ordered minimum reduction.
 * Vector operations have the same float rounding as Godot's Vector3; scalar
 * fractions retain GDScript's double precision. Do not enable fast-math/FMA. */
typedef float Float4 __attribute__((vector_size(16)));
typedef double Double4 __attribute__((vector_size(32)));
typedef struct { float x[4], z[4]; double separation[4]; int count; } Contacts;

static void clip_contacts(const Contacts *batch, float sx, float sz, double length_squared,
                          double *best, float *normal) {
    Float4 x, z;
    Double4 separation;
    memcpy(&x, batch->x, sizeof(x));
    memcpy(&z, batch->z, sizeof(z));
    memcpy(&separation, batch->separation, sizeof(separation));
    Float4 toward_float = x * sx + z * sz;
    Float4 distance_float = x * x + z * z;
    Double4 toward = __builtin_convertvector(toward_float, Double4);
    Double4 outside = __builtin_convertvector(distance_float, Double4) - separation * separation;
    Double4 discriminant = toward * toward - outside * length_squared;
    for (int lane = 0; lane < batch->count; ++lane) {
        double fraction = 0;
        if (outside[lane] > 0) {
            if (discriminant[lane] < 0) continue;
            fraction = (-toward[lane] - sqrt(discriminant[lane])) / length_squared;
        }
        if (fraction >= 0 && fraction < *best) {
            *best = fraction;
            float length = sqrtf(distance_float[lane]);
            normal[0] = x[lane] / length;
            normal[2] = z[lane] / length;
        }
    }
}

static void contact_core(const float *origin, const float *next, const void *neighbors,
                         void *own, int64_t domain, double radius, double margin, float *result) {
    result[0] = result[1] = result[2] = 0;
    result[3] = 1;
    float sx = next[0] - origin[0], sz = next[2] - origin[2];
    double length_squared = sx * sx + sz * sz;
    if (length_squared < 0.00000001) return;
    double best = 1;
    Contacts batch = {0};
    int64_t count = count_array((void *)neighbors);
    for (int64_t i = 0; i < count; ++i) {
        void *value = array_index(neighbors, i);
        if (get_type(value) != TYPE(OBJECT)) continue;
        void *body = object_from_id(object_id(value));
        if (!body || body == own || !object_cast(body, node_tag)) continue;
        float transform[12];
        ptrcall(global_transform, body, 0, transform);
        float x = origin[0] - transform[9], z = origin[2] - transform[11];
        if (x * sx + z * sz >= 0) continue;
        Value movement;
        GDExtensionBool valid = 0;
        get_named(value, &trait_name, &movement, &valid);
        void *agent = valid && get_type(&movement) == TYPE(OBJECT) ? object_from_id(object_id(&movement)) : 0;
        if (!agent) {
            variant_destroy(&movement);
            GDExtensionCallError error = {0};
            variant_call(value, &trait_method, 0, 0, &movement, &error);
            agent = error.error == GDEXTENSION_CALL_OK && get_type(&movement) == TYPE(OBJECT) ? object_from_id(object_id(&movement)) : 0;
        }
        if (agent && object_cast(agent, agent_tag)) {
            double separation = radius + number_property(&movement, &radius_name) - margin;
            /* Reject geometrically impossible contacts before reading live speed
             * modifiers. Most nearby bodies are beside or beyond this short step.
             * Use the same float dot products and double quadratic as the ordered
             * SIMD reduction below; pending lanes can only lower the current best. */
            double toward = x * sx + z * sz;
            double outside = (double)(x * x + z * z) - separation * separation;
            double fraction = 0;
            if (outside > 0) {
                double discriminant = toward * toward - outside * length_squared;
                if (discriminant < 0) { variant_destroy(&movement); continue; }
                fraction = (-toward - sqrt(discriminant)) / length_squared;
            }
            if (fraction < 0 || fraction >= best ||
                number_property(&movement, &domain_name) != domain ||
                !(number_property(&movement, &speed_name) > 0) ||
                number_property(&movement, &ghost_name)) {
                variant_destroy(&movement);
                continue;
            }
            int lane = batch.count++;
            batch.x[lane] = x;
            batch.z[lane] = z;
            batch.separation[lane] = separation;
            if (batch.count == 4) {
                clip_contacts(&batch, sx, sz, length_squared, &best, result);
                batch.count = 0;
            }
        }
        variant_destroy(&movement);
    }
    if (batch.count) clip_contacts(&batch, sx, sz, length_squared, &best, result);
    result[3] = (float)best;
}

static void contact_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                         GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    const GDExtensionVariantType types[] = {TYPE(VECTOR3), TYPE(VECTOR3), TYPE(ARRAY), TYPE(OBJECT), TYPE(INT), TYPE(FLOAT), TYPE(FLOAT)};
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 7) { variant_nil(ret); return; }
    for (int i = 0; i < 7; ++i) if (get_type(args[i]) != types[i]) { variant_nil(ret); return; }
    float origin[3], next[3], result[4];
    Value neighbors;
    int64_t domain;
    double radius, margin;
    to_type(TYPE(VECTOR3))(origin, (void *)args[0]);
    to_type(TYPE(VECTOR3))(next, (void *)args[1]);
    to_type(TYPE(ARRAY))(&neighbors, (void *)args[2]);
    to_type(TYPE(INT))(&domain, (void *)args[4]);
    to_type(TYPE(FLOAT))(&radius, (void *)args[5]);
    to_type(TYPE(FLOAT))(&margin, (void *)args[6]);
    contact_core(origin, next, &neighbors, object_from_id(object_id(args[3])), domain, radius, margin, result);
    from_type(TYPE(VECTOR4))(ret, result);
    get_dtor(TYPE(ARRAY))(&neighbors);
    error->error = GDEXTENSION_CALL_OK;
}

static void contact_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    contact_core(args[0], args[1], args[2], *(void *const *)args[3], *(const int64_t *)args[4],
                 *(const double *)args[5], *(const double *)args[6], ret);
}

static void compose_pose(const float *p, const float *local, float *out) {
    for (int row = 0; row < 3; ++row) {
        for (int col = 0; col < 3; ++col)
            out[row * 3 + col] = p[row * 3] * local[col] + p[row * 3 + 1] * local[3 + col] + p[row * 3 + 2] * local[6 + col];
        out[9 + row] = p[row * 3] * local[9] + p[row * 3 + 1] * local[10] + p[row * 3 + 2] * local[11] + p[9 + row];
    }
}

/* Called only with worker-owned proxies and arrays. A parent precedes every
 * child, so forward traversal composes the full hierarchy in contiguous memory. */
#include "pose_rebase.h"

static void hierarchy_core(const void *poses, const void *parents, const void *anchors, void *palette) {
    int64_t count = count_array((void *)poses), parent_count = 0, anchor_count = 0;
    ints_size((void *)parents, 0, &parent_count, 0);
    ints_size((void *)anchors, 0, &anchor_count, 0);
    if (count <= 0 || count > 8192 || count != parent_count || count_array(palette) != anchor_count) return;
    const int32_t *parent = ints_index(parents, 0);
    const int32_t *anchor = anchor_count ? ints_index(anchors, 0) : 0;
    float *world = malloc((size_t)count * 12 * sizeof(float));
    if (!world) return;
    for (int64_t i = 0; i < count; ++i) {
        Value value;
        GDExtensionBool valid = 0;
        get_named(array_index(poses, i), &local_name, &value, &valid);
        if (!valid || get_type(&value) != TYPE(TRANSFORM3D) || parent[i] < -1 || parent[i] >= i) {
            variant_destroy(&value);
            free(world);
            return;
        }
        float local[12], *out = world + i * 12;
        to_type(TYPE(TRANSFORM3D))(local, &value);
        variant_destroy(&value);
        if (parent[i] < 0) { memcpy(out, local, sizeof(local)); continue; }
        const float *p = world + parent[i] * 12;
        /* Godot Basis is stored by row, followed by the origin vector. */
        compose_pose(p, local, out);
    }
    for (int64_t i = 0; i < anchor_count; ++i) {
        if (anchor[i] < 0 || anchor[i] >= count) continue;
        void *slot = array_write(palette, i);
        variant_destroy(slot);
        from_type(TYPE(TRANSFORM3D))(slot, world + anchor[i] * 12);
    }
    free(world);
}

static void hierarchy_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                           GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    variant_nil(ret);
    const GDExtensionVariantType types[] = {TYPE(ARRAY), TYPE(PACKED_INT32_ARRAY), TYPE(PACKED_INT32_ARRAY), TYPE(ARRAY)};
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 4) return;
    for (int i = 0; i < 4; ++i) if (get_type(args[i]) != types[i]) return;
    Value inputs[4];
    for (int i = 0; i < 4; ++i) to_type(types[i])(&inputs[i], (void *)args[i]);
    hierarchy_core(&inputs[0], &inputs[1], &inputs[2], &inputs[3]);
    for (int i = 0; i < 4; ++i) get_dtor(types[i])(&inputs[i]);
    error->error = GDEXTENSION_CALL_OK;
}

static void hierarchy_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance; (void)ret;
    hierarchy_core(args[0], args[1], args[2], (void *)args[3]);
}

/* Immediate aiming/firing reads only the socket's ancestor chain. This avoids
 * both SceneTree publication and recursive GDScript global-transform getters. */
static void global_pose_core(const void *poses, const void *parents, int64_t index, float *result) {
    memset(result, 0, 12 * sizeof(float));
    result[0] = result[4] = result[8] = 1;
    int64_t count = count_array((void *)poses), parent_count = 0;
    ints_size((void *)parents, 0, &parent_count, 0);
    if (index < 0 || index >= count || count != parent_count || count > 8192) return;
    const int32_t *parent = ints_index(parents, 0);
    int32_t small_chain[128];
    int32_t *chain = count <= 128 ? small_chain : malloc((size_t)count * sizeof(int32_t));
    if (!chain) return;
    int depth = 0;
    while (index >= 0) {
        chain[depth++] = (int32_t)index;
        if (parent[index] < -1 || parent[index] >= index) { depth = 0; break; }
        index = parent[index];
    }
    while (depth) {
        Value value;
        GDExtensionBool valid = 0;
        get_named(array_index(poses, chain[--depth]), &local_name, &value, &valid);
        if (!valid || get_type(&value) != TYPE(TRANSFORM3D)) { variant_destroy(&value); break; }
        float local[12], composed[12];
        to_type(TYPE(TRANSFORM3D))(local, &value);
        variant_destroy(&value);
        compose_pose(result, local, composed);
        memcpy(result, composed, sizeof(composed));
    }
    if (chain != small_chain) free(chain);
}

static void global_pose_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                             GDExtensionInt argc, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    (void)userdata; (void)instance;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 3 || get_type(args[0]) != TYPE(ARRAY) || get_type(args[1]) != TYPE(PACKED_INT32_ARRAY) || get_type(args[2]) != TYPE(INT)) { variant_nil(ret); return; }
    Value poses, parents;
    int64_t index;
    float result[12];
    to_type(TYPE(ARRAY))(&poses, (void *)args[0]);
    to_type(TYPE(PACKED_INT32_ARRAY))(&parents, (void *)args[1]);
    to_type(TYPE(INT))(&index, (void *)args[2]);
    global_pose_core(&poses, &parents, index, result);
    from_type(TYPE(TRANSFORM3D))(ret, result);
    get_dtor(TYPE(ARRAY))(&poses);
    get_dtor(TYPE(PACKED_INT32_ARRAY))(&parents);
    error->error = GDEXTENSION_CALL_OK;
}

static void global_pose_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args, void *ret) {
    (void)userdata; (void)instance;
    global_pose_core(args[0], args[1], *(const int64_t *)args[2], ret);
}

#include "infantry_pose.h"
#include "runtime_profile.h"
#include "pose_rig.h"
#include "navigation_surface.h"
#include "crowd_runtime.h"
#include "visibility_runtime.h"
#include "unit_state.h"
#include "combat_query.h"
#include "battlefield_index.h"
#include "presentation_batch.h"
#include "state_hash.h"

static GDExtensionObjectPtr create_instance(void *userdata, GDExtensionBool notify) {
    (void)userdata; (void)notify;
    void *owner = construct(&parent_name);
    set_instance(owner, &class_name, owner);
    return owner;
}

static void free_instance(void *userdata, void *instance) { (void)userdata; (void)instance; }

static void initialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    name_new(&class_name, "CopperfinPosePacker");
    name_new(&parent_name, "RefCounted");
    name_new(&pack_name, "pack_poses");
    name_new(&node_name, "Node3D");
    name_new(&transform_name, "get_global_transform");
    name_new(&empty_name, "");
    string_new(&empty_string, "");
    name_new(&entries_name, "entries");
    name_new(&capacity_name, "capacity");
    name_new(&size_name, "size");
    name_new(&resize_name, "resize");
    name_new(&query_name, "nearby_units");
    name_new(&object_name, "Object");
    name_new(&queued_name, "is_queued_for_deletion");
    name_new(&append_name, "append");
    name_new(&has_name, "has");
    name_new(&visible_name, "is_visible_in_tree");
    name_new(&filtered_name, "nearby_units_filtered");
    name_new(&hierarchy_name, "solve_hierarchy");
    name_new(&global_pose_name, "global_pose");
    name_new(&index_name, "index");
    name_new(&local_name, "transform");
    const char *hierarchy_names[] = {"poses", "parents", "anchors", "palette"};
    for (int i = 0; i < 4; ++i) name_new(&hierarchy_args[i], hierarchy_names[i]);
    name_new(&contact_name, "ground_contact");
    name_new(&player_name, "player");
    name_new(&trait_name, "_navigation_trait");
    name_new(&trait_method, "_get_navigation_trait");
    name_new(&domain_name, "domain");
    name_new(&speed_name, "speed");
    name_new(&ghost_name, "ghosted");
    name_new(&radius_name, "radius");
    name_new(&agent_name, "NavigationAgent3D");
    agent_tag = class_tag(&agent_name);
    const char *extra_names[] = {"owner_bits", "allowed", "origin", "next", "neighbors", "unit", "domain", "radius", "margin"};
    for (int i = 0; i < 9; ++i) name_new(&extra_args[i], extra_names[i]);
    const char *argument_names[] = {"cells", "point", "radius", "cell_size", "indexed_reach"};
    for (int i = 0; i < 5; ++i) name_new(&query_args[i], argument_names[i]);
    const char *key_names[] = { "anchors", "offset", "shown", "pulse", "poses" };
    for (int i = 0; i < 5; ++i) {
        Value string;
        string_new(&string, key_names[i]);
        from_type(TYPE(STRING))(&keys[i], &string);
        get_dtor(TYPE(STRING))(&string);
    }
    global_transform = method_bind(&node_name, &transform_name, 3229777777LL);
    visible_in_tree = method_bind(&node_name, &visible_name, 36873697LL);
    node_tag = class_tag(&node_name);
    array_size = get_builtin(TYPE(ARRAY), &size_name, 3173160232LL);
    ints_size = get_builtin(TYPE(PACKED_INT32_ARRAY), &size_name, 3173160232LL);
    bytes_resize = get_builtin(TYPE(PACKED_BYTE_ARRAY), &resize_name, 848867239LL);
    array_append = get_builtin(TYPE(ARRAY), &append_name, 3316032543LL);
    dictionary_has = get_builtin(TYPE(DICTIONARY), &has_name, 3680194679LL);
    queued_for_deletion = method_bind(&object_name, &queued_name, 36873697LL);
    if (!ints_size || !agent_tag || !global_transform || !visible_in_tree || !node_tag || !array_size || !bytes_resize || !array_append || !dictionary_has || !queued_for_deletion) return;
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = create_instance;
    info.free_instance_func = free_instance;
    register_class(library, &class_name, &parent_name, &info);
    class_registered = 1;
    GDExtensionPropertyInfo output = { TYPE(PACKED_BYTE_ARRAY), &empty_name, &empty_name, 0, &empty_string, 6 };
    GDExtensionPropertyInfo arguments[] = {
        { TYPE(ARRAY), &entries_name, &empty_name, 0, &empty_string, 6 },
        { TYPE(INT), &capacity_name, &empty_name, 0, &empty_string, 6 }
    };
    GDExtensionClassMethodArgumentMetadata metadata[2] = {0, 0};
    GDExtensionClassMethodInfo method = {0};
    method.name = &pack_name;
    method.call_func = pack_call;
    method.ptrcall_func = pack_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1;
    method.return_value_info = &output;
    method.argument_count = 2;
    method.arguments_info = arguments;
    method.arguments_metadata = metadata;
    register_method(library, &class_name, &method);
    GDExtensionPropertyInfo query_output = {TYPE(ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo query_arguments[5];
    GDExtensionVariantType types[] = {TYPE(DICTIONARY), TYPE(VECTOR3), TYPE(FLOAT), TYPE(FLOAT), TYPE(FLOAT)};
    GDExtensionClassMethodArgumentMetadata query_metadata[5] = {0};
    for (int i = 0; i < 5; ++i)
        query_arguments[i] = (GDExtensionPropertyInfo){types[i], &query_args[i], &empty_name, 0, &empty_string, 6};
    method.name = &query_name;
    method.call_func = nearby_call;
    method.ptrcall_func = nearby_ptrcall;
    method.return_value_info = &query_output;
    method.argument_count = 5;
    method.arguments_info = query_arguments;
    method.arguments_metadata = query_metadata;
    register_method(library, &class_name, &method);
    GDExtensionPropertyInfo filtered_arguments[7];
    GDExtensionClassMethodArgumentMetadata extra_metadata[7] = {0};
    memcpy(filtered_arguments, query_arguments, sizeof(query_arguments));
    filtered_arguments[5] = (GDExtensionPropertyInfo){TYPE(DICTIONARY), &extra_args[0], &empty_name, 0, &empty_string, 6};
    filtered_arguments[6] = (GDExtensionPropertyInfo){TYPE(INT), &extra_args[1], &empty_name, 0, &empty_string, 6};
    method.name = &filtered_name;
    method.call_func = filtered_call;
    method.ptrcall_func = filtered_ptrcall;
    method.argument_count = 7;
    method.arguments_info = filtered_arguments;
    method.arguments_metadata = extra_metadata;
    register_method(library, &class_name, &method);
    GDExtensionPropertyInfo contact_output = {TYPE(VECTOR4), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionVariantType contact_types[] = {TYPE(VECTOR3), TYPE(VECTOR3), TYPE(ARRAY), TYPE(OBJECT), TYPE(INT), TYPE(FLOAT), TYPE(FLOAT)};
    GDExtensionPropertyInfo contact_arguments[7];
    for (int i = 0; i < 7; ++i)
        contact_arguments[i] = (GDExtensionPropertyInfo){contact_types[i], &extra_args[i + 2], &empty_name, 0, &empty_string, 6};
    contact_arguments[3].class_name = &node_name;
    method.name = &contact_name;
    method.call_func = contact_call;
    method.ptrcall_func = contact_ptrcall;
    method.return_value_info = &contact_output;
    method.arguments_info = contact_arguments;
    register_method(library, &class_name, &method);
    GDExtensionVariantType hierarchy_types[] = {TYPE(ARRAY), TYPE(PACKED_INT32_ARRAY), TYPE(PACKED_INT32_ARRAY), TYPE(ARRAY)};
    GDExtensionPropertyInfo hierarchy_arguments[4];
    for (int i = 0; i < 4; ++i)
        hierarchy_arguments[i] = (GDExtensionPropertyInfo){hierarchy_types[i], &hierarchy_args[i], &empty_name, 0, &empty_string, 6};
    method.name = &hierarchy_name;
    method.call_func = hierarchy_call;
    method.ptrcall_func = hierarchy_ptrcall;
    method.has_return_value = 0;
    method.return_value_info = 0;
    method.argument_count = 4;
    method.arguments_info = hierarchy_arguments;
    register_method(library, &class_name, &method);
    GDExtensionPropertyInfo global_arguments[3] = {hierarchy_arguments[0], hierarchy_arguments[1], {TYPE(INT), &index_name, &empty_name, 0, &empty_string, 6}};
    GDExtensionPropertyInfo global_output = {TYPE(TRANSFORM3D), &empty_name, &empty_name, 0, &empty_string, 6};
    method.name = &global_pose_name;
    method.call_func = global_pose_call;
    method.ptrcall_func = global_pose_ptrcall;
    method.has_return_value = 1;
    method.return_value_info = &global_output;
    method.argument_count = 3;
    method.arguments_info = global_arguments;
    register_method(library, &class_name, &method);
    terrain_sight_initialize();
    terrain_outline_initialize();
    spatial_index_initialize();
    rebase_initialize();
    infantry_initialize();
    runtime_profile_initialize();
    pose_rig_initialize();
    crowd_initialize();
    visibility_initialize();
    unit_state_initialize();
    presentation_initialize();
    state_hash_initialize();
}

static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
    (void)userdata;
    if (level != GDEXTENSION_INITIALIZATION_SCENE) return;
    presentation_deinitialize();
    unit_state_deinitialize();
    visibility_deinitialize();
    pose_rig_deinitialize();
    terrain_sight_deinitialize();
    terrain_outline_deinitialize();
    spatial_index_deinitialize();
    rebase_deinitialize();
    crowd_deinitialize();
    infantry_deinitialize();
    if (class_registered) unregister_class(library, &class_name);
    Value *names[] = { &class_name, &parent_name, &pack_name, &node_name, &transform_name,
                      &empty_name, &entries_name, &capacity_name, &size_name, &resize_name,
                      &query_name, &object_name, &queued_name, &append_name, &has_name, &visible_name,
                      &filtered_name, &contact_name, &player_name, &trait_name, &trait_method,
                      &domain_name, &speed_name, &ghost_name, &radius_name, &agent_name, &hierarchy_name, &local_name, &global_pose_name, &index_name };
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); ++i) get_dtor(TYPE(STRING_NAME))(names[i]);
    get_dtor(TYPE(STRING))(&empty_string);
    for (int i = 0; i < 5; ++i) variant_destroy(&keys[i]);
    for (int i = 0; i < 5; ++i) get_dtor(TYPE(STRING_NAME))(&query_args[i]);
    for (int i = 0; i < 9; ++i) get_dtor(TYPE(STRING_NAME))(&extra_args[i]);
    for (int i = 0; i < 4; ++i) get_dtor(TYPE(STRING_NAME))(&hierarchy_args[i]);
}

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
EXPORT GDExtensionBool copperfin_library_init(GDExtensionInterfaceGetProcAddress proc,
             GDExtensionClassLibraryPtr lib, GDExtensionInitialization *init) {
    library = lib;
#define LOAD(name, suffix, symbol) name = (GDExtensionInterface##suffix)proc(symbol); if (!name) return 0
    LOAD(name_new, StringNameNewWithUtf8Chars, "string_name_new_with_utf8_chars");
    LOAD(string_new, StringNewWithUtf8Chars, "string_new_with_utf8_chars");
    LOAD(from_type, GetVariantFromTypeConstructor, "get_variant_from_type_constructor");
    LOAD(to_type, GetVariantToTypeConstructor, "get_variant_to_type_constructor");
    LOAD(get_ctor, VariantGetPtrConstructor, "variant_get_ptr_constructor");
    LOAD(get_dtor, VariantGetPtrDestructor, "variant_get_ptr_destructor");
    LOAD(get_builtin, VariantGetPtrBuiltinMethod, "variant_get_ptr_builtin_method");
    LOAD(get_type, VariantGetType, "variant_get_type");
    LOAD(variant_destroy, VariantDestroy, "variant_destroy");
    LOAD(variant_nil, VariantNewNil, "variant_new_nil");
    LOAD(get_named, VariantGetNamed, "variant_get_named");
    LOAD(variant_call, VariantCall, "variant_call");
    LOAD(array_index, ArrayOperatorIndexConst, "array_operator_index_const");
    LOAD(array_write, ArrayOperatorIndex, "array_operator_index");
    LOAD(ints_index, PackedInt32ArrayOperatorIndexConst, "packed_int32_array_operator_index_const");
    LOAD(dict_index, DictionaryOperatorIndexConst, "dictionary_operator_index_const");
    LOAD(bytes_index, PackedByteArrayOperatorIndex, "packed_byte_array_operator_index");
    LOAD(object_id, VariantGetObjectInstanceId, "variant_get_object_instance_id");
    LOAD(object_from_id, ObjectGetInstanceFromId, "object_get_instance_from_id");
    LOAD(object_cast, ObjectCastTo, "object_cast_to");
    LOAD(class_tag, ClassdbGetClassTag, "classdb_get_class_tag");
    LOAD(method_bind, ClassdbGetMethodBind, "classdb_get_method_bind");
    LOAD(ptrcall, ObjectMethodBindPtrcall, "object_method_bind_ptrcall");
    LOAD(construct, ClassdbConstructObject2, "classdb_construct_object2");
    LOAD(set_instance, ObjectSetInstance, "object_set_instance");
    LOAD(register_class, ClassdbRegisterExtensionClass4, "classdb_register_extension_class4");
    LOAD(register_method, ClassdbRegisterExtensionClassMethod, "classdb_register_extension_class_method");
    LOAD(unregister_class, ClassdbUnregisterExtensionClass, "classdb_unregister_extension_class");
    if (!terrain_sight_load(proc)) return 0;
    if (!terrain_outline_load(proc)) return 0;
    if (!spatial_index_load(proc)) return 0;
    if (!rebase_load(proc)) return 0;
    if (!infantry_load(proc)) return 0;
    if (!runtime_profile_load(proc)) return 0;
    if (!pose_rig_load(proc)) return 0;
    if (!crowd_load(proc)) return 0;
    if (!visibility_load(proc)) return 0;
    if (!state_hash_load(proc)) return 0;
    init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    init->userdata = 0;
    init->initialize = initialize;
    init->deinitialize = deinitialize;
    return 1;
}
