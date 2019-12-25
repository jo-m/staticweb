package(default_visibility = ["//visibility:public"])

filegroup(
    name = "all_files",
    srcs = glob(["**/*"]),
)

CMD = """
base="$$(dirname '$(location README)')"
pushd "$$base"
./configure
make -j4
popd
cp "$$base/src/microhttpd/.libs/libmicrohttpd.a" $@
"""

genrule(
    name = "build",
    srcs = [":all_files", "README"],
    outs = ["libmicrohttpd.a"],
    cmd = CMD,
)

cc_library(
    linkstatic = 1,
    name = "lib",
    srcs = [":build"],
    hdrs = glob(["src/include/*.h"]),
    includes = ["src/include/"],
    linkopts = ["-pthread"],
)
