#include <stdint.h>
#include <stddef.h>
#include <string.h>

const size_t MEMSIZE = 0x10000;
static int i = 0;

size_t svc16_expansion_api_version() { return 1; }

void svc16_expansion_on_init() {
}

void svc16_expansion_on_deinit() {
}

void svc16_expansion_triggered(uint16_t* buffer) {
  memset(buffer, 0, MEMSIZE * 2);
  buffer[0] = 'H';
  buffer[1] = 'e';
  buffer[2] = 'l';
  buffer[3] = 'l';
  buffer[4] = 'o';

}
