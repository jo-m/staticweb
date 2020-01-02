load("@rules_cc//cc:action_names.bzl", "CPP_LINK_STATIC_LIBRARY_ACTION_NAME")

# TODO: Factor out to file
HASHES_TO_HEADER_PY = """
import sys

def hashes_paths():
    with open(sys.argv[1], 'r') as f:
        for line in f.readlines():
            hash, _, path = line.strip().partition(' ')
            yield hash, path[1:]

hashes_paths = list(hashes_paths())

for hash, path in hashes_paths:
    print(f"extern unsigned char blob_{hash}_start;")
    print(f"extern unsigned char blob_{hash}_end;")
    print(f"extern unsigned char blob_{hash}_size;")

print('typedef struct static_file {')
print('    char *hash;')
print('    // length of hash in bytes, excluding terminating 0 char')
print('    size_t hash_len;')
print('    char *path;')
print('    // length of path in bytes, excluding terminating 0 char')
print('    size_t path_len;')
print('    // file contents, no terminating 0 char')
print('    void *data;')
print('    // size of file contents in bytes')
print('    size_t data_len;')
print('} static_file;')

print('const static static_file static_files[] = {')
for hash, path in hashes_paths:
    assert not '"' in path
    assert not '"' in hash
    print(f'{{ "{hash}", {len(hash)}, "{path}", {len(path)}, ((void *)&blob_{hash}_start), ((size_t)&blob_{hash}_size)}},')
print('};')
print(f'const static size_t static_files_len = {len(hashes_paths)};')
"""

def mangle_name(name):
    """
    Replace every char not in A-Za-z0-9 with '_'

    Implements mangle_name() from binutils bfd/binary.c
    """
    return ''.join([c if c.isalnum() else '_' for c in name.elems()])


def get_toolchain(ctx):
    # Workaround https://github.com/bazelbuild/bazel/issues/6874.
    # Should be find_cpp_toolchain() instead.
    return ctx.attr._cc_toolchain[cc_common.CcToolchainInfo]


def build_cc_info(ctx, lib, header):
    cc_toolchain = get_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        static_library = lib,
        cc_toolchain = cc_toolchain,
    )
    compilation_context = cc_common.create_compilation_context(
        headers = depset([header]),
    )
    linking_context = cc_common.create_linking_context(
        libraries_to_link = [library_to_link],
    )
    return cc_common.merge_cc_infos(
        cc_infos = [
            CcInfo(
                compilation_context = compilation_context,
                linking_context = linking_context,
            )
        ]
    )


def create_static_lib(ctx, output_lib, obj_files):
    # write ar script
    # TODO use ar from toolchain:
    # https://github.com/bazelbuild/rules_cc/blob/262ebec3c2296296526740db4aefce68c80de7fa/examples/my_c_archive/my_c_archive.bzl#L42
    ar_script_content = "CREATE %s\n" % ctx.outputs.lib.path
    for f in obj_files:
        ar_script_content += "ADDMOD '%s'\n" % f.path
    ar_script_content += "SAVE\n"
    ar_script_content += "END\n"

    ar_script = ctx.actions.declare_file(output_lib.path + ".ar_script")
    ctx.actions.write(output=ar_script, content=ar_script_content)

    # assemble static library
    ctx.actions.run_shell(
        outputs = [output_lib],
        inputs = obj_files + [ar_script],
        command = "/usr/bin/ar -M < %s" % (ar_script.path)
    )


def _impl(ctx):
    cc_toolchain = get_toolchain(ctx)
    files = []

    # for each input file
    for input_file in ctx.files.srcs:
        hash_file = ctx.actions.declare_file(input_file.path + ".hash")
        obj_file = ctx.actions.declare_file(input_file.path + ".o")

        # write its hash + path into *.hash file
        ctx.actions.run_shell(
            outputs = [hash_file],
            inputs = [input_file],
            progress_message = "Computing hash for %s" % input_file.short_path,
            command = "sha256sum %s > %s" % (input_file.path, hash_file.path),
        )

        # create a *.o file, with symbol name derived from hash
        # TODO: gzip contents before
        sym_name = '_binary_' + mangle_name(input_file.path)
        arch = 'x86-64'
        ctx.actions.run_shell(
            outputs = [obj_file],
            inputs = [input_file, hash_file],
            progress_message = "Converting to ELF for " + input_file.short_path,
            command = """
                hash="$(cat {hash_file} | awk '{{print $1}}')"
                {exe} \
                    --input-target binary \
                    --output-target elf64-{arch} \
                    --binary-architecture i386:{arch} \
                    \
                    --redefine-sym "{sym_name}_start=blob_${{hash}}_start" \
                    --redefine-sym "{sym_name}_end=blob_${{hash}}_end" \
                    --redefine-sym "{sym_name}_size=blob_${{hash}}_size" \
                    '{input_file}' '{obj_file}'
            """.format(hash_file=hash_file.path,
                   exe=cc_toolchain.objcopy_executable,
                   sym_name=sym_name,
                   input_file=input_file.path, obj_file=obj_file.path, arch=arch),
        )

        files.append((obj_file, hash_file))

    # create a file containing all hashes + paths
    ctx.actions.run_shell(
        outputs = [ctx.outputs.hashes],
        inputs = [f[1] for f in files],
        command = "cat %s > %s" % (' '.join(["'{}'".format(f[1].path) for f in files]), ctx.outputs.hashes.path),
    )

    # create header file
    py_script = ctx.actions.declare_file(ctx.outputs.lib.path + ".py")
    ctx.actions.write(output=py_script, content=HASHES_TO_HEADER_PY)
    ctx.actions.run_shell(
        outputs = [ctx.outputs.header],
        inputs = [ctx.outputs.hashes, py_script],
        command = "/usr/bin/env python3 %s %s > %s" % (py_script.path, ctx.outputs.hashes.path, ctx.outputs.header.path)
    )

    create_static_lib(ctx, ctx.outputs.lib, [f[0] for f in files])

    return build_cc_info(ctx, ctx.outputs.lib, ctx.outputs.header)

files_to_obj = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    outputs = {
        "hashes": "%{name}.hashes.txt",
        "header": "%{name}.h",
        "lib": "%{name}.a",
    },
    fragments = ["cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
