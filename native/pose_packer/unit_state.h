/* Resident unit facts, maintained at mutations rather than copied every tick.
 * Main thread only. Nodes retain orders/events/save identity. No private engine
 * layouts, cross-tick query-result caches, or strong references back to nodes. */
#define US_LIMIT 16384
#define US_PLAYERS 64
enum { US_STORE_KIND = 2001, US_VIEW_KIND = 2002, US_LINK_KIND = 2003 };
enum {
    US_STANDARD_DOMAIN = 1,
    US_STANDARD_CONSTRUCTION = 2,
    US_INFANTRY = 4,
    US_TURRET = 8,
    US_HAS_CONSTRUCTION = 16,
    US_ARMED = 32,
    US_INTERACTIVE = 64,
    US_INVULNERABLE = 128,
    US_DAMAGE_CHECK = 256,
    US_FORCE_ONLY = 512,
    US_AGENT = 1024,
    US_OBSTACLE = 2048,
    US_STANDARD_SIGHT = 4096
};
typedef struct {
    uint64_t unit, trait, view, abilities, signature, suppression;
    uint32_t generation, present, flags;
    int live;
    double scalar[US_SCALARS];
    Value domains;
} UsSlot;
typedef struct {
    uint64_t id;
    int64_t team;
    int standard;
} UsPlayer;
typedef struct {
    int kind;
    uint64_t owner, match, commander;
    UsSlot *slots;
    int high_water, live, player_count;
    UsPlayer players[US_PLAYERS];
    uint64_t statistics[9]; /* bound, bindings, writes, eligibility, speed, reads,
                              fallback, direct scalar/radius reads, direct speeds */
} UsStore;
typedef struct {
    int kind;
    UsStore *store;
    int index;
    uint32_t generation;
    uint64_t id;
    Value owner;
} UsView;
typedef struct {
    int kind;
    uint64_t view;
} UsLink;
static Value us_classes[2], us_properties[22], us_store_methods[4], us_view_methods[4];
static Value us_args[11], us_names[21], us_doctrine, us_maneuver, us_movement_factor;
static GDExtensionPtrOperatorEvaluator us_equal, us_string_equal;
static GDExtensionPtrBuiltInMethod us_array_has;
static GDExtensionMethodBindPtr us_obstacle_radius;
static void *us_obstacle_tag;
static int us_initialized, us_registered;
static int us_active_stores;
enum {
    US_KIND,
    US_WINDOW,
    US_TECHNOLOGY,
    US_COMPLETED,
    US_SIEGE,
    US_SPRINT,
    US_ACTIVE,
    US_BAND,
    US_EMP,
    US_FORCE,
    US_ACTION,
    US_TARGET,
    US_DOMAINS,
    US_OWNER,
    US_ARMED_METHOD,
    US_INTERACTIVE_FIELD,
    US_INVULNERABLE_FIELD,
    US_DAMAGE_METHOD,
    US_FORCE_METHOD,
    US_ABILITIES,
    US_SIGNATURE
};
static void *us_binding_create(void *token, void *owner) {
    (void)token;
    (void)owner;
    UsLink *link = calloc(1, sizeof(UsLink));
    if (link)
        link->kind = US_LINK_KIND;
    return link;
}
static void us_binding_free(void *token, void *owner, void *binding) {
    (void)token;
    (void)owner;
    free(binding);
}
static GDExtensionInstanceBindingCallbacks us_link_callbacks = {us_binding_create, us_binding_free,
                                                                rp_binding_reference};

static UsSlot *us_slot(UsView *view) {
    if (!view || view->kind != US_VIEW_KIND || !view->store || view->index < 0 ||
        view->index >= view->store->high_water)
        return 0;
    UsSlot *slot = &view->store->slots[view->index];
    return slot->live && slot->generation == view->generation ? slot : 0;
}
static UsView *us_for_unit(void *unit) {
    if (!us_registered || !us_active_stores || !unit)
        return 0;
    /* Probe only. Passing callbacks here creates an engine binding even when
     * the object is a projectile/generic observer with no resident unit state. */
    UsLink *link = rp_get_binding(unit, library, 0);
    if (!link || link->kind != US_LINK_KIND)
        return 0;
    void *object = object_from_id(link->view);
    if (!object)
        return 0;
    UsView *view = rp_get_binding(object, library, 0);
    UsSlot *slot = us_slot(view);
    return slot && object_from_id(slot->unit) == unit ? view : 0;
}
static int us_read(void *object, int field, Value *value) {
    if (!object) {
        variant_nil(value);
        return 0;
    }
    Value instance;
    cr_variant(object, &instance);
    GDExtensionBool valid = 0;
    get_named(&instance, &us_names[field], value, &valid);
    variant_destroy(&instance);
    return valid;
}
static void *us_object(void *object, int field) {
    Value value;
    int valid = us_read(object, field, &value);
    void *result =
        valid && get_type(&value) == TYPE(OBJECT) ? object_from_id(object_id(&value)) : 0;
    variant_destroy(&value);
    return result;
}
static int us_bool(void *object, int field) {
    Value value;
    int valid = us_read(object, field, &value);
    GDExtensionBool result = 0;
    if (valid && get_type(&value) == TYPE(BOOL))
        to_type(TYPE(BOOL))(&result, &value);
    variant_destroy(&value);
    return result;
}
static double us_number(void *object, int field) {
    Value value;
    int valid = us_read(object, field, &value);
    double result = 0;
    if (valid)
        index_number(&value, &result);
    variant_destroy(&value);
    return result;
}
static int us_has_method(void *object, const Value *name) {
    GDExtensionBool result = 0;
    const void *args[] = {name};
    ptrcall(cv_bind[CV_HAS_METHOD], object, args, &result);
    return result;
}
static int us_call_bool(void *object, const Value *method) {
    Value instance, result;
    cr_variant(object, &instance);
    GDExtensionCallError error = {0};
    variant_call(&instance, method, 0, 0, &result, &error);
    GDExtensionBool yes = 0;
    if (error.error == GDEXTENSION_CALL_OK && get_type(&result) == TYPE(BOOL))
        to_type(TYPE(BOOL))(&yes, &result);
    variant_destroy(&result);
    variant_destroy(&instance);
    return yes;
}
static void *us_parent(void *node) {
    void *parent = 0;
    if (node)
        ptrcall(cr_bind[CR_GET_PARENT], node, 0, &parent);
    return parent;
}
static int us_constructed(UsSlot *slot, void *unit) {
    if (!(slot->flags & US_HAS_CONSTRUCTION))
        return 1;
    return slot->flags & US_STANDARD_CONSTRUCTION ? slot->scalar[US_CONSTRUCTION] >= 1
                                                  : us_call_bool(unit, &cv_helpers[CV_CONSTRUCTED]);
}
static int us_available(UsSlot *slot, void *unit) {
    return cv_live(unit, 1) && (slot->present & (1u << US_HP)) && slot->scalar[US_HP] > 0 &&
           us_constructed(slot, unit) && !cr_meta(unit, &cr_garrison);
}
static int us_siege(UsSlot *slot, void *unit) {
    void *manager = object_from_id(slot->abilities);
    return manager && us_bool(us_object(manager, US_SIEGE), US_ACTIVE) && us_available(slot, unit);
}
static int us_suppression(UsSlot *slot) {
    return (int)us_number(object_from_id(slot->suppression), US_BAND);
}
static int us_emp(UsStore *store, void *unit) {
    Value effects;
    int valid = us_read(object_from_id(store->commander), US_EMP, &effects);
    double left = 0;
    if (valid && get_type(&effects) == TYPE(DICTIONARY)) {
        Value dictionary, key;
        to_type(TYPE(DICTIONARY))(&dictionary, &effects);
        cr_variant(unit, &key);
        void *value = dictionary_lookup(&dictionary, &key);
        if (value)
            index_number(value, &left);
        variant_destroy(&key);
        get_dtor(TYPE(DICTIONARY))(&dictionary);
    }
    variant_destroy(&effects);
    return left > 0;
}
static int us_upgraded(void *unit) {
    void *technology = us_object(us_parent(unit), US_TECHNOLOGY);
    Value completed;
    int valid = us_read(technology, US_COMPLETED, &completed);
    GDExtensionBool yes = 0;
    if (valid && get_type(&completed) == TYPE(ARRAY)) {
        Value array;
        to_type(TYPE(ARRAY))(&array, &completed);
        const void *args[] = {&us_doctrine};
        us_array_has(&array, args, &yes, 1);
        get_dtor(TYPE(ARRAY))(&array);
    }
    variant_destroy(&completed);
    return yes;
}
static double us_speed(UsView *view, UsSlot *slot) {
    view->store->statistics[4]++;
    if (!(slot->flags & US_AGENT))
        return 0;
    void *unit = object_from_id(slot->unit);
    if (!unit)
        return slot->scalar[US_BASE_SPEED];
    double factor = 1;
    void *signature = object_from_id(slot->signature);
    if (signature && us_number(signature, US_WINDOW) > 0) {
        Value kind;
        int valid = us_read(signature, US_KIND, &kind);
        GDExtensionBool maneuver = 0;
        if (valid && get_type(&kind) == TYPE(STRING)) {
            Value left;
            to_type(TYPE(STRING))(&left, &kind);
            us_string_equal(&left, &us_maneuver, &maneuver);
            get_dtor(TYPE(STRING))(&left);
        }
        variant_destroy(&kind);
        if (maneuver)
            factor = us_upgraded(unit) ? 1.5 : 1.35;
    }
    void *manager = object_from_id(slot->abilities);
    if (manager) {
        if (us_bool(us_object(manager, US_SIEGE), US_ACTIVE) && us_available(slot, unit))
            factor *= 0;
        else if (us_bool(us_object(manager, US_SPRINT), US_ACTIVE) && us_available(slot, unit))
            factor *= 1.5;
    }
    int band = us_suppression(slot);
    factor *= band == 2 ? .4 : (band == 1 ? .7 : 1);
    if (!(slot->flags & US_INFANTRY) && us_emp(view->store, unit))
        factor *= .6;
    Value owner, multiplier;
    cr_variant(unit, &owner);
    GDExtensionCallError factor_error = {0};
    variant_call(&owner, &us_movement_factor, 0, 0, &multiplier, &factor_error);
    double technology_factor = 1;
    if (factor_error.error == GDEXTENSION_CALL_OK)
        index_number(&multiplier, &technology_factor);
    variant_destroy(&multiplier);
    variant_destroy(&owner);
    factor *= technology_factor;
    return slot->scalar[US_BASE_SPEED] * factor * slot->scalar[US_VETERAN_SPEED] *
           (1 + .1 * slot->scalar[US_SCRAP]);
}
static int native_unit_scalar(void *unit, int field, double *value, int *present) {
    UsView *view = us_for_unit(unit);
    UsSlot *slot = us_slot(view);
    if (!slot || field < 0 || field >= US_SCALARS)
        return 0;
    view->store->statistics[5]++;
    view->store->statistics[7]++;
    *value = slot->scalar[field];
    *present = (slot->present & (1u << field)) != 0;
    return 1;
}
static int native_unit_speed(void *unit, double *speed) {
    UsView *view = us_for_unit(unit);
    UsSlot *slot = us_slot(view);
    if (!slot)
        return 0;
    *speed = us_speed(view, slot);
    view->store->statistics[8]++;
    return 1;
}
static int native_agent_speed(void *agent, double *speed) {
    if (!us_active_stores)
        return 0;
    return native_unit_speed(us_parent(agent), speed);
}
static int native_unit_radius(void *unit, double *radius) {
    UsView *view = us_for_unit(unit);
    UsSlot *slot = us_slot(view);
    void *trait = slot ? object_from_id(slot->trait) : 0;
    if (!trait || !(slot->flags & (US_AGENT | US_OBSTACLE)))
        return 0;
    ptrcall(slot->flags & US_AGENT ? cr_bind[CR_GET_RADIUS] : us_obstacle_radius, trait, 0, radius);
    view->store->statistics[5]++;
    view->store->statistics[7]++;
    return 1;
}
static int native_unit_domain(void *unit, double *domain, int *present) {
    UsView *view = us_for_unit(unit);
    UsSlot *slot = us_slot(view);
    if (!slot)
        return 0;
    if (slot->flags & US_STANDARD_DOMAIN)
        return native_unit_scalar(unit, US_DOMAIN, domain, present);
    Value value = cv_call(unit, CV_COMBAT_DOMAIN, 0, 0);
    *domain = -1;
    *present = index_number(&value, domain);
    variant_destroy(&value);
    return 1;
}
static UsPlayer *us_player(UsStore *store, void *owner) {
    uint64_t id = owner ? rp_object_id(owner) : 0;
    for (int i = 0; i < store->player_count; i++)
        if (store->players[i].id == id)
            return &store->players[i];
    return 0;
}
static int us_allied(UsStore *store, void *first, void *second) {
    if (first == second)
        return 1;
    if (!first)
        return 0;
    UsPlayer *a = us_player(store, first), *b = us_player(store, second);
    if (a && a->standard && b)
        return a->team >= 0 && a->team == b->team;
    if (!us_has_method(first, &cv_helpers[CV_ALLIED]))
        return 0;
    Value target, owner, result;
    cr_variant(second, &target);
    cr_variant(first, &owner);
    const void *args[] = {&target};
    GDExtensionCallError error = {0};
    variant_call(&owner, &cv_helpers[CV_ALLIED], args, 1, &result, &error);
    GDExtensionBool yes = 0;
    if (error.error == GDEXTENSION_CALL_OK && get_type(&result) == TYPE(BOOL))
        to_type(TYPE(BOOL))(&yes, &result);
    variant_destroy(&result);
    variant_destroy(&owner);
    variant_destroy(&target);
    return yes;
}
static int us_explicit(const void *source, uint64_t target) {
    Value value;
    GDExtensionBool valid = 0;
    get_named(source, &us_names[US_FORCE], &value, &valid);
    if (valid) {
        GDExtensionBool yes = 0;
        if (get_type(&value) == TYPE(BOOL))
            to_type(TYPE(BOOL))(&yes, &value);
        variant_destroy(&value);
        return yes;
    }
    variant_destroy(&value);
    get_named(source, &us_names[US_ACTION], &value, &valid);
    void *action =
        valid && get_type(&value) == TYPE(OBJECT) ? object_from_id(object_id(&value)) : 0;
    int forced = us_bool(action, US_FORCE);
    void *aim = forced ? us_object(action, US_TARGET) : 0;
    variant_destroy(&value);
    return aim && rp_object_id(aim) == target;
}
static int us_receive(UsView *target_view, const void *source, int forced) {
    UsSlot *target = us_slot(target_view);
    void *node = target ? object_from_id(target->unit) : 0;
    if (!node || get_type(source) != TYPE(OBJECT))
        return -1;
    void *shooter = object_from_id(object_id(source));
    if (!shooter)
        return -1;
    UsView *source_view = us_for_unit(shooter);
    UsSlot *source_slot = us_slot(source_view);
    if (source_view && source_view->store != target_view->store)
        return -1;
    if (!cv_live(node, 0) || cr_meta(node, &cr_garrison) ||
        ((target->flags & US_INTERACTIVE) && !us_bool(node, US_INTERACTIVE_FIELD)) ||
        !(target->present & (1u << US_HP)) || !(target->scalar[US_HP] > 0) ||
        ((target->flags & US_INVULNERABLE) && us_bool(node, US_INVULNERABLE_FIELD)) ||
        ((target->flags & US_DAMAGE_CHECK) && !us_call_bool(node, &us_names[US_DAMAGE_METHOD])))
        return 0;
    void *owner = 0;
    Value domains;
    if (source_slot) {
        owner = us_parent(shooter);
        get_ctor(TYPE(ARRAY), 1)(&domains, (const void *[]){&source_slot->domains});
    } else {
        Value value;
        GDExtensionBool valid = 0;
        get_named(source, &us_names[US_OWNER], &value, &valid);
        if (valid && get_type(&value) == TYPE(OBJECT))
            owner = object_from_id(object_id(&value));
        variant_destroy(&value);
        if (!valid)
            return -1;
        get_named(source, &us_names[US_DOMAINS], &value, &valid);
        if (!valid || get_type(&value) != TYPE(ARRAY)) {
            variant_destroy(&value);
            return -1;
        }
        to_type(TYPE(ARRAY))(&domains, &value);
        variant_destroy(&value);
    }
    int eligible = forced || us_explicit(source, target->unit);
    if (!eligible)
        eligible =
            !us_allied(target_view->store, owner, us_parent(node)) &&
            (!(target->flags & US_FORCE_ONLY) || !us_call_bool(node, &us_names[US_FORCE_METHOD]));
    GDExtensionBool yes = 0;
    if (eligible) {
        Value domain;
        if (target->flags & US_STANDARD_DOMAIN) {
            if (target->present & (1u << US_DOMAIN)) {
                int64_t n = (int64_t)target->scalar[US_DOMAIN];
                from_type(TYPE(INT))(&domain, &n);
            } else
                variant_nil(&domain);
        } else
            domain = cv_call(node, CV_COMBAT_DOMAIN, 0, 0);
        const void *args[] = {&domain};
        us_array_has(&domains, args, &yes, 1);
        variant_destroy(&domain);
    }
    get_dtor(TYPE(ARRAY))(&domains);
    return yes;
}
static int us_target(UsView *source_view, const void *target, int forced) {
    UsSlot *source = us_slot(source_view);
    void *unit = source ? object_from_id(source->unit) : 0;
    if (!unit || get_type(target) != TYPE(OBJECT))
        return -1;
    UsView *target_view = us_for_unit(object_from_id(object_id(target)));
    if (!target_view || source_view->store != target_view->store)
        return -1;
    if (!cv_live(unit, 0) || !(source->present & (1u << US_HP)) || !(source->scalar[US_HP] > 0) ||
        !(source->present & (1u << US_RANGE)) || cr_meta(unit, &cr_breach) ||
        ((source->flags & US_TURRET) && us_emp(source_view->store, unit)) ||
        !us_constructed(source, unit) ||
        ((source->flags & US_ARMED) && !us_call_bool(unit, &us_names[US_ARMED_METHOD])))
        return 0;
    Value shooter;
    cr_variant(unit, &shooter);
    int result = us_receive(target_view, &shooter, forced);
    variant_destroy(&shooter);
    return result;
}
static int us_property(const void *name) {
    for (int i = 0; i < 22; i++) {
        GDExtensionBool same = 0;
        us_equal(name, &us_properties[i], &same);
        if (same)
            return i;
    }
    return -1;
}
static GDExtensionBool us_get(void *instance, const void *name, void *ret) {
    UsView *view = instance;
    UsSlot *slot = us_slot(view);
    int field = us_property(name);
    if (!slot || field < 0)
        return 0;
    variant_destroy(ret);
    if (field < US_SCALARS) {
        if (slot->present & (1u << field))
            from_type(TYPE(FLOAT))(ret, &slot->scalar[field]);
        else
            variant_nil(ret);
    } else if (field < 16) {
        uint64_t ids[] = {slot->abilities, slot->signature, slot->suppression, slot->trait};
        void *object = object_from_id(ids[field - US_SCALARS]);
        from_type(TYPE(OBJECT))(ret, &object);
    } else if (field == 16) {
        int64_t handle = ((int64_t)view->generation << 14) | view->index;
        from_type(TYPE(INT))(ret, &handle);
    } else if (field == 17) {
        double speed = us_speed(view, slot);
        from_type(TYPE(FLOAT))(ret, &speed);
    } else if (field < 21) {
        int scalar = field == 18 ? US_DAMAGE : (field == 19 ? US_INTERVAL : US_RANGE);
        if (!(slot->present & (1u << scalar)))
            variant_nil(ret);
        else {
            void *unit = object_from_id(slot->unit);
            double value = slot->scalar[scalar];
            if (scalar == US_DAMAGE) {
                value *= us_siege(slot, unit) ? 1.3 : 1;
                value *= 1 + .15 * slot->scalar[US_SCRAP];
            } else if (scalar == US_INTERVAL) {
                value *= slot->scalar[US_VETERAN_RELOAD];
                value *= us_suppression(slot) != 0 ? 1.2 : 1;
            } else
                value *= us_siege(slot, unit) ? 1.35 : 1;
            from_type(TYPE(FLOAT))(ret, &value);
        }
    } else
        from_type(TYPE(ARRAY))(ret, &slot->domains);
    view->store->statistics[5]++;
    return 1;
}
static GDExtensionBool us_set(void *instance, const void *name, const void *value) {
    UsView *view = instance;
    UsSlot *slot = us_slot(view);
    int field = us_property(name);
    if (!slot || field < 0)
        return 0;
    if (field < US_SCALARS) {
        double number = 0;
        if (get_type(value) == TYPE(NIL))
            slot->present &= ~(1u << field);
        else {
            if (get_type(value) == TYPE(FLOAT))
                to_type(TYPE(FLOAT))(&number, (void *)value);
            else if (get_type(value) == TYPE(INT)) {
                int64_t integer;
                to_type(TYPE(INT))(&integer, (void *)value);
                number = (double)integer;
            } else
                return 0;
            slot->present |= 1u << field;
        }
        slot->scalar[field] = number;
    } else if (field < 16) {
        uint64_t id = get_type(value) == TYPE(OBJECT) ? object_id(value) : 0;
        uint64_t *ids[] = {&slot->abilities, &slot->signature, &slot->suppression, &slot->trait};
        *ids[field - US_SCALARS] = id;
        if (field == 15) {
            void *trait = object_from_id(id);
            slot->flags &= ~(US_AGENT | US_OBSTACLE);
            if (trait && object_cast(trait, agent_tag))
                slot->flags |= US_AGENT;
            else if (trait && object_cast(trait, us_obstacle_tag))
                slot->flags |= US_OBSTACLE;
        }
    } else if (field == 21 && get_type(value) == TYPE(ARRAY)) {
        get_dtor(TYPE(ARRAY))(&slot->domains);
        to_type(TYPE(ARRAY))(&slot->domains, (void *)value);
    } else
        return 0;
    view->store->statistics[2]++;
    return 1;
}
static GDExtensionObjectPtr us_create(void *userdata, GDExtensionBool notify) {
    (void)notify;
    int is_view = (int)(intptr_t)userdata;
    void *state;
    if (is_view) {
        UsView *view = calloc(1, sizeof(UsView));
        if (!view)
            return 0;
        view->kind = US_VIEW_KIND;
        view->index = -1;
        variant_nil(&view->owner);
        state = view;
    } else {
        UsStore *store = calloc(1, sizeof(UsStore));
        if (!store)
            return 0;
        store->kind = US_STORE_KIND;
        store->slots = calloc(US_LIMIT, sizeof(UsSlot));
        if (!store->slots) {
            free(store);
            return 0;
        }
        state = store;
    }
    void *owner = construct(&parent_name);
    if (!owner) {
        if (!is_view)
            free(((UsStore *)state)->slots);
        free(state);
        return 0;
    }
    set_instance(owner, &us_classes[is_view], state);
    rp_set_binding(owner, library, state, &rp_callbacks);
    if (is_view)
        ((UsView *)state)->id = rp_object_id(owner);
    else
        ((UsStore *)state)->owner = rp_object_id(owner);
    if (!is_view)
        us_active_stores++;
    return owner;
}
static void us_free(void *userdata, void *instance) {
    if ((int)(intptr_t)userdata) {
        UsView *view = instance;
        UsSlot *slot = us_slot(view);
        if (slot) {
            /* The node link holds a weak view ID. Do not call back into a node
             * while its script members may already be in destruction. */
            get_dtor(TYPE(ARRAY))(&slot->domains);
            slot->live = 0;
            view->store->live--;
            view->store->statistics[0] = (uint64_t)view->store->live;
        }
        variant_destroy(&view->owner);
        free(view);
    } else {
        UsStore *store = instance;
        free(store->slots);
        free(store);
        us_active_stores--;
    }
}
static void *us_bind(UsStore *store, void *unit, void *trait, const void *scalars,
                     const void *domains, int flags) {
    UsView *existing = us_for_unit(unit);
    if (existing)
        return existing->store == store ? object_from_id(existing->id) : 0;
    if (!object_cast(unit, node_tag) || count_array((void *)scalars) != US_SCALARS)
        return 0;
    for (int i = 0; i < US_SCALARS; i++) {
        GDExtensionVariantType type = get_type(array_index(scalars, i));
        if (type != TYPE(NIL) && type != TYPE(FLOAT) && type != TYPE(INT))
            return 0;
    }
    int index = 0;
    while (index < store->high_water && store->slots[index].live)
        index++;
    if (index == US_LIMIT)
        return 0;
    UsLink *link = rp_get_binding(unit, library, &us_link_callbacks);
    if (!link || link->kind != US_LINK_KIND)
        return 0;
    if (index == store->high_water)
        store->high_water++;
    void *owner = construct(&us_classes[1]);
    if (!owner)
        return 0;
    UsView *view = rp_get_binding(owner, library, 0);
    UsSlot *slot = &store->slots[index];
    uint32_t generation = slot->generation + 1;
    if (!generation)
        generation = 1;
    memset(slot, 0, sizeof(*slot));
    slot->generation = generation;
    slot->live = 1;
    slot->unit = rp_object_id(unit);
    slot->trait = trait ? rp_object_id(trait) : 0;
    slot->flags = (uint32_t)flags & (15 | US_STANDARD_SIGHT);
    if (trait && object_cast(trait, agent_tag))
        slot->flags |= US_AGENT;
    else if (trait && object_cast(trait, us_obstacle_tag))
        slot->flags |= US_OBSTACLE;
    if (us_has_method(unit, &cv_helpers[CV_CONSTRUCTED]))
        slot->flags |= US_HAS_CONSTRUCTION;
    const int methods[] = {US_ARMED_METHOD, US_DAMAGE_METHOD, US_FORCE_METHOD};
    const int bits[] = {US_ARMED, US_DAMAGE_CHECK, US_FORCE_ONLY};
    for (int i = 0; i < 3; i++)
        if (us_has_method(unit, &us_names[methods[i]]))
            slot->flags |= bits[i];
    for (int i = 0; i < 2; i++) {
        Value value;
        int valid = us_read(unit, i ? US_INVULNERABLE_FIELD : US_INTERACTIVE_FIELD, &value);
        if (valid)
            slot->flags |= i ? US_INVULNERABLE : US_INTERACTIVE;
        variant_destroy(&value);
    }
    slot->abilities = 0;
    void *object = us_object(unit, US_ABILITIES);
    if (object)
        slot->abilities = rp_object_id(object);
    object = us_object(unit, US_SIGNATURE);
    if (object)
        slot->signature = rp_object_id(object);
    /* Suppression is the third object link, read by its property name. */
    Value unit_value, suppression;
    cr_variant(unit, &unit_value);
    GDExtensionBool valid = 0;
    get_named(&unit_value, &us_properties[14], &suppression, &valid);
    if (valid && get_type(&suppression) == TYPE(OBJECT))
        slot->suppression = object_id(&suppression);
    variant_destroy(&suppression);
    variant_destroy(&unit_value);
    to_type(TYPE(ARRAY))(&slot->domains, (void *)domains);
    view->store = store;
    view->index = index;
    view->generation = generation;
    void *store_owner = object_from_id(store->owner);
    variant_destroy(&view->owner);
    cr_variant(store_owner, &view->owner);
    slot->view = view->id;
    for (int i = 0; i < US_SCALARS; i++)
        us_set(view, &us_properties[i], array_index(scalars, i));
    link->view = view->id;
    store->statistics[1]++;
    store->statistics[0] = (uint64_t)++store->live;
    return owner;
}
static void us_store_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                          GDExtensionInt count, void *ret, GDExtensionCallError *error) {
    UsStore *store = instance;
    int method = (int)(intptr_t)userdata;
    variant_nil(ret);
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (method == 0 && count == 2) {
        store->match = get_type(args[0]) == TYPE(OBJECT) ? object_id(args[0]) : 0;
        store->commander = get_type(args[1]) == TYPE(OBJECT) ? object_id(args[1]) : 0;
    } else if (method == 1 && count == 5 && get_type(args[0]) == TYPE(OBJECT) &&
               get_type(args[2]) == TYPE(ARRAY) && get_type(args[3]) == TYPE(ARRAY) &&
               get_type(args[4]) == TYPE(INT)) {
        void *unit = object_from_id(object_id(args[0]));
        void *trait = get_type(args[1]) == TYPE(OBJECT) ? object_from_id(object_id(args[1])) : 0;
        Value scalars;
        to_type(TYPE(ARRAY))(&scalars, (void *)args[2]);
        int64_t flags;
        to_type(TYPE(INT))(&flags, (void *)args[4]);
        void *view = unit ? us_bind(store, unit, trait, &scalars, args[3], (int)flags) : 0;
        get_dtor(TYPE(ARRAY))(&scalars);
        variant_destroy(ret);
        cr_variant(view, ret);
    } else if (method == 2 && count == 3 && get_type(args[0]) == TYPE(OBJECT) &&
               get_type(args[1]) == TYPE(INT) && get_type(args[2]) == TYPE(BOOL)) {
        uint64_t id = object_id(args[0]);
        int index = 0;
        while (index < store->player_count && store->players[index].id != id)
            index++;
        if (index >= US_PLAYERS)
            return;
        if (index == store->player_count)
            store->player_count++;
        int64_t team;
        GDExtensionBool standard;
        to_type(TYPE(INT))(&team, (void *)args[1]);
        to_type(TYPE(BOOL))(&standard, (void *)args[2]);
        store->players[index] = (UsPlayer){id, team, standard};
    } else if (method == 3 && count == 0) {
        variant_destroy(ret);
        profile_array(store->statistics, 9, ret);
    } else
        return;
    error->error = GDEXTENSION_CALL_OK;
}
static void us_view_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                         GDExtensionInt count, void *ret, GDExtensionCallError *error) {
    UsView *view = instance;
    UsSlot *slot = us_slot(view);
    int method = (int)(intptr_t)userdata;
    variant_nil(ret);
    error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    if (!slot)
        return;
    if (method < 2 && count == 2 && get_type(args[1]) == TYPE(BOOL)) {
        GDExtensionBool forced;
        to_type(TYPE(BOOL))(&forced, (void *)args[1]);
        int64_t result =
            method == 0 ? us_target(view, args[0], forced) : us_receive(view, args[0], forced);
        view->store->statistics[3]++;
        view->store->statistics[6] += result < 0;
        variant_destroy(ret);
        from_type(TYPE(INT))(ret, &result);
    } else if (method == 2 && count == 0) {
        uint64_t values[] = {slot->flags, slot->present, (uint64_t)view->index, view->generation};
        variant_destroy(ret);
        profile_array(values, 4, ret);
    } else if (method == 3 && count == 0) {
        double result = us_speed(view, slot);
        variant_destroy(ret);
        from_type(TYPE(FLOAT))(ret, &result);
    } else
        return;
    error->error = GDEXTENSION_CALL_OK;
}
static void unit_state_initialize(void) {
    const char *classes[] = {"CopperfinUnitStore", "CopperfinUnitState"};
    const char *properties[] = {
        "hp",           "hp_max",          "base_damage",      "base_interval",
        "base_range",   "sight_range",     "construction",     "domain",
        "base_speed",   "veterancy_speed", "veterancy_reload", "scrap_tiers",
        "abilities",    "signature",       "suppression",      "trait",
        "handle",       "movement_speed",  "attack_damage",    "attack_interval",
        "attack_range", "domains"};
    const char *store_methods[] = {"configure", "bind_unit", "set_team", "statistics"};
    const char *view_methods[] = {"can_target", "can_receive", "metadata", "speed"};
    const char *names[] = {"kind",
                           "window_left",
                           "technology",
                           "completed",
                           "_siege_anchor",
                           "_combat_sprint",
                           "is_active",
                           "band",
                           "emp",
                           "force_attack",
                           "action",
                           "_target_unit",
                           "attack_domains",
                           "player",
                           "armed",
                           "interactive",
                           "invulnerable",
                           "can_take_damage",
                           "force_attack_only",
                           "abilities",
                           "signature"};
    const char *arguments[] = {"unit",  "trait",     "scalars", "domains", "flags",   "forced",
                               "match", "commander", "player",  "team",    "standard"};
    for (int i = 0; i < 2; i++)
        name_new(&us_classes[i], classes[i]);
    for (int i = 0; i < 22; i++)
        name_new(&us_properties[i], properties[i]);
    for (int i = 0; i < 21; i++)
        name_new(&us_names[i], names[i]);
    for (int i = 0; i < 11; i++)
        name_new(&us_args[i], arguments[i]);
    for (int i = 0; i < 4; i++) {
        name_new(&us_store_methods[i], store_methods[i]);
        name_new(&us_view_methods[i], view_methods[i]);
    }
    Value text, has;
    string_new(&text, "doctrine");
    from_type(TYPE(STRING))(&us_doctrine, &text);
    get_dtor(TYPE(STRING))(&text);
    string_new(&us_maneuver, "maneuver");
    name_new(&has, "has");
    us_array_has = get_builtin(TYPE(ARRAY), &has, 3680194679);
    get_dtor(TYPE(STRING_NAME))(&has);
    Value obstacle, radius;
    name_new(&obstacle, "NavigationObstacle3D");
    name_new(&radius, "get_radius");
    us_obstacle_radius = method_bind(&obstacle, &radius, 1740695150);
    us_obstacle_tag = class_tag(&obstacle);
    get_dtor(TYPE(STRING_NAME))(&obstacle);
    get_dtor(TYPE(STRING_NAME))(&radius);
    us_equal = rp_evaluator(GDEXTENSION_VARIANT_OP_EQUAL, TYPE(STRING_NAME), TYPE(STRING_NAME));
    us_string_equal = rp_evaluator(GDEXTENSION_VARIANT_OP_EQUAL, TYPE(STRING), TYPE(STRING));
    name_new(&us_movement_factor, "movement_technology_factor");
    us_initialized = 1;
    if (!us_equal || !us_string_equal || !us_array_has || !us_obstacle_radius || !us_obstacle_tag)
        return;
    for (int view = 0; view < 2; view++) {
        GDExtensionClassCreationInfo4 info = {0};
        info.is_exposed = 1;
        info.class_userdata = (void *)(intptr_t)view;
        info.create_instance_func = us_create;
        info.free_instance_func = us_free;
        if (view) {
            info.get_func = us_get;
            info.set_func = us_set;
        }
        register_class(library, &us_classes[view], &parent_name, &info);
        const int counts[2][4] = {{2, 5, 3, 0}, {2, 2, 0, 0}};
        const GDExtensionVariantType parameters[2][4][5] = {
            {{TYPE(OBJECT), TYPE(OBJECT)},
             {TYPE(OBJECT), TYPE(OBJECT), TYPE(ARRAY), TYPE(ARRAY), TYPE(INT)},
             {TYPE(OBJECT), TYPE(INT), TYPE(BOOL)},
             {}},
            {{TYPE(OBJECT), TYPE(BOOL)}, {TYPE(OBJECT), TYPE(BOOL)}, {}, {}}};
        const GDExtensionVariantType outputs[2][4] = {
            {TYPE(NIL), TYPE(OBJECT), TYPE(NIL), TYPE(ARRAY)},
            {TYPE(INT), TYPE(INT), TYPE(ARRAY), TYPE(FLOAT)}};
        for (int method = 0; method < 4; method++) {
            GDExtensionPropertyInfo args[5];
            GDExtensionClassMethodArgumentMetadata metadata[5] = {0};
            for (int a = 0; a < counts[view][method]; a++) {
                int argument = a;
                if (!view && method == 0)
                    argument = 6 + a;
                else if (!view && method == 2)
                    argument = 8 + a;
                else if (view && a == 1)
                    argument = 5;
                args[a] = (GDExtensionPropertyInfo){parameters[view][method][a],
                                                    &us_args[argument],
                                                    &empty_name,
                                                    0,
                                                    &empty_string,
                                                    6};
            }
            GDExtensionPropertyInfo output = {
                outputs[view][method], &empty_name, &empty_name, 0, &empty_string, 6};
            GDExtensionClassMethodInfo binding = {0};
            binding.name = view ? &us_view_methods[method] : &us_store_methods[method];
            binding.method_userdata = (void *)(intptr_t)method;
            binding.call_func = view ? us_view_call : us_store_call;
            binding.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
            binding.argument_count = counts[view][method];
            binding.arguments_info = args;
            binding.arguments_metadata = metadata;
            binding.has_return_value = outputs[view][method] != TYPE(NIL);
            binding.return_value_info = binding.has_return_value ? &output : 0;
            register_method(library, &us_classes[view], &binding);
        }
    }
    us_registered = 1;
}
static void unit_state_deinitialize(void) {
    if (!us_initialized)
        return;
    if (us_registered) {
        unregister_class(library, &us_classes[1]);
        unregister_class(library, &us_classes[0]);
    }
    us_registered = 0;
    for (int i = 0; i < 2; i++)
        get_dtor(TYPE(STRING_NAME))(&us_classes[i]);
    for (int i = 0; i < 22; i++)
        get_dtor(TYPE(STRING_NAME))(&us_properties[i]);
    for (int i = 0; i < 21; i++)
        get_dtor(TYPE(STRING_NAME))(&us_names[i]);
    for (int i = 0; i < 11; i++)
        get_dtor(TYPE(STRING_NAME))(&us_args[i]);
    for (int i = 0; i < 4; i++) {
        get_dtor(TYPE(STRING_NAME))(&us_store_methods[i]);
        get_dtor(TYPE(STRING_NAME))(&us_view_methods[i]);
    }
    get_dtor(TYPE(STRING_NAME))(&us_movement_factor);
    variant_destroy(&us_doctrine);
    get_dtor(TYPE(STRING))(&us_maneuver);
    us_initialized = 0;
}
