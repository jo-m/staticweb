load(":files_to_obj.bzl", "files_to_obj")

files_to_obj(
    name = "webroot",
    srcs = glob(["webroot/**/*"])
)

# bazel run //:main
cc_binary(
    name = "main",
    srcs = ["main.c"],
    deps = [
        "@libmicrohttpd//:lib",
        ":webroot"
    ],
    linkstatic = 1,
    features = ["fully_static_link"],
)
