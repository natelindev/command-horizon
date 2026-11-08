/* Node-free chassis dynamics. ChassisMotion.gd remains the reference/fallback;
 * this object preserves its state and methods while keeping spring integration
 * and idle/recoil sampling inside one native call. Separate bodies may be solved
 * by separate workers, and the batch entry point never reads scene nodes. */
#include <stddef.h>
#define CM_BODY 1003
#define CM_PI 3.14159265358979323846
#define CM_TAU (2.0 * CM_PI)
#define CM_RECOVERY .4
#define CM_SCALARS(X) \
    X(forward_speed) X(yaw_lag) X(pitch) X(pitch_velocity) X(roll) X(roll_velocity) \
    X(heave) X(heave_velocity) X(engine) X(idle) X(clock) X(max_speed) X(length) \
    X(_recoil_age) X(_recoil_strength) X(_root_yaw) X(_root_rate) X(_visual_yaw) \
    X(_visual_rate) X(_step) X(_velocity_weight) X(_accel_weight) X(_rate_weight) \
    X(_body_decay) X(_body_cos) X(_body_sin) X(_heave_cos) X(_heave_sin)
typedef struct {
    int binding_kind;
#define CM_MEMBER(name) double name;
    CM_SCALARS(CM_MEMBER)
#undef CM_MEMBER
    int64_t kind, damage_band;
    IpV velocity, _recoil_direction, _drift;
    float accel[2];
    IpT _previous;
    GDExtensionBool _started, _floating, _engine_driven;
    double _tuning[8];
    Value damage_faction;
    int faction;
} CmBody;
static const double cm_tuning[6][8] = {
    {10, .55, 8, .42, .0045, .0035, .055, .14},
    {12, .5, 10, .38, .005, .0045, .06, .12},
    {8.5, .7, 5, .3, .006, -.008, .1, .16},
    {10, .6, 9, .5, .003, .003, .04, .12},
    {7.5, .8, 7, .6, -.009, -.022, .42, .12},
    {17, 1.3, 14, .7, .012, .012, .12, .08}};
typedef struct {
    const char *name;
    GDExtensionVariantType type;
    size_t offset;
} CmField;
#define CM_FIELD(name, type) {#name, TYPE(type), offsetof(CmBody, name)}
#define CM_FLOAT(name) CM_FIELD(name, FLOAT),
static const CmField cm_fields[] = {
    CM_SCALARS(CM_FLOAT)
    CM_FIELD(kind, INT), CM_FIELD(damage_band, INT), CM_FIELD(velocity, VECTOR3),
    CM_FIELD(_recoil_direction, VECTOR3), CM_FIELD(_drift, VECTOR3), CM_FIELD(accel, VECTOR2),
    CM_FIELD(_previous, TRANSFORM3D), CM_FIELD(_started, BOOL), CM_FIELD(_floating, BOOL),
    CM_FIELD(_engine_driven, BOOL), CM_FIELD(_tuning, PACKED_FLOAT64_ARRAY),
    CM_FIELD(damage_faction, STRING), {"Kind", TYPE(DICTIONARY), 0},
    {"CANNON_RECOVERY", TYPE(FLOAT), 0}};
#undef CM_FIELD
#undef CM_FLOAT
#define CM_FIELD_COUNT (sizeof(cm_fields) / sizeof(cm_fields[0]))
#define CM_PROPERTY_CAPACITY 128
static GDExtensionPtrBuiltInMethod cm_name_hash;
static unsigned char cm_property_slots[CM_PROPERTY_CAPACITY];
_Static_assert(CM_FIELD_COUNT < CM_PROPERTY_CAPACITY / 2, "Chassis property table is too small");
static Value cm_class, cm_properties[CM_FIELD_COUNT], cm_methods[15], cm_arguments[7],
    cm_profile_names[3], cm_job_names[4], cm_factions[2], cm_kind;
static GDExtensionInterfaceDictionaryOperatorIndex cm_dict_write;
static int cm_initialized, cm_registered;

static int cm_equal(double a, double b) {
    return a == b || fabs(a - b) < fmax(.00001, .00001 * fabs(a));
}
static double cm_angle(double from, double to) {
    double d = fmod(to - from, CM_TAU);
    return fmod(2 * d, CM_TAU) - d;
}
static double cm_wrap(double angle) {
    double result = angle - CM_TAU * floor((angle + CM_PI) / CM_TAU);
    return cm_equal(result, CM_PI) ? -CM_PI : result;
}
static void cm_smoothing(CmBody *b, double step) {
    b->_step = step;
    b->_velocity_weight = 1 - exp(-step / b->_tuning[7]);
    b->_accel_weight = 1 - exp(-step / .08);
    b->_rate_weight = 1 - exp(-step / .06);
    double body = b->_tuning[2], damping = b->_tuning[3] * body;
    double frequency = sqrt(body * body - damping * damping);
    double heave_frequency = sqrt(body * body * 1.5 - damping * damping);
    b->_body_decay = exp(-damping * step);
    b->_body_cos = cos(frequency * step);
    b->_body_sin = sin(frequency * step) / frequency;
    b->_heave_cos = cos(heave_frequency * step);
    b->_heave_sin = sin(heave_frequency * step) / heave_frequency;
}
static void cm_reset(CmBody *b, IpT current) {
    b->_previous = current;
    b->_root_yaw = atan2(current.b.v[2], current.b.v[8]);
    b->_visual_yaw = b->_root_yaw;
    b->_visual_rate = b->_root_rate = 0;
    b->_started = 1;
    b->velocity = ipv(0, 0, 0);
    b->accel[0] = b->accel[1] = 0;
    b->forward_speed = b->yaw_lag = 0;
}
static void cm_clamp(CmBody *b, double limit) {
    b->yaw_lag = cm_angle(b->_root_yaw, b->_visual_yaw);
    if (fabs(b->yaw_lag) > limit) {
        b->yaw_lag = ipclamp(b->yaw_lag, -limit, limit);
        b->_visual_yaw = b->_root_yaw + b->yaw_lag;
        b->_visual_rate = ipmix(b->_visual_rate, b->_root_rate, .5);
    }
}
static void cm_integrate(CmBody *b, double step) {
    double omega = b->_tuning[0], error = cm_angle(b->_visual_yaw, b->_root_yaw);
    double target_error = -error - 2 * b->_root_rate / omega;
    double coefficient = b->_visual_rate + omega * target_error, decay = exp(-omega * step);
    double new_error = (target_error + coefficient * step) * decay;
    b->_visual_yaw = cm_wrap(b->_visual_yaw + new_error - target_error);
    b->_visual_rate = (b->_visual_rate - omega * coefficient * step) * decay;
    cm_clamp(b, b->_tuning[1]);
    double limit = b->_tuning[6];
    double brake = b->kind == 0 && b->forward_speed * b->accel[0] < 0 ? 1.55 : 1;
    double pitch_target = ipclamp(b->accel[0] * b->_tuning[4] * brake, -limit * brake, limit);
    double roll_target = ipclamp(b->accel[1] * b->_tuning[5], -limit, limit);
    if (b->kind == 4)
        pitch_target = ipclamp(pitch_target - .1 * ipclamp(b->forward_speed / b->max_speed, -1, 1),
                               -limit, limit);
    double body = b->_tuning[2], damping = b->_tuning[3] * body;
    double pe = b->pitch - pitch_target, re = b->roll - roll_target;
    double pitch = pitch_target + b->_body_decay *
        (pe * b->_body_cos + (b->pitch_velocity + damping * pe) * b->_body_sin);
    double roll = roll_target + b->_body_decay *
        (re * b->_body_cos + (b->roll_velocity + damping * re) * b->_body_sin);
    b->pitch_velocity = b->_body_decay * (b->pitch_velocity * b->_body_cos -
        (damping * b->pitch_velocity + body * body * pe) * b->_body_sin);
    b->roll_velocity = b->_body_decay * (b->roll_velocity * b->_body_cos -
        (damping * b->roll_velocity + body * body * re) * b->_body_sin);
    double heave = b->_body_decay *
        (b->heave * b->_heave_cos + (b->heave_velocity + damping * b->heave) * b->_heave_sin);
    b->heave_velocity = b->_body_decay * (b->heave_velocity * b->_heave_cos -
        (damping * b->heave_velocity + body * body * 1.5 * b->heave) * b->_heave_sin);
    b->pitch = pitch;
    b->roll = roll;
    b->heave = heave;
}
static void cm_advance(CmBody *b, double delta, IpT current) {
    if (delta <= 0)
        return;
    b->_recoil_age = fmin(CM_RECOVERY, b->_recoil_age + delta);
    if (!b->_started)
        cm_reset(b, current);
    b->clock += delta;
    IpV travel = ips(current.p, b->_previous.p);
    travel.y = 0;
    double yaw = atan2(current.b.v[2], current.b.v[8]);
    double turn = cm_angle(b->_root_yaw, yaw) / delta;
    b->_previous = current;
    b->_root_yaw = yaw;
    double limit = fmax(1, b->max_speed * delta * 4);
    if (ipdot(travel, travel) > limit * limit) {
        cm_reset(b, current);
        return;
    }
    if (fabs(turn) > 4)
        turn = 0;
    IpV forward = ipv(-sin(yaw), 0, -cos(yaw)), right = ipv(-forward.z, 0, forward.x);
    float dt = (float)delta;
    IpV raw = ipv(travel.x / dt, travel.y / dt, travel.z / dt);
    if (!cm_equal(delta, b->_step))
        cm_smoothing(b, delta);
    IpV old = b->velocity;
    b->velocity = iplerp(b->velocity, raw, b->_velocity_weight);
    IpV change = ips(b->velocity, old);
    change = ipv(change.x / dt, change.y / dt, change.z / dt);
    float weight = (float)b->_accel_weight;
    b->accel[0] += (ipdot(change, forward) - b->accel[0]) * weight;
    b->accel[1] += (ipdot(change, right) - b->accel[1]) * weight;
    b->_root_rate = ipmix(b->_root_rate, turn, b->_rate_weight);
    cm_integrate(b, delta);
    b->forward_speed = ipdot(b->velocity, forward);
    b->engine = ipdot(raw, raw) > .0004 ? 1 : ipmove(b->engine, 0, delta / 1.5);
}
static double cm_running(CmBody *b) { return b->_engine_driven ? fmax(b->engine, b->idle * .6) : 0; }
static double cm_spring(CmBody *b) {
    double t = b->_recoil_age / CM_RECOVERY;
    return sin(CM_TAU * t) * exp(-5 * t) * (1 - t) * (1 - t) * b->_recoil_strength;
}
static int cm_settled(CmBody *b) {
    if (b->_floating || cm_running(b) > 0 || b->damage_band > 0 || b->_recoil_age < CM_RECOVERY)
        return 0;
    return fabs(b->yaw_lag) <= .0001 && fabs(b->_visual_rate) <= .0001 &&
        fabs(b->_root_rate) <= .0001 && fabs(b->pitch) <= .0001 &&
        fabs(b->pitch_velocity) <= .0001 && fabs(b->roll) <= .0001 &&
        fabs(b->roll_velocity) <= .0001 && fabs(b->heave) <= .0001 && fabs(b->heave_velocity) <= .0001;
}
static void cm_settle(CmBody *b) {
    b->_recoil_age = CM_RECOVERY;
    b->_visual_yaw = b->_root_yaw;
    b->_visual_rate = b->_root_rate = b->yaw_lag = 0;
    b->pitch = b->pitch_velocity = b->roll = b->roll_velocity = b->heave = b->heave_velocity = 0;
}
static IpV cm_rotation(CmBody *b, double extra) {
    double running = cm_running(b), rumble = 0;
    if (running > 0)
        rumble = running * (sin(b->clock * 31) + sin(b->clock * 47 + 1.3)) * .0007;
    double bank = b->roll, nose = b->pitch + extra;
    if (b->kind == 2) {
        nose += sin(b->clock * b->_drift.z * 1.7) * .012;
        bank += sin(b->clock * b->_drift.x * 1.4 + .8) * .016;
    } else if (b->kind == 4) {
        nose += sin(b->clock * b->_drift.z * 1.3) * .02;
        bank += sin(b->clock * b->_drift.x * 1.9 + .4) * .03;
    }
    if (b->faction == 1 && b->damage_band == 2) {
        if (b->kind == 2) {
            nose += sin(b->clock * 5.3) * .018;
            bank += sin(b->clock * 3.7 + .8) * .025;
        } else if (b->kind == 3)
            bank += sin(b->clock * 19) * .003;
    } else if (b->faction == 2 && b->damage_band > 0)
        rumble += sin(b->clock * 43) * (b->damage_band == 1 ? .0015 : .004);
    double recoil = cm_spring(b);
    return ipv(nose + rumble - b->_recoil_direction.z * recoil * .12, b->yaw_lag,
                bank + rumble * .6 + b->_recoil_direction.x * recoil * .12);
}
static IpV cm_position(CmBody *b) {
    double lift = b->heave;
    if (!b->_floating) {
        lift += (fabs(b->pitch) * b->length + fabs(b->roll) * b->length * .6) * .32;
        lift += cm_running(b) * sin(b->clock * 39) * .0012;
        double recoil = cm_spring(b);
        /* Keep the two Vector3 scalar operations in the reference order. */
        return ipa(ipm(ipm(b->_recoil_direction, -recoil), .32),
                    ipv(0, lift - fabs(recoil) * .06, 0));
    }
    if (b->kind == 2)
        return ipv(0, lift + sin(b->clock * b->_drift.y * 2.1) * .03 +
            sin(b->clock * b->_drift.x * 3.3) * .008 +
            (b->damage_band == 2 && b->faction == 1 ? sin(b->clock * 4.7) * .025 : 0), 0);
    if (b->kind == 4) {
        double calm = 1 - ipclamp(fabs(b->forward_speed) / b->max_speed, 0, 1) * .6;
        return ipv(sin(b->clock * b->_drift.x) * .04 * calm,
                    lift + sin(b->clock * b->_drift.y * 1.6) * .045,
                    sin(b->clock * b->_drift.z + 1.1) * .04 * calm);
    }
    return ipv(0, lift, 0);
}

static int cm_property(const void *name) {
    if (cm_name_hash) {
        int64_t hash = 0;
        cm_name_hash((void *)name, 0, &hash, 0);
        unsigned slot = (unsigned)hash & (CM_PROPERTY_CAPACITY - 1);
        while (cm_property_slots[slot]) {
            int index = cm_property_slots[slot] - 1;
            GDExtensionBool same = 0;
            rp_equal(name, &cm_properties[index], &same);
            if (same)
                return index;
            slot = (slot + 1) & (CM_PROPERTY_CAPACITY - 1);
        }
        return -1;
    }
    for (unsigned i = 0; i < CM_FIELD_COUNT; i++) {
        GDExtensionBool same = 0;
        rp_equal(name, &cm_properties[i], &same);
        if (same)
            return (int)i;
    }
    return -1;
}
static GDExtensionBool cm_get(void *instance, const void *name, void *ret) {
    CmBody *b = instance;
    int index = cm_property(name);
    if (index < 0)
        return 0;
    const CmField *field = &cm_fields[index];
    variant_destroy(ret);
    if (index == (int)CM_FIELD_COUNT - 1) {
        double recovery = CM_RECOVERY;
        from_type(TYPE(FLOAT))(ret, &recovery);
    } else if (field->type == TYPE(DICTIONARY))
        from_type(TYPE(DICTIONARY))(ret, &cm_kind);
    else if (field->type == TYPE(PACKED_FLOAT64_ARRAY)) {
        Value array, tuning;
        get_ctor(TYPE(ARRAY), 0)(&array, 0);
        for (int i = 0; i < 8; i++) {
            Value value;
            from_type(TYPE(FLOAT))(&value, &b->_tuning[i]);
            array_append(&array, (const void *[]){&value}, 0, 1);
            variant_destroy(&value);
        }
        get_ctor(TYPE(PACKED_FLOAT64_ARRAY), 2)(&tuning, (const void *[]){&array});
        from_type(TYPE(PACKED_FLOAT64_ARRAY))(ret, &tuning);
        get_dtor(TYPE(PACKED_FLOAT64_ARRAY))(&tuning);
        get_dtor(TYPE(ARRAY))(&array);
    } else
        from_type(field->type)(ret, (char *)b + field->offset);
    return 1;
}
static GDExtensionBool cm_set(void *instance, const void *name, const void *value) {
    CmBody *b = instance;
    int index = cm_property(name);
    if (index < 0 || index >= (int)CM_FIELD_COUNT - 2)
        return 0;
    const CmField *field = &cm_fields[index];
    void *destination = (char *)b + field->offset;
    if (field->type == TYPE(FLOAT))
        return index_number(value, destination);
    if (get_type(value) != field->type)
        return 0;
    if (field->type == TYPE(PACKED_FLOAT64_ARRAY)) {
        Value tuning;
        to_type(TYPE(PACKED_FLOAT64_ARRAY))(&tuning, (void *)value);
        int64_t size = 0;
        ip_doubles_size(&tuning, 0, &size, 0);
        if (size == 8)
            memcpy(b->_tuning, ip_doubles(&tuning, 0), sizeof(b->_tuning));
        get_dtor(TYPE(PACKED_FLOAT64_ARRAY))(&tuning);
        return size == 8;
    }
    if (field->type == TYPE(STRING)) {
        get_dtor(TYPE(STRING))(&b->damage_faction);
        to_type(TYPE(STRING))(&b->damage_faction, (void *)value);
        b->faction = 0;
        for (int i = 0; i < 2; i++) {
            GDExtensionBool same = 0;
            us_string_equal(&b->damage_faction, &cm_factions[i], &same);
            if (same)
                b->faction = i + 1;
        }
        return 1;
    }
    to_type(field->type)(destination, (void *)value);
    return 1;
}
static void *cm_create(void *userdata, GDExtensionBool notify) {
    (void)userdata;
    (void)notify;
    CmBody *b = calloc(1, sizeof(CmBody));
    if (!b)
        return 0;
    b->binding_kind = CM_BODY;
    b->max_speed = 4;
    b->length = 2;
    b->_recoil_age = CM_RECOVERY;
    b->_recoil_direction = ipv(0, 0, -1);
    b->_drift = ipv(1, 1, 1);
    b->_previous = rp_identity();
    b->_engine_driven = 1;
    memcpy(b->_tuning, cm_tuning[0], sizeof(b->_tuning));
    get_ctor(TYPE(STRING), 0)(&b->damage_faction, 0);
    void *owner = construct(&parent_name);
    set_instance(owner, &cm_class, b);
    rp_set_binding(owner, library, b, &rp_callbacks);
    return owner;
}
static void cm_free(void *userdata, void *instance) {
    (void)userdata;
    CmBody *b = instance;
    get_dtor(TYPE(STRING))(&b->damage_faction);
    free(b);
}
static int cm_read(const void *object, const Value *name, Value *result) {
    GDExtensionBool valid = 0;
    get_named(object, name, result, &valid);
    return valid;
}
static void cm_batch(const void *jobs, void *remaining) {
    get_ctor(TYPE(ARRAY), 0)(remaining, 0);
    int64_t count = count_array((void *)jobs);
    for (int64_t i = 0; i < count; i++) {
        const void *job = array_index(jobs, i);
        Value chassis, root, delta, mode;
        int valid = cm_read(job, &cm_job_names[0], &chassis);
        valid &= cm_read(job, &cm_job_names[1], &root);
        valid &= cm_read(job, &cm_job_names[2], &delta);
        valid &= cm_read(job, &cm_job_names[3], &mode);
        void *owner = get_type(&chassis) == TYPE(OBJECT) ? object_from_id(object_id(&chassis)) : 0;
        CmBody *b = owner ? rp_get_binding(owner, library, 0) : 0;
        double dt;
        valid = valid && b && b->binding_kind == CM_BODY && get_type(&root) == TYPE(TRANSFORM3D) &&
            get_type(&mode) == TYPE(INT) && index_number(&delta, &dt);
        if (valid) {
            IpT transform;
            int64_t action;
            to_type(TYPE(TRANSFORM3D))(&transform, &root);
            to_type(TYPE(INT))(&action, &mode);
            if (action == 1)
                cm_reset(b, transform);
            else if (action == 2)
                b->clock += dt;
            else if (action == 3)
                cm_advance(b, dt, transform);
        } else
            array_append(remaining, (const void *[]){job}, 0, 1);
        variant_destroy(&chassis);
        variant_destroy(&root);
        variant_destroy(&delta);
        variant_destroy(&mode);
    }
}
static void cm_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                    GDExtensionInt count, GDExtensionVariantPtr ret, GDExtensionCallError *error) {
    CmBody *b = instance;
    int method = (int)(intptr_t)userdata;
    const int counts[] = {4, 1, 1, 2, 1, 1, 2, 2, 0, 0, 0, 0, 1, 0, 1};
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    variant_nil(ret);
    if (count != counts[method] && !(method == 12 && count == 0))
        return;
    double n = 0;
    IpT transform;
    IpV vector;
    if (method == 0) {
        int64_t kind;
        double speed, length;
        if (get_type(args[0]) != TYPE(INT) || !index_number(args[2], &speed) ||
            !index_number(args[3], &length))
            return;
        to_type(TYPE(INT))(&kind, (void *)args[0]);
        if (kind < 0 || kind >= 6)
            return;
        Value yaw, drift, phase;
        int valid = cm_read(args[1], &cm_profile_names[0], &yaw);
        valid &= cm_read(args[1], &cm_profile_names[1], &drift);
        valid &= cm_read(args[1], &cm_profile_names[2], &phase);
        double response, clock;
        valid = valid && index_number(&yaw, &response) && index_number(&phase, &clock) &&
            get_type(&drift) == TYPE(VECTOR3);
        if (valid) {
            b->kind = kind;
            memcpy(b->_tuning, cm_tuning[kind], sizeof(b->_tuning));
            b->_tuning[0] *= response;
            to_type(TYPE(VECTOR3))(&b->_drift, &drift);
            b->clock = clock;
            b->max_speed = fmax(.5, speed);
            b->length = length;
            b->_floating = kind == 2 || kind == 4;
            b->_engine_driven = kind == 0 || kind == 1;
            cm_smoothing(b, 1.0 / 60.0);
        }
        variant_destroy(&yaw);
        variant_destroy(&drift);
        variant_destroy(&phase);
        if (!valid)
            return;
    } else if (method == 2) {
        if (get_type(args[0]) != TYPE(TRANSFORM3D))
            return;
        to_type(TYPE(TRANSFORM3D))(&transform, (void *)args[0]);
        cm_reset(b, transform);
    } else if (method == 3) {
        if (!index_number(args[0], &n) || get_type(args[1]) != TYPE(TRANSFORM3D))
            return;
        to_type(TYPE(TRANSFORM3D))(&transform, (void *)args[1]);
        cm_advance(b, n, transform);
    } else if (method == 1 || method == 4 || method == 5) {
        if (!index_number(args[0], &n))
            return;
        if (method == 1)
            cm_smoothing(b, n);
        else if (method == 4)
            cm_integrate(b, n);
        else
            cm_clamp(b, n);
    } else if (method == 6 || method == 7) {
        if (get_type(args[0]) != TYPE(VECTOR3) || !index_number(args[1], &n))
            return;
        to_type(TYPE(VECTOR3))(&vector, (void *)args[0]);
        if (method == 6) {
            b->pitch_velocity += vector.z * n;
            b->roll_velocity -= vector.x * n;
            b->heave_velocity -= n * .25;
        } else {
            vector.y = 0;
            b->_recoil_direction = ipnorm(vector);
            b->_recoil_strength = n;
            b->_recoil_age = 0;
        }
    } else if (method == 8 || method == 11) {
        n = method == 8 ? cm_spring(b) : cm_running(b);
        variant_destroy(ret);
        from_type(TYPE(FLOAT))(ret, &n);
    } else if (method == 9) {
        GDExtensionBool settled = cm_settled(b);
        variant_destroy(ret);
        from_type(TYPE(BOOL))(ret, &settled);
    } else if (method == 10)
        cm_settle(b);
    else if (method == 12 || method == 13) {
        if (method == 12 && count && !index_number(args[0], &n))
            return;
        vector = method == 12 ? cm_rotation(b, n) : cm_position(b);
        variant_destroy(ret);
        from_type(TYPE(VECTOR3))(ret, &vector);
    } else if (method == 14) {
        if (get_type(args[0]) != TYPE(ARRAY))
            return;
        Value jobs, remaining;
        to_type(TYPE(ARRAY))(&jobs, (void *)args[0]);
        cm_batch(&jobs, &remaining);
        variant_destroy(ret);
        from_type(TYPE(ARRAY))(ret, &remaining);
        get_dtor(TYPE(ARRAY))(&remaining);
        get_dtor(TYPE(ARRAY))(&jobs);
    }
    error->error = GDEXTENSION_CALL_OK;
}
static int chassis_load(GDExtensionInterfaceGetProcAddress proc) {
    cm_dict_write = (GDExtensionInterfaceDictionaryOperatorIndex)proc("dictionary_operator_index");
    return cm_dict_write != 0;
}
static void chassis_initialize(void) {
    name_new(&cm_class, "CopperfinChassisMotion");
    for (unsigned i = 0; i < CM_FIELD_COUNT; i++)
        name_new(&cm_properties[i], cm_fields[i].name);
    /* The immutable index uses only the public StringName ABI. Hot property
     * reads no longer cross the ABI once for each preceding field name. */
    Value hash_name;
    name_new(&hash_name, "hash");
    cm_name_hash = get_builtin(TYPE(STRING_NAME), &hash_name, 3173160232);
    get_dtor(TYPE(STRING_NAME))(&hash_name);
    memset(cm_property_slots, 0, sizeof(cm_property_slots));
    if (cm_name_hash) {
        for (unsigned i = 0; i < CM_FIELD_COUNT; i++) {
            int64_t hash = 0;
            cm_name_hash(&cm_properties[i], 0, &hash, 0);
            unsigned slot = (unsigned)hash & (CM_PROPERTY_CAPACITY - 1);
            while (cm_property_slots[slot])
                slot = (slot + 1) & (CM_PROPERTY_CAPACITY - 1);
            cm_property_slots[slot] = (unsigned char)(i + 1);
        }
    }
    const char *methods[] = {"configure", "_smoothing", "reset", "advance", "_integrate",
        "clamp_lag", "impulse", "cannon_recoil", "_cannon_spring", "is_settled", "settle",
        "_running", "offset_rotation", "offset_position", "solve_batch"};
    const char *arguments[] = {"kind", "profile", "speed", "length", "delta", "root", "jobs"};
    const char *profile[] = {"yaw_response", "drift_rates", "phase"};
    const char *jobs[] = {"chassis", "root", "delta", "mode"};
    for (int i = 0; i < 15; i++)
        name_new(&cm_methods[i], methods[i]);
    for (int i = 0; i < 7; i++)
        name_new(&cm_arguments[i], arguments[i]);
    for (int i = 0; i < 3; i++)
        name_new(&cm_profile_names[i], profile[i]);
    for (int i = 0; i < 4; i++)
        name_new(&cm_job_names[i], jobs[i]);
    string_new(&cm_factions[0], "helix");
    string_new(&cm_factions[1], "frontier");
    get_ctor(TYPE(DICTIONARY), 0)(&cm_kind, 0);
    const char *kinds[] = {"TRACKED", "WHEELED", "HOVER", "WALKER", "AIR", "INFANTRY"};
    for (int64_t i = 0; i < 6; i++) {
        Value text, key;
        string_new(&text, kinds[i]);
        from_type(TYPE(STRING))(&key, &text);
        void *value = cm_dict_write(&cm_kind, &key);
        variant_destroy(value);
        from_type(TYPE(INT))(value, &i);
        variant_destroy(&key);
        get_dtor(TYPE(STRING))(&text);
    }
    Value kinds_value, readonly_name, result;
    from_type(TYPE(DICTIONARY))(&kinds_value, &cm_kind);
    name_new(&readonly_name, "make_read_only");
    GDExtensionCallError call_error = {0};
    variant_call(&kinds_value, &readonly_name, 0, 0, &result, &call_error);
    variant_destroy(&result);
    variant_destroy(&kinds_value);
    get_dtor(TYPE(STRING_NAME))(&readonly_name);
    cm_initialized = 1;
    GDExtensionClassCreationInfo4 info = {0};
    info.is_exposed = 1;
    info.create_instance_func = cm_create;
    info.free_instance_func = cm_free;
    info.get_func = cm_get;
    info.set_func = cm_set;
    register_class(library, &cm_class, &parent_name, &info);
    cm_registered = 1;
    const int counts[] = {4, 1, 1, 2, 1, 1, 2, 2, 0, 0, 0, 0, 1, 0, 1};
    const GDExtensionVariantType types[15][4] = {
        {TYPE(INT), TYPE(OBJECT), TYPE(FLOAT), TYPE(FLOAT)}, {TYPE(FLOAT)}, {TYPE(TRANSFORM3D)},
        {TYPE(FLOAT), TYPE(TRANSFORM3D)}, {TYPE(FLOAT)}, {TYPE(FLOAT)},
        {TYPE(VECTOR3), TYPE(FLOAT)}, {TYPE(VECTOR3), TYPE(FLOAT)}, {}, {}, {}, {}, {TYPE(FLOAT)}, {}, {TYPE(ARRAY)}};
    const GDExtensionVariantType outputs[] = {TYPE(NIL), TYPE(NIL), TYPE(NIL), TYPE(NIL),
        TYPE(NIL), TYPE(NIL), TYPE(NIL), TYPE(NIL), TYPE(FLOAT), TYPE(BOOL), TYPE(NIL), TYPE(FLOAT),
        TYPE(VECTOR3), TYPE(VECTOR3), TYPE(ARRAY)};
    const int names[15][4] = {{0, 1, 2, 3}, {4}, {5}, {4, 5}, {4}, {4}, {5, 2}, {5, 2}, {}, {}, {}, {}, {4}, {}, {6}};
    for (int i = 0; i < 15; i++) {
        GDExtensionPropertyInfo parameters[4];
        GDExtensionClassMethodArgumentMetadata metadata[4] = {0};
        for (int j = 0; j < counts[i]; j++)
            parameters[j] = (GDExtensionPropertyInfo){
                types[i][j], &cm_arguments[names[i][j]], &empty_name, 0, &empty_string, 6};
        GDExtensionPropertyInfo output = {outputs[i], &empty_name, &empty_name, 0, &empty_string, 6};
        GDExtensionClassMethodInfo method = {0};
        method.name = &cm_methods[i];
        method.method_userdata = (void *)(intptr_t)i;
        method.call_func = cm_call;
        method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
        method.argument_count = counts[i];
        method.arguments_info = parameters;
        method.arguments_metadata = metadata;
        method.has_return_value = outputs[i] != TYPE(NIL);
        method.return_value_info = method.has_return_value ? &output : 0;
        Value zero;
        double n = 0;
        from_type(TYPE(FLOAT))(&zero, &n);
        void *defaults[] = {&zero};
        if (i == 12) {
            method.default_argument_count = 1;
            method.default_arguments = defaults;
        }
        register_method(library, &cm_class, &method);
        variant_destroy(&zero);
    }
}
static void chassis_deinitialize(void) {
    if (!cm_initialized)
        return;
    if (cm_registered)
        unregister_class(library, &cm_class);
    for (unsigned i = 0; i < CM_FIELD_COUNT; i++)
        get_dtor(TYPE(STRING_NAME))(&cm_properties[i]);
    for (int i = 0; i < 15; i++)
        get_dtor(TYPE(STRING_NAME))(&cm_methods[i]);
    for (int i = 0; i < 7; i++)
        get_dtor(TYPE(STRING_NAME))(&cm_arguments[i]);
    for (int i = 0; i < 3; i++)
        get_dtor(TYPE(STRING_NAME))(&cm_profile_names[i]);
    for (int i = 0; i < 4; i++)
        get_dtor(TYPE(STRING_NAME))(&cm_job_names[i]);
    for (int i = 0; i < 2; i++)
        get_dtor(TYPE(STRING))(&cm_factions[i]);
    get_dtor(TYPE(DICTIONARY))(&cm_kind);
    get_dtor(TYPE(STRING_NAME))(&cm_class);
    cm_initialized = cm_registered = 0;
}
#undef CM_SCALARS
