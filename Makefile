WEBROOT_DIR = ./webroot

WEB_FILES = $(shell find $(WEBROOT_DIR) -type f)
WEB_FILES_OBJS = $(addprefix build/objs/, $(addsuffix .o, $(WEB_FILES)))

BUILD_DIR = ./build
AR = ar
OBJCOPY = objcopy
ARCH = x86-64
CFLAGS = -I$(BUILD_DIR)
LDFLAGS = $(shell pkg-config libmicrohttpd --variable=libdir)/libmicrohttpd.a $(shell pkg-config --libs gnutls) -lpthread

.PHONY: all
all: $(BUILD_DIR)/main

build/objs/%.o: %
	mkdir -p $(shell dirname $@)
	python3 -c "import sys; print(''.join([c if c.isalnum() else '_' for c in sys.argv[1]]))" $< > $@.name
	sha256sum $< | awk '{print $$1}' > $@.hash
	$(OBJCOPY) \
		--input-target binary \
		--output-target elf64-$(ARCH) \
		--binary-architecture i386:$(ARCH) \
		--redefine-sym "_binary_$$(cat $@.name)_start=blob_$$(cat $@.hash)_start" \
		--redefine-sym "_binary_$$(cat $@.name)_end=blob_$$(cat $@.hash)_end" \
		--redefine-sym "_binary_$$(cat $@.name)_size=blob_$$(cat $@.hash)_size" \
		$< $@

$(BUILD_DIR)/web_files.hashes: $(WEB_FILES)
	mkdir -p $(shell dirname $@)
	sha256sum $^ > $@

$(BUILD_DIR)/$(WEBROOT_DIR).a: $(WEB_FILES_OBJS)
	mkdir -p $(shell dirname $@)
	$(AR) rcs $@ $^

$(BUILD_DIR)/$(WEBROOT_DIR).h: $(BUILD_DIR)/web_files.hashes gen_header.py
	python3 gen_header.py $< > $@

clean:
	rm -rf $(BUILD_DIR)/

$(BUILD_DIR)/main.c.o: main.c $(BUILD_DIR)/$(WEBROOT_DIR).h
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/main: $(BUILD_DIR)/main.c.o $(BUILD_DIR)/$(WEBROOT_DIR).a
	$(CC) -o $@ $^ $(LDFLAGS)
