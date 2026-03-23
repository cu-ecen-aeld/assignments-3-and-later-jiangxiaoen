#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    // open syslog with LOG_USER
    openlog("writer", LOG_PID, LOG_USER);

    // check arguments
    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments: got %d", argc - 1);
        fprintf(stderr, "Usage: %s <file> <string>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *file_path = argv[1];
    const char *write_str = argv[2];

    // open file to write
    FILE *file = fopen(file_path, "w");
    if (file == NULL) {
        syslog(LOG_ERR, "Error opening file %s", file_path);
        perror("fopen");
        closelog();
        return 1;
    }

    //write the string
    int bytes_written = fprintf(file, "%s", write_str);
    if (bytes_written < 0) {
        syslog(LOG_ERR, "Failed to write to file %s: %s", file_path, strerror(errno));
        fprintf(stderr, "Error: Could not write to file %s\n", file_path);
        fclose(file);
        closelog();
        return 1;
    }

    fclose(file);

    // log success
    syslog(LOG_DEBUG, "Writing %s to %s", write_str, file_path);

    closelog();
    return 0;
}
