/**
 * Simple C wrapper for simdjson
 * Provides basic JSON parsing functionality through C interface
 */

#ifndef SIMDJSON_WRAPPER_H
#define SIMDJSON_WRAPPER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  const char* data;
  size_t len;
} simdjson_string;

typedef void* simdjson_parser_t;
typedef void* simdjson_document_t;
typedef void* simdjson_element_t;

/* Parser initialization and cleanup */
simdjson_parser_t simdjson_create_parser();
void simdjson_free_parser(simdjson_parser_t parser);

/* Parsing */
int simdjson_parse(simdjson_parser_t parser, const char* json, size_t len, simdjson_document_t* out_doc);
void simdjson_free_document(simdjson_document_t doc);

/* Document root access */
simdjson_element_t simdjson_document_root(simdjson_document_t doc);
void simdjson_free_element(simdjson_element_t elem);

/* Element access */
int simdjson_element_get_string(simdjson_element_t elem, simdjson_string* out_str);
int simdjson_element_get_int64(simdjson_element_t elem, int64_t* out_val);
int simdjson_element_get_uint64(simdjson_element_t elem, uint64_t* out_val);
int simdjson_element_get_double(simdjson_element_t elem, double* out_val);
int simdjson_element_get_bool(simdjson_element_t elem, int* out_val);

/* Object/Array access */
int simdjson_element_is_object(simdjson_element_t elem);
int simdjson_element_is_array(simdjson_element_t elem);
int simdjson_element_is_null(simdjson_element_t elem);

#ifdef __cplusplus
}
#endif

#endif /* SIMDJSON_WRAPPER_H */
