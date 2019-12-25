# https://balau82.wordpress.com/2012/02/19/linking-a-binary-blob-with-gcc/
# https://github.com/bazelbuild/rules_cc/blob/262ebec3c2296296526740db4aefce68c80de7fa/examples/my_c_archive/my_c_archive.bzl

load("@rules_cc//cc:action_names.bzl", "CPP_LINK_STATIC_LIBRARY_ACTION_NAME")

HEADER_TEMPLATE = """
extern unsigned char blob_59b0d9568c778e76193bde5e3b5cc5e713f3a14daeba405e7d8f129d775c11cf_start;
extern unsigned char blob_59b0d9568c778e76193bde5e3b5cc5e713f3a14daeba405e7d8f129d775c11cf_size;
"""

def mangle_name(name):
    """
    Implementation of mangle_name() from binutils bfd/binary.c

    Replace every char not in [A-Za-z0-9] with '_'
    """
    return ''.join([c if c.isalnum() else '_' for c in name.elems()])


def _impl(ctx):
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
        # TODO do not hardcode arch
        sym_name = '_binary_' + mangle_name(input_file.path)
        ctx.actions.run_shell(
            outputs = [obj_file],
            inputs = [input_file, hash_file],
            progress_message = "Converting to ELF for %s" % input_file.short_path,
            command = """
                hash="$(cat %s | awk '{print $1}')"
                objcopy -I binary -O elf64-x86-64 -B i386:x86-64 \
                    --redefine-sym "%s_start=blob_${hash}_start" \
                    --redefine-sym "%s_end=blob_${hash}_end" \
                    --redefine-sym "%s_size=blob_${hash}_size" \
                    '%s' '%s'
            """ % (hash_file.path, sym_name, sym_name, sym_name, input_file.path, obj_file.path),
        )

        files.append((obj_file, hash_file))

    # create a file containing all hashes + paths
    hashes = ctx.actions.declare_file(ctx.outputs.lib.path + ".txt")
    ctx.actions.run_shell(
        outputs = [hashes],
        inputs = [f[1] for f in files],
        command = "cat %s > %s" % (' '.join(["'{}'".format(f[1].path) for f in files]), hashes.path),
    )

    # write ar script
    # TODO make this portable
    ar_script_content = "CREATE %s\n" % ctx.outputs.lib.path
    for f in files:
        ar_script_content += "ADDMOD '%s'\n" % f[0].path
    ar_script_content += "SAVE\n"
    ar_script_content += "END\n"

    ar_script = ctx.actions.declare_file(ctx.outputs.lib.path + ".ar_script")
    ctx.actions.write(output=ar_script, content=ar_script_content)

    # assemble static library
    ctx.actions.run_shell(
        outputs = [ctx.outputs.lib],
        inputs = [f[0] for f in files] + [ar_script],
        command = "/usr/bin/ar -M < %s" % (ar_script.path)
    )

    ctx.actions.write(output=ctx.outputs.header, content=HEADER_TEMPLATE)

    # Workaround https://github.com/bazelbuild/bazel/issues/6874.
    # Should be find_cpp_toolchain() instead.
    cc_toolchain = ctx.attr._cc_toolchain[cc_common.CcToolchainInfo]
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    library_to_link = cc_common.create_library_to_link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        static_library = ctx.outputs.lib,
        cc_toolchain = cc_toolchain,
    )
    compilation_context = cc_common.create_compilation_context(
        headers = depset([ctx.outputs.header]),
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

files_to_obj = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "_cc_toolchain": attr.label(default = Label("@bazel_tools//tools/cpp:current_cc_toolchain")),
    },
    outputs = {
        "header": "%{name}.h",
        "lib": "%{name}.a",
    },
    fragments = ["cpp"],
    toolchains = ["@bazel_tools//tools/cpp:toolchain_type"],
)
