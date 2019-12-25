/*
  bazel run //:main
 */

#include <stdio.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/types.h>

#include <microhttpd.h>

#include "public.h"

#define PORT 8888

int answer_to_connection(void *cls, struct MHD_Connection *connection,
                         const char *url, const char *method,
                         const char *version, const char *upload_data,
                         size_t *upload_data_size, void **con_cls) {
  struct MHD_Response *response;
  int ret;

  response = MHD_create_response_from_buffer(
      &blob_59b0d9568c778e76193bde5e3b5cc5e713f3a14daeba405e7d8f129d775c11cf_size,
      (void
           *)&blob_59b0d9568c778e76193bde5e3b5cc5e713f3a14daeba405e7d8f129d775c11cf_start,
      MHD_RESPMEM_PERSISTENT);

  ret = MHD_queue_response(connection, MHD_HTTP_OK, response);
  MHD_destroy_response(response);

  return ret;
}

int main() {
  struct MHD_Daemon *daemon;

  daemon = MHD_start_daemon(MHD_USE_INTERNAL_POLLING_THREAD, PORT, NULL, NULL,
                            &answer_to_connection, NULL, MHD_OPTION_END);
  if (NULL == daemon) return 1;

  printf("Running at http://0.0.0.0:%d", PORT);

  getchar();

  MHD_stop_daemon(daemon);
  return 0;
}
