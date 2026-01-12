#define SOCKET_PATH "/tmp/faceunlock.sock"
#define PAM_SM_AUTH

#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <syslog.h>

PAM_EXTERN int pam_sm_authenticate(
    pam_handle_t *pamh, int flags, int argc, const char **argv)
{

    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: module entered");

    const char *user;

    if (pam_get_user(pamh, &user, NULL) != PAM_SUCCESS)
    {
        pam_syslog(pamh, LOG_ERR, "pam_faceunlock: FAILED to get username");

        return PAM_IGNORE;
    }
    
    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: got username: %s", user);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);

    if (fd < 0)
    {
        pam_syslog(pamh, LOG_ERR, "pam_faceunlock: FAILED to create socket");

        return PAM_IGNORE;
    }
    
    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: socket created successfully");

    struct sockaddr_un addr = {0};

    addr.sun_family = AF_UNIX;

    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0)
    {
        close(fd);
        pam_syslog(pamh, LOG_ERR, "pam_faceunlock: FAILED to connect to daemon socket at %s", SOCKET_PATH);

        return PAM_IGNORE;
    }
    
    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: connected to daemon");

    char buf[256];

    snprintf(buf, sizeof(buf), "{\"user\":\"%s\"}", user);
    write(fd, buf, strlen(buf));
    
    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: sent request: %s", buf);

    char resp[256] = {0};

    int n = read(fd, resp, sizeof(resp) - 1);
    close(fd);

    if (n <= 0)
    {
        pam_syslog(pamh, LOG_ERR, "pam_faceunlock: FAILED to read response from daemon");

        return PAM_IGNORE;
    }
    
    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: received response: %s", resp);

    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: received response: %s", resp);

    if (strstr(resp, "\"ok\": true"))
    {
        pam_syslog(pamh, LOG_INFO, "pam_faceunlock: face match SUCCESS");

        return PAM_SUCCESS;
    }

    pam_syslog(pamh, LOG_ERR, "pam_faceunlock: face match FAILED - response did not contain success");
    return PAM_IGNORE;
}

PAM_EXTERN int pam_sm_setcred(
    pam_handle_t *pamh, int flags, int argc, const char **argv)
{
    pam_syslog(pamh, LOG_INFO, "pam_faceunlock: setcred called");

    return PAM_SUCCESS;
}
