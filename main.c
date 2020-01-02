#include <arpa/inet.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>

#include <microhttpd.h>

#include "webroot.h"

#define PORT 8888

const char *not_found = "404 not found";

const static_file *find_file(const char *path) {
  for (size_t i = 0; i < static_files_len; i++) {
    if (strcmp(path, static_files[i].path) == 0) {
      return static_files + i;
    }
  }

  return NULL;
}

const static_file *find_url(const char *dir_prefix, const char *index_file_name,
                            const char *path) {
  const size_t search_str_sz =
      strlen(dir_prefix) + strlen(index_file_name) + strlen(path) + 1;
  char *search_str = malloc(search_str_sz);
  assert(search_str != NULL);

  memset(search_str, 0, search_str_sz);
  strcpy(search_str, dir_prefix);
  strcat(search_str, path);

  const static_file *ret = find_file(search_str);
  if (ret == NULL) {
    strcat(search_str, index_file_name);
    ret = find_file(search_str);
  }

  free(search_str);

  return ret;
}

char *get_ip_str(const struct sockaddr *addr, char *s, size_t max_len) {
  switch (addr->sa_family) {
    case AF_INET:
      inet_ntop(AF_INET, &(((struct sockaddr_in *)addr)->sin_addr), s, max_len);
      break;

    case AF_INET6:
      inet_ntop(AF_INET6, &(((struct sockaddr_in6 *)addr)->sin6_addr), s,
                max_len);
      break;

    default:
      strncpy(s, "unknown", max_len);
      return NULL;
  }

  return s;
}

int answer_to_connection(void *cls, struct MHD_Connection *connection,
                         const char *url, const char *method,
                         const char *version, const char *upload_data,
                         size_t *upload_data_size, void **con_cls) {
  const union MHD_ConnectionInfo *conn_info =
      MHD_get_connection_info(connection, MHD_CONNECTION_INFO_CLIENT_ADDRESS);
  struct MHD_Response *response;
  int ret;

  char remote_addr_str[16] = {0};
  get_ip_str(conn_info->client_addr, remote_addr_str, 15);
  printf("Req %s %s %s from %s\n", method, url, version, remote_addr_str);

  const static_file *file = find_url("webroot", "index.html", url);
  if (file != NULL) {
    printf("-> 200 hash=%s path='%s'\n", file->hash, file->path);

    response = MHD_create_response_from_buffer(file->data_len, file->data,
                                               MHD_RESPMEM_PERSISTENT);
    ret = MHD_queue_response(connection, MHD_HTTP_OK, response);
  } else {
    printf("-> 404\n");
    response = MHD_create_response_from_buffer(strlen(not_found), not_found,
                                               MHD_RESPMEM_PERSISTENT);

    ret = MHD_queue_response(connection, MHD_HTTP_NOT_FOUND, response);
  }

  MHD_destroy_response(response);

  return ret;
}

int main() {
  struct MHD_Daemon *daemon;

  daemon = MHD_start_daemon(MHD_USE_INTERNAL_POLLING_THREAD, PORT, NULL, NULL,
                            &answer_to_connection, NULL, MHD_OPTION_END);
  if (NULL == daemon) return 1;

  printf("Serving at http://localhost:%d\n", PORT);

  getchar();

  MHD_stop_daemon(daemon);
  return 0;
}
