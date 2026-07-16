CC := gcc
CFLAGS := -Wall -Wextra -fPIC -O0 -g
TARGET := libkfd_ioctl_shim.so

.PHONY: all clean

all: $(TARGET)

$(TARGET): kfd_ioctl_shim.c
	$(CC) $(CFLAGS) -shared -o $@ $< -ldl

clean:
	rm -f $(TARGET)
