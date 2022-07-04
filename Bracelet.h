#ifndef SMARTBRACELET_H
#define SMARTBRACELET_H

typedef nx_struct my_msg {
	nx_uint16_t msg_type;
	nx_uint8_t msg_key[20];
	nx_uint16_t msg_x;
	nx_uint16_t msg_y;
	nx_uint8_t msg_status;
} my_msg_t;


#define KEY 1
#define INFO 2 
#define ALERT 3
#define DONE 4

#define STANDING 1
#define WALKING 2
#define RUNNING 3
#define FALLING 4

// Pre-loaded random keys
#define FOREACH_KEY(KEY) \
        KEY(BFBD2d3VsBNIsfJO68dI) \
        KEY(xr3gBthvdhvFhvB6iHUH) \
        KEY(ygxbbBb7UUYUYGiubiuh) \
        KEY(sacuycagb7Nun0u90m9I) \
        KEY(IMIMi09i9ioinhbvdc5c) \
        KEY(q65v76tb8n98u09mu9n8) \
        KEY(nuyb8byn98uiyi8u9uBF) \
        KEY(BD2d3VsBNIsfJO68dIby) \
        
#define GENERATE_ENUM(ENUM) ENUM,
#define GENERATE_STRING(STRING) #STRING,

enum KEY_ENUM {
    FOREACH_KEY(GENERATE_ENUM)
};

enum{
AM_MY_MSG = 6,
};

static const char *RANDOM_KEY[] = {
    FOREACH_KEY(GENERATE_STRING)
};

#endif
