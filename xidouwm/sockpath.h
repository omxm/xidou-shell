/* See LICENSE file for copyright and license details.
 *
 * Where xidouwm's IPC socket lives. Both xidouwm (dwm.c) and xidouwm-msg
 * (dwm-msg.c) include this, so the server and the client can't disagree.
 * The path is resolved at run time, not compile time, because it depends
 * on the session's environment:
 *
 *   1. $XIDOU_WM_SOCKET, if set and non-empty -- test instances only.
 *   2. $XDG_RUNTIME_DIR/xidouwm.sock -- the normal session socket. That
 *      directory is per-user, mode 0700, and removed at logout.
 *   3. /tmp/xidouwm-<uid>.sock, if $XDG_RUNTIME_DIR is unset or not an
 *      absolute path (the XDG spec says to ignore a relative one). This
 *      keeps a session without elogind working. xidouwm warns about it.
 *
 * A path that doesn't fit sun_path is an error, never a fallback to the
 * next rule. In particular, an over-long $XIDOU_WM_SOCKET must not fall
 * back to the session socket: ipc_create_socket() unlink()s whatever is at
 * its path before binding, so a test instance would take over the live
 * session's IPC, and a test client would send its commands to the live WM.
 *
 * `xidouwm-msg --socket-path` prints the result, so shell scripts (session/
 * xidou-xinitrc) never need their own copy of these rules. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define XIDOUWM_SOCKNAME "xidouwm.sock"

/* Writes the socket path into buf (size is normally sizeof(sun_path)).
 * Returns 0 on success, or -1 after printing why to stderr, prefixed with
 * prog. warnfallback prints a notice when rule 3 is used. */
static int
xidouwm_sockpath(char *buf, size_t size, const char *prog, int warnfallback)
{
	const char *env = getenv("XIDOU_WM_SOCKET");
	const char *dir = getenv("XDG_RUNTIME_DIR");
	int n;

	if (env && *env) {
		n = snprintf(buf, size, "%s", env);
		if (n < 0 || (size_t)n >= size) {
			fprintf(stderr, "%s: XIDOU_WM_SOCKET too long (%zu bytes, max %zu); "
				"not falling back to the session socket\n",
				prog, strlen(env), size - 1);
			return -1;
		}
		return 0;
	}
	if (dir && dir[0] == '/') {
		n = snprintf(buf, size, "%s/" XIDOUWM_SOCKNAME, dir);
		if (n < 0 || (size_t)n >= size) {
			fprintf(stderr, "%s: $XDG_RUNTIME_DIR/" XIDOUWM_SOCKNAME
				" too long (max %zu bytes)\n", prog, size - 1);
			return -1;
		}
		return 0;
	}
	n = snprintf(buf, size, "/tmp/xidouwm-%lu.sock", (unsigned long)getuid());
	if (n < 0 || (size_t)n >= size)
		return -1;
	if (warnfallback)
		fprintf(stderr, "%s: XDG_RUNTIME_DIR is not set; using %s\n", prog, buf);
	return 0;
}
