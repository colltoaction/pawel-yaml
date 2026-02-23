#include <stdio.h>
#include "common.h"
#include "stream.tab.h"
#include "event.tab.h"

int stream_yy_parse(void *scanner) { return 0; }
int node_yy_parse(void *scanner) { return 0; }
int event_yy_parse(void) { return 0; }
int ct_yy_parse(void) { return 0; }
int yaml_yy_parse(void *scanner) { return 0; }

int stream_yy_drive_parse(void *scanner) { return stream_yy_parse(scanner); }
int node_yy_drive_parse(void *scanner) { return node_yy_parse(scanner); }

void ct_yy_error(const char *s) { (void)s; }
void yaml_yy_error(void *yylloc, void *scanner, const char *s) { (void)yylloc; (void)scanner; (void)s; }
