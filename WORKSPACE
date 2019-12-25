workspace(name = "staticweb")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

HTTPLIB_VERSION = "0.9.69"

http_archive(
    name = "libmicrohttpd",
    build_file = "//:libmicrohttpd.BUILD",
    strip_prefix = "libmicrohttpd-0.9.69",
    sha256 = "fb9b6b148b787493e637d3083588711e65cbcb726fa02cee2cd543c5de27e37e",
    url = "https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-{}.tar.gz".format(HTTPLIB_VERSION),
)
