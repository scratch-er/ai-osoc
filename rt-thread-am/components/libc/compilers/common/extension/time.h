#ifndef __RTTHREAD_AM_TIME_H__
#define __RTTHREAD_AM_TIME_H__

#include <rtconfig.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef long time_t;
typedef long clock_t;

#ifndef CLOCKS_PER_SEC
#define CLOCKS_PER_SEC RT_TICK_PER_SECOND
#endif

struct tm
{
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
};

clock_t clock(void);
time_t time(time_t *t);
time_t mktime(struct tm *timeptr);
struct tm *gmtime(const time_t *timep);
struct tm *gmtime_r(const time_t *timep, struct tm *result);
struct tm *localtime(const time_t *timep);
struct tm *localtime_r(const time_t *timep, struct tm *result);
char *asctime(const struct tm *timeptr);
char *asctime_r(const struct tm *timeptr, char *buf);
char *ctime(const time_t *timer);
char *ctime_r(const time_t *timer, char *buf);

#ifdef __cplusplus
}
#endif

#endif
