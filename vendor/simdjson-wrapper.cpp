/**
 * C wrapper implementation for simdjson
 * Wraps the C++ API with a C interface for use from Nim
 */

#include "simdjson-wrapper.h"
#include "simdjson/simdjson.h"
#include <cstring>
#include <new>

// Use the simdjson namespace
using namespace simdjson;

// Opaque type implementations
struct SimdJsonParserImpl {
    simdjson::ondemand::parser parser;
};

struct SimdJsonDocumentImpl {
    simdjson::ondemand::document_stream stream;
    const char* json_data;
    size_t json_len;
};

struct SimdJsonElementImpl {
    simdjson::ondemand::value value;
};

// Parser creation and cleanup
extern "C" {

simdjson_parser_t simdjson_create_parser() {
    try {
        auto* impl = new SimdJsonParserImpl();
        return static_cast<void*>(impl);
    } catch (...) {
        return nullptr;
    }
}

void simdjson_free_parser(simdjson_parser_t parser) {
    if (parser) {
        delete static_cast<SimdJsonParserImpl*>(parser);
    }
}

// Parsing
int simdjson_parse(simdjson_parser_t parser_ptr, const char* json, size_t len, simdjson_document_t* out_doc) {
    if (!parser_ptr || !json || !out_doc) {
        return -1;  // Error code for invalid input
    }

    try {
        auto* parser = static_cast<SimdJsonParserImpl*>(parser_ptr);

        // Try to parse using on-demand API
        auto doc_result = parser->parser.parse_into_document(json, len);

        if (doc_result.error()) {
            return static_cast<int>(doc_result.error());
        }

        // Allocate and store the document
        auto* doc_impl = new SimdJsonDocumentImpl();
        doc_impl->json_data = json;
        doc_impl->json_len = len;

        *out_doc = static_cast<simdjson_document_t>(doc_impl);
        return 0;  // Success
    } catch (...) {
        return -1;  // Generic error
    }
}

void simdjson_free_document(simdjson_document_t doc) {
    if (doc) {
        delete static_cast<SimdJsonDocumentImpl*>(doc);
    }
}

// Document root access
simdjson_element_t simdjson_document_root(simdjson_document_t doc_ptr) {
    if (!doc_ptr) {
        return nullptr;
    }

    try {
        auto* doc = static_cast<SimdJsonDocumentImpl*>(doc_ptr);

        // Parse the document to get the root element
        ondemand::parser parser;
        auto doc_result = parser.parse_into_document(doc->json_data, doc->json_len);

        if (doc_result.error()) {
            return nullptr;
        }

        auto* elem_impl = new SimdJsonElementImpl();
        elem_impl->value = doc_result.value_unsafe();

        return static_cast<simdjson_element_t>(elem_impl);
    } catch (...) {
        return nullptr;
    }
}

void simdjson_free_element(simdjson_element_t elem) {
    if (elem) {
        delete static_cast<SimdJsonElementImpl*>(elem);
    }
}

// Element value extraction
int simdjson_element_get_string(simdjson_element_t elem_ptr, simdjson_string* out_str) {
    if (!elem_ptr || !out_str) {
        return -1;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto str_result = elem->value.get_string();

        if (str_result.error()) {
            return static_cast<int>(str_result.error());
        }

        std::string_view sv = str_result.value_unsafe();
        out_str->data = sv.data();
        out_str->len = sv.length();
        return 0;
    } catch (...) {
        return -1;
    }
}

int simdjson_element_get_int64(simdjson_element_t elem_ptr, int64_t* out_val) {
    if (!elem_ptr || !out_val) {
        return -1;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto int_result = elem->value.get_int64();

        if (int_result.error()) {
            return static_cast<int>(int_result.error());
        }

        *out_val = int_result.value_unsafe();
        return 0;
    } catch (...) {
        return -1;
    }
}

int simdjson_element_get_uint64(simdjson_element_t elem_ptr, uint64_t* out_val) {
    if (!elem_ptr || !out_val) {
        return -1;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto uint_result = elem->value.get_uint64();

        if (uint_result.error()) {
            return static_cast<int>(uint_result.error());
        }

        *out_val = uint_result.value_unsafe();
        return 0;
    } catch (...) {
        return -1;
    }
}

int simdjson_element_get_double(simdjson_element_t elem_ptr, double* out_val) {
    if (!elem_ptr || !out_val) {
        return -1;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto double_result = elem->value.get_double();

        if (double_result.error()) {
            return static_cast<int>(double_result.error());
        }

        *out_val = double_result.value_unsafe();
        return 0;
    } catch (...) {
        return -1;
    }
}

int simdjson_element_get_bool(simdjson_element_t elem_ptr, int* out_val) {
    if (!elem_ptr || !out_val) {
        return -1;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto bool_result = elem->value.get_bool();

        if (bool_result.error()) {
            return static_cast<int>(bool_result.error());
        }

        *out_val = bool_result.value_unsafe() ? 1 : 0;
        return 0;
    } catch (...) {
        return -1;
    }
}

// Type checking functions
int simdjson_element_is_object(simdjson_element_t elem_ptr) {
    if (!elem_ptr) {
        return 0;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto type_result = elem->value.type();

        if (type_result.error()) {
            return 0;
        }

        return type_result.value_unsafe() == ondemand::json_type::object ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

int simdjson_element_is_array(simdjson_element_t elem_ptr) {
    if (!elem_ptr) {
        return 0;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto type_result = elem->value.type();

        if (type_result.error()) {
            return 0;
        }

        return type_result.value_unsafe() == ondemand::json_type::array ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

int simdjson_element_is_null(simdjson_element_t elem_ptr) {
    if (!elem_ptr) {
        return 0;
    }

    try {
        auto* elem = static_cast<SimdJsonElementImpl*>(elem_ptr);
        auto type_result = elem->value.type();

        if (type_result.error()) {
            return 0;
        }

        return type_result.value_unsafe() == ondemand::json_type::null ? 1 : 0;
    } catch (...) {
        return 0;
    }
}

}  // extern "C"
