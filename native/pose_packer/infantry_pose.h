/* Whole infantry gait/IK solve over a compact, node-free working set.
 * Script objects are sampled/published only at the boundary. No engine-internal
 * layouts, SceneTree calls, worker access to nodes, or retained borrowed arrays.
 * The GDScript solver remains the reference and fallback. */
typedef struct {
    float x, y, z;
} IpV;
typedef struct {
    float v[9];
} IpB;
typedef struct {
    IpB b;
    IpV p;
} IpT;
static Value ip_method, ip_argument, ip_fields[29], ip_job_fields[10];
static GDExtensionInterfaceVariantSetNamed ip_set_named;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst ip_doubles;
static GDExtensionPtrBuiltInMethod ip_doubles_size;
static int ip_initialized;
enum {
    IP_BLEND,
    IP_PHASE,
    IP_SPEED,
    IP_AIM,
    IP_BRACE,
    IP_STRIDE,
    IP_LEAD,
    IP_MIX,
    IP_SETTLE_FOOT,
    IP_SETTLE_TIME,
    IP_HEIGHT,
    IP_MOVING,
    IP_IDLE,
    IP_SUPPRESS_TARGET,
    IP_PIN_TARGET,
    IP_SUPPRESS,
    IP_PIN,
    IP_TURN,
    IP_FIDGET,
    IP_LEAN,
    IP_FLINCH,
    IP_SETTLE_FROM,
    IP_FEET,
    IP_STANCE,
    IP_START,
    IP_POSED_PELVIS,
    IP_POSED_CARRY,
    IP_POSED_FEET,
    IP_TRANSFORM
};
enum {
    IP_MOTION,
    IP_PARTS,
    IP_CONFIG,
    IP_DT,
    IP_DISTANCE,
    IP_CLOCK,
    IP_GESTURE,
    IP_RECOIL,
    IP_AIMING,
    IP_SOLVED
};
static IpV ipv(double x, double y, double z) { return (IpV){(float)x, (float)y, (float)z}; }
static IpV ipa(IpV a, IpV b) { return ipv(a.x + b.x, a.y + b.y, a.z + b.z); }
static IpV ips(IpV a, IpV b) { return ipv(a.x - b.x, a.y - b.y, a.z - b.z); }
static IpV ipm(IpV a, double k) {
    float f = (float)k;
    return ipv(a.x * f, a.y * f, a.z * f);
}
static float ipdot(IpV a, IpV b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static float iplen(IpV a) { return sqrtf(ipdot(a, a)); }
static IpV ipnorm(IpV a) {
    float l = iplen(a);
    return l ? ipv(a.x / l, a.y / l, a.z / l) : ipv(0, 0, 0);
}
static IpV iplerp(IpV a, IpV b, double k) { return ipa(a, ipm(ips(b, a), k)); }
static double ipclamp(double x, double a, double b) { return fmin(b, fmax(a, x)); }
static double ipmix(double a, double b, double t) { return a + (b - a) * t; }
static double ipmove(double a, double b, double t) {
    return fabs(b - a) <= t ? b : a + copysign(t, b - a);
}
static double ipsmooth(double x) {
    x = ipclamp(x, 0, 1);
    return x * x * (3 - 2 * x);
}
static double ipmod(double x, double m) {
    double r = fmod(x, m);
    return r < 0 ? r + m : r;
}
static IpB ipmul(IpB a, IpB b) {
    IpB c;
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
            c.v[y * 3 + x] =
                a.v[y * 3] * b.v[x] + a.v[y * 3 + 1] * b.v[3 + x] + a.v[y * 3 + 2] * b.v[6 + x];
    return c;
}
static IpV ipxform(IpB b, IpV v) {
    return ipv(b.v[0] * v.x + b.v[1] * v.y + b.v[2] * v.z,
               b.v[3] * v.x + b.v[4] * v.y + b.v[5] * v.z,
               b.v[6] * v.x + b.v[7] * v.y + b.v[8] * v.z);
}
static IpB ipinv(IpB b) {
    float *a = b.v;
    IpB c = {{a[4] * a[8] - a[5] * a[7], a[2] * a[7] - a[1] * a[8], a[1] * a[5] - a[2] * a[4],
              a[5] * a[6] - a[3] * a[8], a[0] * a[8] - a[2] * a[6], a[2] * a[3] - a[0] * a[5],
              a[3] * a[7] - a[4] * a[6], a[1] * a[6] - a[0] * a[7], a[0] * a[4] - a[1] * a[3]}};
    float d = a[0] * c.v[0] + a[1] * c.v[3] + a[2] * c.v[6];
    for (int i = 0; i < 9; i++)
        c.v[i] *= 1.0f / d;
    return c;
}
static IpB iprx(double angle) {
    float c = cosf((float)angle), s = sinf((float)angle);
    return (IpB){{1, 0, 0, 0, c, -s, 0, s, c}};
}
static IpB iprz(double angle) {
    float c = cosf((float)angle), s = sinf((float)angle);
    return (IpB){{c, -s, 0, s, c, 0, 0, 0, 1}};
}
static IpB ipeuler(IpV e) {
    float c = cosf(e.y), s = sinf(e.y);
    IpB y = {{c, 0, s, 0, 1, 0, -s, 0, c}};
    return ipmul(ipmul(y, iprx(e.x)), iprz(e.z));
}
static IpB iparc(IpV a, IpV b) {
    float d = ipdot(a, b), x, y, z, w;
    if (d < -1.0f + 0.00001f) {
        x = 0;
        y = 1;
        z = 0;
        w = 0;
    } else {
        float s = sqrtf((1.0f + d) * 2.0f), r = 1.0f / s;
        x = (a.y * b.z - a.z * b.y) * r;
        y = (a.z * b.x - a.x * b.z) * r;
        z = (a.x * b.y - a.y * b.x) * r;
        w = s * 0.5f;
    }
    float s = 2.0f / (x * x + y * y + z * z + w * w);
    float xs = x * s, ys = y * s, zs = z * s;
    return (IpB){{1 - (y * ys + z * zs), x * ys - w * zs, x * zs + w * ys, x * ys + w * zs,
                  1 - (x * xs + z * zs), y * zs - w * xs, x * zs - w * ys, y * zs + w * xs,
                  1 - (x * xs + y * ys)}};
}
static int ipread(const void *object, int field, GDExtensionVariantType type, void *out) {
    Value value;
    GDExtensionBool valid = 0;
    get_named(object, &ip_fields[field], &value, &valid);
    int ok = valid && get_type(&value) == type;
    if (ok)
        to_type(type)(out, &value);
    variant_destroy(&value);
    return ok;
}
static void ipwrite(const void *object, int field, GDExtensionVariantType type, const void *data) {
    Value value;
    GDExtensionBool valid = 0;
    from_type(type)(&value, (void *)data);
    ip_set_named((void *)object, &ip_fields[field], &value, &valid);
    variant_destroy(&value);
}
static int ipnumber(const void *object, const Value *field, double *out) {
    Value value;
    GDExtensionBool valid = 0;
    get_named(object, field, &value, &valid);
    int ok = valid;
    if (valid && get_type(&value) == TYPE(BOOL)) {
        GDExtensionBool b;
        to_type(TYPE(BOOL))(&b, &value);
        *out = b;
    } else if (!valid || !index_number(&value, out))
        ok = 0;
    /* Only the intentional travel-idle sentinel may be infinite. */
    if (valid && get_type(&value) == TYPE(FLOAT)) {
        to_type(TYPE(FLOAT))(out, &value);
        ok = !isnan(*out);
    }
    variant_destroy(&value);
    return ok;
}
static int ipjobvalue(const void *job, int field, GDExtensionVariantType type, void *out) {
    Value value;
    GDExtensionBool valid = 0;
    get_named(job, &ip_job_fields[field], &value, &valid);
    int ok = valid && get_type(&value) == type;
    if (ok)
        to_type(type)(out, &value);
    variant_destroy(&value);
    return ok;
}
static int ipfeet(const void *object, int field, Value *array, IpV *out) {
    if (!ipread(object, field, TYPE(ARRAY), array))
        return 0;
    if (count_array(array) != 2) {
        get_dtor(TYPE(ARRAY))(array);
        return 0;
    }
    for (int i = 0; i < 2; i++) {
        void *value = array_index(array, i);
        if (get_type(value) != TYPE(VECTOR3)) {
            get_dtor(TYPE(ARRAY))(array);
            return 0;
        }
        to_type(TYPE(VECTOR3))(&out[i], value);
    }
    return 1;
}
static void ipstorefeet(void *array, IpV *feet) {
    for (int i = 0; i < 2; i++) {
        void *slot = array_write(array, i);
        variant_destroy(slot);
        from_type(TYPE(VECTOR3))(slot, &feet[i]);
    }
}
static void iparms(IpT *p, const double *config) {
    for (int i = 0; i < 2; i++) {
        int base = 5 + i * 4;
        IpV upper_rest = ipv(config[11 + i * 9], config[12 + i * 9], config[13 + i * 9]);
        IpV lower_rest = ipv(config[14 + i * 9], config[15 + i * 9], config[16 + i * 9]);
        IpV pole = ipv(config[17 + i * 9], config[18 + i * 9], config[19 + i * 9]);
        IpV target = ipa(ipxform(p[4].b, p[base + 3].p), p[4].p);
        IpV offset = ips(target, p[base].p), direction = ipnorm(offset);
        double upper = iplen(upper_rest), lower = iplen(lower_rest);
        double distance = ipclamp(iplen(offset), .02, upper + lower - .0001);
        double along = (distance * distance + upper * upper - lower * lower) / (2.0 * distance);
        IpV outward = ipnorm(ips(pole, ipm(direction, ipdot(pole, direction))));
        IpV elbow =
            ipa(ipm(direction, along), ipm(outward, sqrt(fmax(0, upper * upper - along * along))));
        p[base].b = iparc(ipnorm(upper_rest), ipnorm(elbow));
        IpV forearm = ips(ipm(direction, distance), elbow);
        p[base + 1].b = ipmul(ipinv(p[base].b), iparc(ipnorm(lower_rest), ipnorm(forearm)));
        p[base + 2].b = ipmul(ipinv(ipmul(p[base].b, p[base + 1].b)), p[4].b);
    }
}
static void ipleg(IpT *p, int base, IpV target, double pelvis_roll) {
    IpV offset = ips(target, p[base].p);
    double roll = atan2(offset.x, -offset.y),
           height = -sqrtf(offset.x * offset.x + offset.y * offset.y);
    double reach = fmin(sqrtf((float)height * (float)height + offset.z * offset.z), .5199);
    double bend = acos(ipclamp(reach / .52, 0, 1)), pitch = atan2(-offset.z, -height) + bend;
    p[base].b = ipmul(iprz(roll), iprx(pitch));
    p[base + 1].b = iprx(-2.0 * bend);
    p[base + 2].b = ipmul(iprx(2.0 * bend - pitch), iprz(-(roll + pelvis_roll)));
}
static int infantry_job(const void *job) {
    Value motion, parts, configuration;
    GDExtensionBool valid_motion = 0;
    get_named(job, &ip_job_fields[IP_MOTION], &motion, &valid_motion);
    if (!valid_motion || get_type(&motion) != TYPE(OBJECT) || !object_from_id(object_id(&motion))) {
        variant_destroy(&motion);
        return 0;
    }
    int have_parts = 0, have_config = 0, arrays = 0, ok = 0;
    Value feet_arrays[3];
    IpV feet[2], stance[2], start[2], settle_from, flinch;
    IpV *vectors[] = {feet, stance, start};
    double s[19], dt, distance, clock, gesture, recoil, aiming;
    float lean[2];
    IpT p[19];
    if (!ipjobvalue(job, IP_PARTS, TYPE(ARRAY), &parts))
        goto cleanup;
    have_parts = 1;
    if (count_array(&parts) != 19 ||
        !ipjobvalue(job, IP_CONFIG, TYPE(PACKED_FLOAT64_ARRAY), &configuration))
        goto cleanup;
    have_config = 1;
    int64_t config_count = 0;
    ip_doubles_size(&configuration, 0, &config_count, 0);
    if (config_count != 29)
        goto cleanup;
    const double *c = ip_doubles(&configuration, 0);
    if (!(c[0] > 0) || !isfinite(c[0]))
        goto cleanup;
    for (int i = 0; i < 29; i++)
        if (!isfinite(c[i]))
            goto cleanup;
    for (int i = 0; i < 19; i++) {
        void *part = array_index(&parts, i);
        if (get_type(part) != TYPE(OBJECT) || !object_from_id(object_id(part)) ||
            object_cast(object_from_id(object_id(part)), node_tag) ||
            !ipread(part, IP_TRANSFORM, TYPE(TRANSFORM3D), &p[i]))
            goto cleanup;
        const float *components = (const float *)&p[i];
        for (int j = 0; j < 12; j++)
            if (!isfinite(components[j]))
                goto cleanup;
    }
    for (int i = 0; i < 19; i++)
        if (!ipnumber(&motion, &ip_fields[i], &s[i]))
            goto cleanup;
    for (int i = 0; i < 19; i++)
        if (i != IP_IDLE && !isfinite(s[i]))
            goto cleanup;
    if (!(s[IP_STRIDE] > 0))
        goto cleanup;
    if (s[IP_SETTLE_FOOT] < -1 || s[IP_SETTLE_FOOT] > 1)
        goto cleanup;
    if (!ipread(&motion, IP_LEAN, TYPE(VECTOR2), lean) ||
        !ipread(&motion, IP_FLINCH, TYPE(VECTOR3), &flinch) ||
        !ipread(&motion, IP_SETTLE_FROM, TYPE(VECTOR3), &settle_from))
        goto cleanup;
    for (int i = 0; i < 3; i++) {
        if (!ipfeet(&motion, IP_FEET + i, &feet_arrays[i], vectors[i]))
            goto cleanup;
        arrays++;
    }
    double *inputs[] = {&dt, &distance, &clock, &gesture, &recoil, &aiming};
    for (int i = 0; i < 6; i++)
        if (!ipnumber(job, &ip_job_fields[IP_DT + i], inputs[i]) || !isfinite(*inputs[i]))
            goto cleanup;
    if (dt < 0 || distance < 0)
        goto cleanup;
    const double pi = 3.14159265358979323846, tau = 6.28318530717958647692;
    s[IP_SUPPRESS] = ipmove(s[IP_SUPPRESS], s[IP_SUPPRESS_TARGET], dt * 4);
    s[IP_PIN] = ipmove(s[IP_PIN], s[IP_PIN_TARGET], dt * 3);
    distance /= c[0];
    int traveling = distance > fmax(.0000001, dt * .02);
    s[IP_IDLE] = traveling ? 0 : s[IP_IDLE] + dt;
    int moving = traveling || (s[IP_MOVING] && s[IP_IDLE] < .06);
    if (dt > 0)
        s[IP_SPEED] = ipmix(s[IP_SPEED], distance / dt, 1 - exp(-dt * 10));
    if (!moving)
        s[IP_SPEED] = ipmove(s[IP_SPEED], 0, dt * 6);
    s[IP_BLEND] = ipmove(s[IP_BLEND], moving ? ipclamp(s[IP_SPEED] / 1.4, 0, 1) : 0, dt * 6);
    s[IP_AIM] = ipmove(s[IP_AIM], aiming, dt * (aiming > s[IP_AIM] ? 6 : 2.5));
    double stationary = moving ? 0 : aiming;
    s[IP_BRACE] = ipmove(s[IP_BRACE], stationary, dt * (stationary > s[IP_BRACE] ? 4 : 2));
    double kneeling = fmax(c[5] ? s[IP_BRACE] : 0, s[IP_SUPPRESS] * .75);
    s[IP_HEIGHT] = ipmix(ipmix(.55 - .02 * s[IP_BRACE], .37, kneeling), .19, s[IP_PIN]);
    if (moving) {
        if (!s[IP_MOVING]) {
            s[IP_MOVING] = 1;
            s[IP_SETTLE_FOOT] = -1;
            s[IP_PHASE] = tau * (s[IP_LEAD] == 0 ? .25 : .75);
            s[IP_MIX] = 0;
            memcpy(start, feet, sizeof(feet));
        }
        double stride = ipclamp(.5 + .13 * s[IP_SPEED], .55, 1) * s[IP_STRIDE];
        s[IP_PHASE] = ipmod(s[IP_PHASE] + distance * tau / stride, tau);
        s[IP_MIX] = fmin(1, s[IP_MIX] + dt / .14);
        for (int i = 0; i < 2; i++) {
            double reach = stride * .25, cycle = ipmod(s[IP_PHASE] / tau + i * .5, 1), z, lift = 0;
            if (cycle < .5)
                z = ipmix(-reach, reach, cycle * 2);
            else {
                double swing = (cycle - .5) * 2;
                z = ipmix(reach, -reach, ipsmooth(swing));
                lift = sin(swing * pi) * ipclamp(.05 + .018 * s[IP_SPEED], .05, .12);
            }
            feet[i] =
                iplerp(start[i], ipv((i == 0 ? -1 : 1) * .09, .045 + lift, z), ipsmooth(s[IP_MIX]));
        }
    } else {
        s[IP_MOVING] = 0;
        for (int i = 0; i < 2; i++) {
            double side = i == 0 ? -1 : 1;
            stance[i] = iplerp(iplerp(ipv(side * .1, .045, side * .04),
                                      ipv(side * .12, .045, side * .13), s[IP_BRACE]),
                               ipv(side * .1, .045, i == 0 ? -.2 : .31), kneeling);
        }
        int settle = (int)s[IP_SETTLE_FOOT];
        if (settle >= 0) {
            s[IP_SETTLE_TIME] += dt / .2;
            double progress = fmin(1, s[IP_SETTLE_TIME]);
            feet[settle] = iplerp(settle_from, stance[settle], ipsmooth(progress));
            feet[settle].y +=
                (float)(sin(progress * pi) *
                        fmin(.07, .02 + iplen(ips(settle_from, stance[settle])) * .3));
            if (progress >= 1)
                s[IP_SETTLE_FOOT] = -1;
        } else {
            int farthest = -1;
            double gap = .015;
            for (int i = 0; i < 2; i++) {
                double offset = iplen(ips(feet[i], stance[i]));
                if (offset > gap) {
                    gap = offset;
                    farthest = i;
                }
            }
            if (farthest >= 0) {
                s[IP_SETTLE_FOOT] = farthest;
                settle_from = feet[farthest];
                s[IP_SETTLE_TIME] = 0;
            } else
                memcpy(feet, stance, sizeof(feet));
        }
    }
    for (int i = 0; i < 2; i++)
        feet[i] = iplerp(
            feet[i],
            ipv((i == 0 ? -1 : 1) * .15, .045, .55 + sin(s[IP_PHASE] + i * pi) * s[IP_BLEND] * .12),
            s[IP_PIN]);
    double phase = s[IP_PHASE], blend = s[IP_BLEND], speed = s[IP_SPEED], aim = s[IP_AIM],
           brace = s[IP_BRACE], pin = s[IP_PIN];
    double breath = sin(clock * 2.2),
           dip = (.04 + .012 * cos(phase * 2)) * blend * ipclamp(speed / 2.5, .5, 1);
    double shift = -sin(phase) * .018 * blend;
    if (s[IP_FIDGET] == 1)
        shift += gesture * .03;
    IpT pelvis = {ipeuler(ipv(0, sin(phase) * .035 * blend, -shift * .5)),
                  ipv(shift, s[IP_HEIGHT] - dip, 0)};
    double upright = 1 - c[4] * .5, kick = recoil * c[2];
    IpV torso = ipv((-.035 - .03 * ipclamp(speed / 3.5, 0, 1)) * blend * upright - lean[0] -
                        kick * .035 - brace * .05 - kneeling * .06 + flinch.x +
                        (s[IP_FIDGET] == 3 ? gesture * .05 : 0) + breath * .006,
                    -sin(phase) * .025 * blend + brace * .1 +
                        (s[IP_FIDGET] == 0 ? gesture * .14 : 0) + flinch.y,
                    sin(phase) * .018 * blend + lean[1] + flinch.z +
                        (s[IP_FIDGET] != 0 ? gesture * .018 : 0));
    torso.x = (float)ipmix(torso.x, -1.25, pin);
    p[2].b = ipeuler(torso);
    p[2].p = ipa(
        ipa(ipv(0, .62, 0), ipv(shift * .6, s[IP_HEIGHT] - .55 - dip + breath * .003, kick * .014)),
        ipv(0, 0, flinch.x * .08 - pin * .18));
    p[3].p = ipa(ipv(c[8], c[9], c[10]), ipm(ipv(.025, -.022, -.018), aim));
    double look = gesture * (s[IP_FIDGET] == 0 ? .45 : .1) * (1 - aim);
    IpV head = ipv(.035 * blend - torso.x * .55 - aim * .12 -
                       (s[IP_FIDGET] == 2 ? fabs(gesture) * .35 : 0),
                   ipclamp(s[IP_TURN], -.6, .6) + look - brace * .08 + flinch.y * 1.5,
                   -torso.z * .6 + flinch.z * 1.4);
    /* Component rotation write preserves the authored head's scale. */
    float head_scale[3];
    const float *hb = p[3].b.v;
    float head_det = hb[0] * (hb[4] * hb[8] - hb[5] * hb[7]) -
                     hb[1] * (hb[3] * hb[8] - hb[5] * hb[6]) +
                     hb[2] * (hb[3] * hb[7] - hb[4] * hb[6]);
    for (int x = 0; x < 3; x++)
        head_scale[x] = (head_det < 0 ? -1 : 1) *
                        sqrtf(hb[x] * hb[x] + hb[3 + x] * hb[3 + x] + hb[6 + x] * hb[6 + x]);
    head.x += (float)(pin * .65);
    p[3].b = ipeuler(head);
    for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
            p[3].b.v[y * 3 + x] *= head_scale[x];
    IpV carry =
        ipv(c[1] * (moving ? 1 : .7) * (1 - aim) + sin(phase * 2 + .6) * .035 * blend * (1 - aim) +
                kick * .09 + (s[IP_FIDGET] == 2 ? fabs(gesture) * .25 : 0),
            c[6] * (1 - aim), c[7] * (1 - aim) + (s[IP_FIDGET] == 2 ? gesture * .45 : 0));
    carry.x += (float)(pin * 1.25);
    p[4].b = ipeuler(carry);
    p[4].p = ipa(ipv(0, .25, 0), ipv(0, aim * c[3], kick * .035));
    iparms(p, c);
    p[1] = pelvis;
    IpB to_pelvis = ipinv(pelvis.b);
    for (int i = 0; i < 2; i++)
        ipleg(p, 13 + i * 3, ipxform(to_pelvis, ips(feet[i], pelvis.p)), -shift * .5);
    /* Publish only after the entire input has been validated and solved. */
    for (int i = 0; i < 19; i++) {
        if (i == IP_LEAD || i == IP_FIDGET || i == IP_SETTLE_FOOT) {
            int64_t n = (int64_t)s[i];
            ipwrite(&motion, i, TYPE(INT), &n);
        } else if (i == IP_MOVING) {
            GDExtensionBool b = s[i] != 0;
            ipwrite(&motion, i, TYPE(BOOL), &b);
        } else
            ipwrite(&motion, i, TYPE(FLOAT), &s[i]);
    }
    ipwrite(&motion, IP_SETTLE_FROM, TYPE(VECTOR3), &settle_from);
    for (int i = 0; i < 3; i++)
        ipstorefeet(&feet_arrays[i], vectors[i]);
    ipwrite(&motion, IP_POSED_PELVIS, TYPE(TRANSFORM3D), &pelvis);
    ipwrite(&motion, IP_POSED_CARRY, TYPE(TRANSFORM3D), &p[4]);
    Value posed;
    if (ipread(&motion, IP_POSED_FEET, TYPE(ARRAY), &posed)) {
        while (count_array(&posed) < 2) {
            Value value;
            from_type(TYPE(VECTOR3))(&value, &feet[0]);
            const void *a[] = {&value};
            array_append(&posed, a, 0, 1);
            variant_destroy(&value);
        }
        ipstorefeet(&posed, feet);
        get_dtor(TYPE(ARRAY))(&posed);
    }
    for (int i = 1; i < 19; i++)
        ipwrite(array_index(&parts, i), IP_TRANSFORM, TYPE(TRANSFORM3D), &p[i]);
    Value solved;
    GDExtensionBool yes = 1, valid = 0;
    from_type(TYPE(BOOL))(&solved, &yes);
    ip_set_named((void *)job, &ip_job_fields[IP_SOLVED], &solved, &valid);
    variant_destroy(&solved);
    ok = 1;
cleanup:
    for (int i = 0; i < arrays; i++)
        get_dtor(TYPE(ARRAY))(&feet_arrays[i]);
    if (have_config)
        get_dtor(TYPE(PACKED_FLOAT64_ARRAY))(&configuration);
    if (have_parts)
        get_dtor(TYPE(ARRAY))(&parts);
    variant_destroy(&motion);
    return ok;
}
static int64_t infantry_core(const void *jobs) {
    int64_t solved = 0;
    for (int64_t i = 0; i < count_array((void *)jobs); i++)
        if (get_type(array_index(jobs, i)) == TYPE(OBJECT))
            solved += infantry_job(array_index(jobs, i));
    return solved;
}
static void infantry_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                          GDExtensionInt argc, GDExtensionVariantPtr ret,
                          GDExtensionCallError *error) {
    (void)userdata;
    (void)instance;
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (argc != 1 || get_type(args[0]) != TYPE(ARRAY)) {
        variant_nil(ret);
        return;
    }
    Value jobs;
    to_type(TYPE(ARRAY))(&jobs, (void *)args[0]);
    int64_t solved = infantry_core(&jobs);
    from_type(TYPE(INT))(ret, &solved);
    get_dtor(TYPE(ARRAY))(&jobs);
    error->error = GDEXTENSION_CALL_OK;
}
static void infantry_ptrcall(void *userdata, void *instance, const GDExtensionConstTypePtr *args,
                             void *ret) {
    (void)userdata;
    (void)instance;
    *(int64_t *)ret = infantry_core(args[0]);
}
static int infantry_load(GDExtensionInterfaceGetProcAddress proc) {
    ip_set_named = (GDExtensionInterfaceVariantSetNamed)proc("variant_set_named");
    ip_doubles = (GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst)proc(
        "packed_float64_array_operator_index_const");
    return ip_set_named && ip_doubles;
}
static void infantry_initialize(void) {
    name_new(&ip_method, "solve_infantry_batch");
    name_new(&ip_argument, "jobs");
    const char *fields[] = {"blend",          "phase",
                            "speed",          "aim",
                            "brace",          "stride_scale",
                            "lead_foot",      "_start_mix",
                            "_settle_foot",   "_settle_time",
                            "_hip_height",    "_moving",
                            "_travel_idle",   "_suppressed_target",
                            "_pinned_target", "_suppressed_pose",
                            "_pinned_pose",   "turn_lead",
                            "fidget",         "lean",
                            "flinch",         "_settle_from",
                            "_feet",          "_stance",
                            "_start_feet",    "_posed_pelvis",
                            "_posed_carry",   "_posed_feet",
                            "transform"};
    const char *job_fields[] = {"motion",   "native_parts", "native_config", "delta",
                                "distance", "clock",        "gesture",       "recoil",
                                "aiming",   "native_solved"};
    for (int i = 0; i < 29; i++)
        name_new(&ip_fields[i], fields[i]);
    for (int i = 0; i < 10; i++)
        name_new(&ip_job_fields[i], job_fields[i]);
    ip_initialized = 1;
    ip_doubles_size = get_builtin(TYPE(PACKED_FLOAT64_ARRAY), &size_name, 3173160232LL);
    if (!ip_doubles_size)
        return;
    GDExtensionPropertyInfo output = {TYPE(INT), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionPropertyInfo argument = {TYPE(ARRAY), &ip_argument,  &empty_name,
                                        0,           &empty_string, 6};
    GDExtensionClassMethodArgumentMetadata metadata = 0;
    GDExtensionClassMethodInfo method = {0};
    method.name = &ip_method;
    method.call_func = infantry_call;
    method.ptrcall_func = infantry_ptrcall;
    method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    method.has_return_value = 1;
    method.return_value_info = &output;
    method.argument_count = 1;
    method.arguments_info = &argument;
    method.arguments_metadata = &metadata;
    register_method(library, &class_name, &method);
}
static void infantry_deinitialize(void) {
    if (!ip_initialized)
        return;
    get_dtor(TYPE(STRING_NAME))(&ip_method);
    get_dtor(TYPE(STRING_NAME))(&ip_argument);
    for (int i = 0; i < 29; i++)
        get_dtor(TYPE(STRING_NAME))(&ip_fields[i]);
    for (int i = 0; i < 10; i++)
        get_dtor(TYPE(STRING_NAME))(&ip_job_fields[i]);
    ip_initialized = 0;
}
