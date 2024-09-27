#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>

#define ERR   "\e[1;31m"
#define GOOD  "\e[1;32m"
#define WARN  "\e[1;33m"
#define ITEM  "\e[1;36m"
#define RESET "\e[0m"

typedef enum {
	REQ_HARD, // implied if not specified
	REQ_WARN,
	REQ_GEN, // generate this
	REQ_NONE
} req_t;

typedef struct {
	char	name[32];
	char	description[128];
	char	warning[128];
	req_t	requirement;
} item_t;


static bool progInPath(char *execName) {
	// get the PATH
	char *path_orig = getenv("PATH");
	if (path_orig == NULL) {
		// shouldn't ever fail, but just in case
		perror("getenv");
		exit(1);
	}

	// copy it, strtok will modify it later
	char *path = strdup(path_orig);
	if (path == NULL) {
		// probably out of mem
		perror("strdup");
		exit(1);
	}

	// split on :
	char *dir = strtok(path, ":");
	while (dir != NULL) {
		// build a path to the exec
		char full_path[1024];
		snprintf(full_path, sizeof(full_path), "%s/%s", dir, execName);

		// does it exist and we can exec it?
		if (access(full_path, X_OK) == 0) {
			// yes, clean up and leave
			free(path);
			return true;
		}

		// no, get the next dir
		dir = strtok(NULL, ":");
	}

    // free the strdup'd path
    free(path);

    // not found
    return false;
}


static item_t programs[] = {
	{ "gcc", "Host system compiler" },
	{ "as", "Host system assembler" },
	{ "ld", "Host system linker" },
	{ "make", "Host system make" },
	{ "bc", "Basic calculator, needed by Linux kernel", "You won't be able to compile the kernel", REQ_WARN },
	{ "powerpc-unknown-linux-gnu-gcc", "PowerPC Cross-Toolchain compiler" },
	{ "powerpc-unknown-linux-gnu-ld", "PowerPC Cross-Toolchain linker" },
	{ "powerpc-unknown-linux-gnu-as", "PowerPC Cross-Toolchain assembler" },
	{ }
};


static item_t directories[] = {
	{ "buildroot", "Wii Linux buildroot fork", "You won't be able to build the loader(s) unless you have a pre-generated copy of initrd-src and loader-img-src", REQ_WARN },
	{ "boot-stack", "Wii Linux boot stack (custom init scripts and boot menu)", "You won't be able to build the loader(s)", REQ_WARN },
	{ "build-stack", "Wii Linux build stack" },
	{ "installer", "Wii Linux installer source code", "You won't be able to build the installer", REQ_WARN },
	{ "initrd-src", "Built sources for the internal loader", "", REQ_GEN },
	{ "loader-img-src", "Built sources for the boot menu / loader.img", "", REQ_GEN },
	{ }
};

int main(int argc, char *argv[], char *envp[]) {
	int i = 0;

	char *base = argv[1];
	printf("Now checking your host system for software compatibility...\r\n");
	while (programs[i].name[0] != '\0') {
		printf(ITEM "%s" RESET ": %s... ", programs[i].name, programs[i].description);
		if (progInPath(programs[i].name)) {
			puts(GOOD "SUCCESS" RESET);
		}
		else {
			puts(ERR "FAIL" RESET);
			printf(ERR "FAILED" RESET " to find an executable binary for program " ITEM "%s" RESET "!  Please install it.\r\n", programs[i].name);
			exit(2);
		}
		i++;
	}

	printf("Now checking your host system for all required Wii Linux code...\r\n");
	i = 0;
	while (directories[i].name[0] != '\0') {
		char *dir = malloc(strlen(base) + strlen(directories[i].name) + 2);
		printf(ITEM "%s" RESET ": %s... ", directories[i].name, directories[i].description);

		strcpy(dir, base);
		strcat(dir, "/");
		strcat(dir, directories[i].name);
		if (dirExists(dir)) {
			puts(GOOD "SUCCESS" RESET);
		}
		else {
			puts(ERR "FAIL" RESET);
			printf(ERR "FAILED" RESET " to find the source directory " ITEM "%s" RESET "!\r\n", directories[i].name);
			exit(3);
		}
		i++;
	}

	return 0;
}

