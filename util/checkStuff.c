#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdint.h>
#include <ctype.h>
#include <errno.h>

#define ERR   "\e[1;31m"
#define GOOD  "\e[1;32m"
#define WARN  "\e[1;33m"
#define ITEM  "\e[1;36m"
#define STEP  "\e[1;35m"
#define RESET "\e[0m"

typedef enum {
	REQ_HARD, // implied if not specified
	REQ_WARN,
	REQ_NONE
} req_t;

#define FLAG_NONE		0x00
#define FLAG_ALLOW_DOWNLOAD	0x01
#define FLAG_GENERATE		0x02
#define FLAG_SETVAR		0x04


#define RET_INT_ERR		1
#define RET_NO_PROG		2
#define RET_NO_SRC		3

typedef struct {
	char	name[32];
	char	description[128];
	char	warning[128];
	req_t	requirement;
	uint8_t	flags;
	bool *	toSet;
} item_t;

// keep track of whether or not the user has git
static bool hasGit = false;


static bool dirExists(const char *dir) {
	struct stat sb;
	return (stat(dir, &sb) == 0 && S_ISDIR(sb.st_mode));
}


static bool confirmation(const char *prompt) {
	char answer[32];
startConfirm:
	printf("%s", prompt);
	fgets(answer, sizeof(answer), stdin);

	// convert to lowercase and strip the newline
	for (unsigned int i = 0; i != strlen(answer); i++) {
		answer[i] = tolower(answer[i]);
		if (answer[i] == '\r' || answer[i] == '\n') {
			answer[i] = '\0';
			break;
		}
	}

	if (strcmp(answer, "yes") == 0 || strcmp(answer, "y") == 0 || answer[0] == '\0') {
		return true;
	}


	else if (strcmp(answer, "no") == 0 || strcmp(answer, "n") == 0) {
		return false;
	}

	else {
		printf(ERR "Invalid answer " ITEM "\"%s\"" RESET "!\r\n", answer);
		goto startConfirm;
	}
}

static bool progInPath(const char *execName) {
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

static void promptForDownload(char *base, const char *name, int retOnErr) {
	char confText[128];
	puts("This program can " GOOD "automatically download" RESET " this source code for you!");

	if (!hasGit) {
		puts(WARN "Missing git executable, unable to download." RESET);
		puts("Install git, or download the source yourself!");
		exit(retOnErr);
	}
	snprintf(confText, sizeof(confText), "Would you like to download " ITEM "%s" RESET " using git? [Y/n] ", name);

	if (!confirmation(confText)) {
		printf(WARN "Offer to download denied, however, source " ITEM "%s" WARN " does not exist, but is required.\r\n"
				ERR "Exiting...\r\n" RESET,
				name
		);
		exit(retOnErr);
	}

	char cmd[128] = "git clone https://github.com/Wii-Linux/";

	if (chdir(base) != 0) {
		fprintf(stderr, ERR "chdir(\"%s\") failed: %s\r\n" RESET, base, strerror(errno));
		exit(1);
	}
	strcat(cmd, name);
	if (system(cmd) != 0) {
		printf(ERR "An error has occurred while attempting to download" ITEM "%s" ERR "!\r\n" RESET
				"Please check your internet connection and try again.\r\n", cmd);
		exit(1);
	}
}



static const item_t programs[] = {
	{ "gcc", "Host system compiler", "", REQ_HARD, FLAG_NONE, NULL },
	{ "as", "Host system assembler", "", REQ_HARD, FLAG_NONE, NULL },
	{ "ld", "Host system linker", "", REQ_HARD, FLAG_NONE, NULL },
	{ "make", "Host system make", "", REQ_HARD, FLAG_NONE, NULL },
	{ "cpio", "Utility for dealing with the CPIO archive format - required by buildroot", "", REQ_HARD, FLAG_NONE, NULL },
	{ "tar", "Utility for dealing with the TAR archive format - required by buildroot, and for managing the rootfs", "", REQ_HARD, FLAG_NONE, NULL },
	{ "git", "Git version control software", "The auto-download feature won't work properly if you're missing any code!", REQ_WARN, FLAG_SETVAR, &hasGit },
	{ "bc", "Basic calculator, needed by Linux kernel", "You won't be able to compile the kernel", REQ_WARN, FLAG_NONE, NULL },
	{ "hostname", "Report the system hostname, needed by Linux kernel", "You won't be able to compile the kernel", REQ_WARN, FLAG_NONE, NULL },
	{ "mksquashfs", "Tool to make a squashfs filesystem", "You won't be able to compile a loader", REQ_WARN, FLAG_NONE, NULL },
	{ "powerpc-unknown-linux-gnu-gcc", "PowerPC Cross-Toolchain compiler", "", REQ_HARD, FLAG_NONE, NULL },
	{ "powerpc-unknown-linux-gnu-ld", "PowerPC Cross-Toolchain linker", "", REQ_HARD, FLAG_NONE, NULL },
	{ "powerpc-unknown-linux-gnu-as", "PowerPC Cross-Toolchain assembler", "", REQ_HARD, FLAG_NONE, NULL },
	{ "", "", "", REQ_HARD, FLAG_NONE, NULL }
};


static const item_t directories[] = {
	{ "buildroot", "Wii Linux buildroot fork",
		"You won't be able to build the loader(s) unless you have a pre-generated copy of initrd-src and loader-img-src", REQ_WARN, FLAG_ALLOW_DOWNLOAD, NULL },
	{ "boot-stack", "Wii Linux boot stack (custom init scripts and boot menu)", "You won't be able to build the loader(s)", REQ_WARN, FLAG_ALLOW_DOWNLOAD, NULL },
	{ "build-stack", "Wii Linux build stack", "", REQ_HARD, FLAG_ALLOW_DOWNLOAD, NULL },
	{ "installer", "Wii Linux installer source code", "You won't be able to build the installer", REQ_WARN, FLAG_ALLOW_DOWNLOAD, NULL },
	{ "initrd-src", "Built sources for the internal loader", "", REQ_HARD, FLAG_GENERATE, NULL },
	{ "dummy-sysroot-src", "A copy of the sysroot from sdk.config in order to pull headers and similar from", "", REQ_HARD, FLAG_GENERATE, NULL },
	{ "loader-img-src", "Built sources for the boot menu / loader.img", "", REQ_HARD, FLAG_GENERATE, NULL },
	{ "", "", "", REQ_HARD, FLAG_NONE, NULL }
};

int main(int argc, char *argv[], char *envp[]) {
	int i = 0;
	(void)argc;
	(void)envp;

	char *base = argv[1];
	printf(STEP "Now checking your host system for software compatibility...\r\n" RESET);
	while (programs[i].name[0] != '\0') {
		printf(ITEM "%s" RESET ": %s... ", programs[i].name, programs[i].description);
		if (progInPath(programs[i].name)) {
			puts(GOOD "SUCCESS" RESET);
			if (programs[i].flags & FLAG_SETVAR) { *programs[i].toSet = true; }
		}
		else {
			puts(ERR "FAIL" RESET);
			if (programs[i].flags & FLAG_SETVAR) { *programs[i].toSet = false; }

			if (programs[i].requirement == REQ_HARD) {
				printf(ERR "FAILED" RESET " to find an executable binary for program " ITEM "%s" RESET "!  Please install it.\r\n", programs[i].name);
				return RET_NO_PROG;
			}
			else if (programs[i].requirement == REQ_WARN) {
				printf(WARN "%s\r\n" RESET, programs[i].warning);
			}
			else if (programs[i].requirement == REQ_NONE) {
				// do nothing
			}
			else {
				printf(ERR "INTERNAL ERROR" RESET " - %d isn't a valid value for .requirement of a program!\r\n", programs[i].requirement);
				return 1;
			}

		}
		i++;
	}

	printf(STEP "\r\nNow checking your host system for all required Wii Linux code...\r\n" RESET);
	i = 0;
	while (directories[i].name[0] != '\0') {
		char *dir;
		const char *name = directories[i].name;
		printf(ITEM "%s" RESET ": %s... ", name, directories[i].description);

		dir = malloc(strlen(base) + strlen(name) + 2);
		if (!dir) {
			printf(ERR "FAILED" RESET " to allocate memory for the directory name!\r\n");
			return RET_INT_ERR;
		}

		strcpy(dir, base);
		strcat(dir, "/");
		strcat(dir, name);
		if (dirExists(dir)) {
			puts(GOOD "SUCCESS" RESET);
		}
		else {
			puts(ERR "FAIL" RESET);
			printf(ERR "FAILED" RESET " to find the source directory " ITEM "%s" RESET "!\r\n", name);
			if (directories[i].flags & FLAG_ALLOW_DOWNLOAD) {
				promptForDownload(base, name, RET_NO_SRC);
			}
			else if (directories[i].flags & FLAG_GENERATE) {
				char confText[128];
				char cmd[64] = "../build-stack/util/generate_";
				int ret;
				puts("This program can " GOOD "automatically generate" RESET " this code for you!");
				snprintf(confText, sizeof(confText), "Would you like to generate " ITEM "%s" RESET " using buildroot? [Y/n] ", name);

				if (!confirmation(confText)) {
					printf(WARN "Offer to generate denied, however, source " ITEM "%s" WARN " does not exist, but is required.\r\n"
							ERR "Exiting...\r\n" RESET,
							name
					);
					return RET_NO_SRC;
				}

				chdir(base);
				chdir("buildroot");

				// generate the command
				strcat(cmd, name);
				strcat(cmd, ".sh");
				ret = system(cmd);
				if (ret != 0) {
					printf(ERR "Generating " ITEM "%s" ERR " FAILED!\r\n" WARN
						"This is an " ERR "ERROR" WARN " in the code, and should be reported!\r\n" RESET,
						name
					);
					return 1;
				}
				printf("Generating " ITEM "%s" GOOD " SUCCESS!\r\n" RESET, name);
			}
			else {
				return RET_NO_SRC;
			}
		}
		i++;
	}

	return 0;
}

