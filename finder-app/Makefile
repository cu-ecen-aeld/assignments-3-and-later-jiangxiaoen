# cross-compiler prefix (empty by default)
CROSS_COMPILE ?=

# compiler and flags
CC = $(CROSS_COMPILE)gcc
CFLAGS = -Wall -Wextra

# target executable
TARGET = writer

# source files
SRCS = writer.c
OBJS = $(SRCS:.c=.o)

# default target (native)
all: $(TARGET)

# link object files into executable
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^

# compile .c to .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# clean up build
clean:
	rm -f $(TARGET) $(OBJS)

.PHONY: all clean
