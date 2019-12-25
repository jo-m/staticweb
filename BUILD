load(":files_to_obj.bzl", "files_to_obj")

files_to_obj(
    name = "public",
    srcs = glob(["public/**/*"])
)

# bazel run //:main
cc_binary(
    name = "main",
    srcs = ["main.c"],
    deps = [
        "@libmicrohttpd//:lib",
        ":public"
    ],
    linkstatic = 1,
    features = ["fully_static_link"],
)
