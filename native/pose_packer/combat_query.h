/* Complete live firing query for resident unit pairs. The return value -1
 * retains the script path for objects outside the resident unit contract.
 * No query answers are cached; all range, ownership and visibility facts are
 * evaluated in order at the instant of the request. */
static Value cf_role, cf_faction, cf_robot, cf_rocket, cf_helix, cf_mines;

static int cf_string(void *object, const Value *field, const Value *expected) {
    Value owner, value;
    cr_variant(object, &owner);
    GDExtensionBool valid = 0, equal = 0;
    get_named(&owner, field, &value, &valid);
    if (valid && get_type(&value) == TYPE(STRING)) {
        Value text;
        to_type(TYPE(STRING))(&text, &value);
        us_string_equal(&text, expected, &equal);
        get_dtor(TYPE(STRING))(&text);
    }
    variant_destroy(&value);
    variant_destroy(&owner);
    return equal;
}

static int native_combat_fire(CvRuntime *r, void *source, void *target, const void *cells,
                              double maximum, double step) {
    UsView *view = us_for_unit(source), *target_view = us_for_unit(target);
    UsSlot *slot = us_slot(view);
    if (!slot || !us_slot(target_view) || view->store != target_view->store)
        return -1;
    GDExtensionBool mine = 0;
    const void *group[] = {&cf_mines};
    ptrcall(cv_bind[CV_GROUP], target, group, &mine);
    if (mine)
        return -1; /* Engineering retains its specialized mine observation. */
    Value target_value;
    cr_variant(target, &target_value);
    int eligible = us_target(view, &target_value, 0);
    variant_destroy(&target_value);
    if (eligible <= 0)
        return eligible;

    IpT a, b;
    ptrcall(global_transform, source, 0, &a);
    ptrcall(global_transform, target, 0, &b);
    double range = slot->scalar[US_RANGE] * (us_siege(slot, source) ? 1.35 : 1.0);
    double target_domain = cv_domain(target, 1);
    void *owner = us_parent(source);
    if (target_domain == 0 && cf_string(source, &cf_role, &cf_robot) &&
        !cf_string(owner, &cf_faction, &cf_helix))
        range = fmin(6.5, range);
    else if (target_domain == 0 && cf_string(source, &cf_role, &cf_rocket))
        range = fmin(9.0, range);
    else {
        double height = target_domain == 0 || cv_domain(source, 1) == 0 ? 0 : (double)a.p.y - b.p.y;
        range += height <= -1.5 ? -range * .2 : (height >= 1.5 ? range * .25 : 0);
        if (cv_group(target, 1))
            range += cv_radius(target);
        void *host = cv_meta_host(source);
        if (host)
            range += cv_radius(host) + 2;
    }
    int outlined = 0;
    IpV nearest = cv_footprint_point(target, a.p, &outlined);
    /* Match Vector2.distance_to's float arithmetic, including boundary cases. */
    float dx = a.p.x - nearest.x, dz = a.p.z - nearest.z;
    double distance = sqrtf(dx * dx + dz * dz);
    if (outlined)
        distance += cv_radius(target);
    if (distance > range)
        return 0;
    if (!us_allied(view->store, owner, us_parent(target)) &&
        !cv_observed(r, owner, target, cells, maximum, step))
        return 0;
    CvHeight heights = {0};
    IpV start = ipa(a.p, ipv(0, .8, 0)), end = ipa(b.p, ipv(0, .8, 0));
    int clear = cv_terrain(r, &heights, source, start, end, target, 1);
    cv_close_height(&heights);
    return clear && cv_line(r, start, end, source, target, 1);
}

static void native_combat_initialize(void) {
    name_new(&cf_role, "type");
    name_new(&cf_faction, "faction");
    name_new(&cf_mines, "field_mines");
    string_new(&cf_robot, "CombatRobot");
    string_new(&cf_rocket, "RocketInfantry");
    string_new(&cf_helix, "helix");
}
static void native_combat_deinitialize(void) {
    get_dtor(TYPE(STRING_NAME))(&cf_role);
    get_dtor(TYPE(STRING_NAME))(&cf_faction);
    get_dtor(TYPE(STRING_NAME))(&cf_mines);
    get_dtor(TYPE(STRING))(&cf_robot);
    get_dtor(TYPE(STRING))(&cf_rocket);
    get_dtor(TYPE(STRING))(&cf_helix);
}
