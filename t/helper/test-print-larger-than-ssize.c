#include "test-tool.h"
#include "cache.h"

int cmd__print_larger_than_ssize(int argc, const char **argv)
{
	size_t large = ~0;

	large = ~(large & ~(large >> 1)) + 1;
	printf("%" PRIuMAX "\n", (uintmax_t) large);
	return 0;
}
