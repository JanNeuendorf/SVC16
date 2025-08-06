package main

import "C"
import "unsafe"

func main() {}

//export svc16_expansion_api_version
func svc16_expansion_api_version() C.size_t {
	return 1;
}

//export svc16_expansion_on_init
func svc16_expansion_on_init() {}
//export svc16_expansion_on_deinit
func svc16_expansion_on_deinit() {}

//export svc16_expansion_triggered
func svc16_expansion_triggered(raw_buffer *C.size_t) {
	var buffer = (*[0x10000]C.size_t)(unsafe.Pointer(raw_buffer))[:0x10000:0x10000];
	buffer[0] = 'H';
	buffer[1] = 'e';
	buffer[2] = 'l';
	buffer[3] = 'l';
	buffer[4] = 'o';
}
