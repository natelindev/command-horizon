#ifndef COPPERFIN_UNIT_STATE_API_H
#define COPPERFIN_UNIT_STATE_API_H
enum {
    US_HP,
    US_HP_MAX,
    US_DAMAGE,
    US_INTERVAL,
    US_RANGE,
    US_SIGHT,
    US_CONSTRUCTION,
    US_DOMAIN,
    US_BASE_SPEED,
    US_VETERAN_SPEED,
    US_VETERAN_RELOAD,
    US_SCRAP,
    US_SCALARS
};
/* A zero return means no resident state: preserve the existing live fallback.
 * A successful scalar lookup can still contain the original nullable value. */
static int native_unit_scalar(void *unit, int field, double *value, int *present);
static int native_unit_speed(void *unit, double *speed);
static int native_agent_speed(void *agent, double *speed);
static int native_unit_radius(void *unit, double *radius);
static int native_unit_domain(void *unit, double *domain, int *present);
#endif
