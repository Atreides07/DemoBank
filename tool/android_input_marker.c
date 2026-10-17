#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

/* Build for the device ABI with the Android NDK's clang. The host collector
 * uploads this helper into its own temporary namespace; it does not install it.
 * CLOCK_MONOTONIC shares SurfaceFlinger's fence time base. The timestamp precedes
 * exec/input startup and dispatch, so it gives a conservative automated-input
 * bound, not the time of a physical touch or of a completed screen transition. */
static int valid_coordinate(const char *text) {
  char *end = NULL;
  errno = 0;
  const long value = strtol(text, &end, 10);
  return errno == 0 && end != text && *end == '\0' && value >= 0 &&
         value <= INT_MAX;
}

int main(int argc, char **argv) {
  if (argc != 3 || !valid_coordinate(argv[1]) || !valid_coordinate(argv[2])) {
    fputs("usage: input_marker <nonnegative-x> <nonnegative-y>\n", stderr);
    return 64;
  }
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    perror("clock_gettime");
    return 1;
  }
  const int64_t stamp = (int64_t)now.tv_sec * INT64_C(1000000000) + now.tv_nsec;
  if (printf("BEFORE_INJECT_NS=%" PRId64 "\n", stamp) < 0 ||
      fflush(stdout) != 0) {
    return 1;
  }
  execl("/system/bin/input", "input", "tap", argv[1], argv[2], (char *)NULL);
  perror("exec input");
  return 1;
}
