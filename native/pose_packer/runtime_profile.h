/* Optional main-thread elapsed timings, using Godot's public monotonic clock.
 * Timers are disabled unless explicitly requested; nested timings are reported
 * separately and must not be added to their enclosing stages. */
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#endif
static GDExtensionInterfaceGlobalGetSingleton profile_singleton;
static GDExtensionMethodBindPtr profile_clock;
static void *profile_time;

static uint64_t profile_now(void) {
    int64_t usec = 0;
    if (profile_time && profile_clock)
        ptrcall(profile_clock, profile_time, 0, &usec);
    return (uint64_t)usec;
}
static void profile_array(const uint64_t *values, int count, void *ret) {
    Value array;
    get_ctor(TYPE(ARRAY), 0)(&array, 0);
    for (int i = 0; i < count; i++) {
        Value value;
        int64_t n = (int64_t)values[i];
        from_type(TYPE(INT))(&value, &n);
        const void *args[] = {&value};
        array_append(&array, args, 0, 1);
        variant_destroy(&value);
    }
    from_type(TYPE(ARRAY))(ret, &array);
    get_dtor(TYPE(ARRAY))(&array);
}
static void profile_cpu_call(void *userdata, void *instance, const GDExtensionConstVariantPtr *args,
                             GDExtensionInt count, GDExtensionVariantPtr ret,
                             GDExtensionCallError *error) {
    (void)userdata;
    (void)instance;
    (void)args;
    if (count != 0) {
        variant_nil(ret);
        error->error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
        return;
    }
    uint64_t values[4] = {0}; /* available, process CPU us, caller thread CPU us, cycles */
#ifdef _WIN32
    FILETIME created, exited, pk, pu, tk, tu;
    ULONG64 cycles = 0;
    if (GetProcessTimes(GetCurrentProcess(), &created, &exited, &pk, &pu) &&
        GetThreadTimes(GetCurrentThread(), &created, &exited, &tk, &tu) &&
        QueryThreadCycleTime(GetCurrentThread(), &cycles)) {
        values[0] = 1;
        values[1] = (((uint64_t)pk.dwHighDateTime << 32) | pk.dwLowDateTime) +
                    (((uint64_t)pu.dwHighDateTime << 32) | pu.dwLowDateTime);
        values[2] = (((uint64_t)tk.dwHighDateTime << 32) | tk.dwLowDateTime) +
                    (((uint64_t)tu.dwHighDateTime << 32) | tu.dwLowDateTime);
        values[1] /= 10;
        values[2] /= 10;
        values[3] = (uint64_t)cycles;
    }
#endif
    profile_array(values, 4, ret);
    error->error = GDEXTENSION_CALL_OK;
}
static int runtime_profile_load(GDExtensionInterfaceGetProcAddress proc) {
    profile_singleton = (GDExtensionInterfaceGlobalGetSingleton)proc("global_get_singleton");
    return profile_singleton != 0;
}
static void runtime_profile_initialize(void) {
    Value name, method;
    name_new(&name, "Time");
    name_new(&method, "get_ticks_usec");
    profile_clock = method_bind(&name, &method, 3905245786LL);
    profile_time = profile_singleton(&name);
    get_dtor(TYPE(STRING_NAME))(&method);
    get_dtor(TYPE(STRING_NAME))(&name);
    name_new(&name, "cpu_sample");
    GDExtensionPropertyInfo output = {TYPE(ARRAY), &empty_name, &empty_name, 0, &empty_string, 6};
    GDExtensionClassMethodInfo info = {0};
    info.name = &name;
    info.call_func = profile_cpu_call;
    info.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
    info.has_return_value = 1;
    info.return_value_info = &output;
    register_method(library, &class_name, &info);
    get_dtor(TYPE(STRING_NAME))(&name);
}
