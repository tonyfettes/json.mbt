///|
test "numbers_edge_cases" {
  assert_true(@json.parse("-0") is @json.Json::Number("-0"))
  assert_true(@json.parse("0.0") is @json.Json::Number("0.0"))
  assert_true(@json.parse("-1.23") is @json.Json::Number("-1.23"))
  assert_true(@json.parse("1E10") is @json.Json::Number("1E10"))
  assert_true(@json.parse("1e-10") is @json.Json::Number("1e-10"))
}

///|
test "array_with_all_types" {
  assert_true(
    @json.parse("[null, true, false, 42, \"hello\", [], {}]")
    is @json.Json::Array(
      [
        @json.Json::Null,
        @json.Json::Bool(true),
        @json.Json::Bool(false),
        @json.Json::Number("42"),
        @json.Json::String("hello"),
        @json.Json::Array([]),
        @json.Json::Object({ .. }),
      ]
    ),
  )
}

///|
test "array_with_nested_objects_and_arrays" {
  assert_true(
    @json.parse("[{\"arr\": [1]}, [\"str\"], 123]")
    is @json.Json::Array(
      [
        @json.Json::Object(
          { "arr": @json.Json::Array([@json.Json::Number("1")]), .. }
        ),
        @json.Json::Array([@json.Json::String("str")]),
        @json.Json::Number("123"),
      ]
    ),
  )
}

///|
test "object_with_special_keys" {
  assert_true(
    @json.parse(
      "{\"key with spaces\": \"value1\", \"key_with_underscores\": \"value2\", \"key-with-dashes\": \"value3\"}",
    )
    is @json.Json::Object(
      {
        "key with spaces": @json.Json::String("value1"),
        "key_with_underscores": @json.Json::String("value2"),
        "key-with-dashes": @json.Json::String("value3"),
        ..
      }
    ),
  )
}

///|
test "empty_string_key" {
  assert_true(
    @json.parse("{\"\": \"empty key\"}")
    is @json.Json::Object({ "": @json.Json::String("empty key"), .. }),
  )
}

///|
test "complex_nested_structure" {
  let json_str : Bytes = "{\"users\": [{\"id\": 1, \"name\": \"Alice\", \"active\": true}, {\"id\": 2, \"name\": \"Bob\", \"active\": false}], \"count\": 2}"
  assert_true(
    @json.parse(json_str)
    is @json.Json::Object(
      {
        "users": @json.Json::Array(
          [
            @json.Json::Object(
              {
                "id": @json.Json::Number("1"),
                "name": @json.Json::String("Alice"),
                "active": @json.Json::Bool(true),
                ..
              }
            ),
            @json.Json::Object(
              {
                "id": @json.Json::Number("2"),
                "name": @json.Json::String("Bob"),
                "active": @json.Json::Bool(false),
                ..
              }
            ),
          ]
        ),
        "count": @json.Json::Number("2"),
        ..
      }
    ),
  )
}

///|
test "string_with_backslash" {
  assert_true(
    @json.parse("\"path\\\\to\\\\file\"")
    is @json.Json::String("path\\to\\file"),
  )
}

///|
test "string_with_forward_slash" {
  assert_true(
    @json.parse("\"http://example.com\"")
    is @json.Json::String("http://example.com"),
  )
}

///|
test "string_with_control_chars" {
  assert_true(
    @json.parse("\"line1\\nline2\\tindented\"")
    is @json.Json::String("line1\nline2\tindented"),
  )
}

///|
test "mixed_array_object_nesting" {
  assert_true(
    @json.parse("[{\"items\": [1, 2]}, {\"items\": [3, 4]}]")
    is @json.Json::Array(
      [
        @json.Json::Object(
          {
            "items": @json.Json::Array(
              [@json.Json::Number("1"), @json.Json::Number("2")]
            ),
            ..
          }
        ),
        @json.Json::Object(
          {
            "items": @json.Json::Array(
              [@json.Json::Number("3"), @json.Json::Number("4")]
            ),
            ..
          }
        ),
      ]
    ),
  )
}

///|
test "object_with_duplicate_keys" {
  // JSON spec allows duplicate keys, last one wins
  assert_true(
    @json.parse("{\"key\": \"first\", \"key\": \"second\"}")
    is @json.Json::Object({ "key": @json.Json::String("second"), .. }),
  )
}

///|
test "string_with_various_escapes" {
  assert_true(
    @json.parse("\"\\\"\\\\\\n\\r\\t\\b\\f\"")
    is @json.Json::String("\"\\\n\r\t\b\x0C"),
  )
}

///|
test "number_zero" {
  assert_true(@json.parse("0") is @json.Json::Number("0"))
}

///|
test "number_with_positive_exponent" {
  assert_true(@json.parse("1.5e+10") is @json.Json::Number("1.5e+10"))
}

///|
test "number_large_integer" {
  assert_true(@json.parse("123456789") is @json.Json::Number("123456789"))
}

///|
test "string_with_carriage_return" {
  assert_true(
    @json.parse("\"line1\\rline2\"") is @json.Json::String("line1\rline2"),
  )
}

///|
test "string_with_backspace" {
  assert_true(
    @json.parse("\"text\\bmore\"") is @json.Json::String("text\bmore"),
  )
}

///|
test "string_with_form_feed" {
  assert_true(
    @json.parse("\"page1\\fpage2\"") is @json.Json::String("page1\x0Cpage2"),
  )
}

///|
test "large_nested_object" {
  let json_bytes : Bytes = "{\"level1\": {\"level2\": {\"level3\": {\"level4\": {\"value\": \"nested\"}}}}}"
  assert_true(
    @json.parse(json_bytes)
    is @json.Json::Object(
      {
        "level1": @json.Json::Object(
          {
            "level2": @json.Json::Object(
              {
                "level3": @json.Json::Object(
                  {
                    "level4": @json.Json::Object(
                      { "value": @json.Json::String("nested"), .. }
                    ),
                    ..
                  }
                ),
                ..
              }
            ),
            ..
          }
        ),
        ..
      }
    ),
  )
}

///|
test "object" {
  assert_true(
    @json.parse("{\"a\":\"b\"}")
    is @json.Json::Object({ "a": @json.Json::String("b"), .. }),
  )
}

///|
test "null" {
  assert_true(@json.parse("null") is @json.Json::Null)
}

///|
test "boolean_true" {
  assert_true(@json.parse("true") is @json.Json::Bool(true))
}

///|
test "boolean_false" {
  assert_true(@json.parse("false") is @json.Json::Bool(false))
}

///|
test "number_integer" {
  assert_true(@json.parse("42") is @json.Json::Number("42"))
}

///|
test "number_negative" {
  assert_true(@json.parse("-123") is @json.Json::Number("-123"))
}

///|
test "number_float" {
  assert_true(@json.parse("3.14") is @json.Json::Number("3.14"))
}

///|
test "number_exponential" {
  assert_true(@json.parse("1.23e4") is @json.Json::Number("1.23e4"))
}

///|
test "number_exponential_negative" {
  assert_true(@json.parse("5e-3") is @json.Json::Number("5e-3"))
}

///|
test "string_simple" {
  assert_true(@json.parse("\"hello\"") is @json.Json::String("hello"))
}

///|
test "string_empty" {
  assert_true(@json.parse("\"\"") is @json.Json::String(""))
}

///|
test "string_with_escapes" {
  assert_true(
    @json.parse("\"hello\\nworld\"") is @json.Json::String("hello\nworld"),
  )
}

///|
test "string_with_quotes" {
  assert_true(
    @json.parse("\"Say \\\"hello\\\"\"") is @json.Json::String("Say \"hello\""),
  )
}

///|
test "string_with_unicode" {
  assert_true(
    @json.parse("\"\\u0048\\u0065\\u006c\\u006c\\u006f\"")
    is @json.Json::String("Hello"),
  )
}

///|
test "object_empty" {
  assert_true(@json.parse("{}") is @json.Json::Object({ .. }))
}

///|
test "object_single_property" {
  assert_true(
    @json.parse("{\"name\": \"John\"}")
    is @json.Json::Object({ "name": @json.Json::String("John"), .. }),
  )
}

///|
test "object_multiple_properties" {
  assert_true(
    @json.parse("{\"age\": 30, \"active\": true, \"name\": \"Alice\"}")
    is @json.Json::Object(
      {
        "age": @json.Json::Number("30"),
        "active": @json.Json::Bool(true),
        "name": @json.Json::String("Alice"),
        ..
      }
    ),
  )
}

///|
test "object_nested" {
  assert_true(
    @json.parse("{\"person\": {\"name\": \"Bob\", \"age\": 25}}")
    is @json.Json::Object(
      {
        "person": @json.Json::Object(
          {
            "name": @json.Json::String("Bob"),
            "age": @json.Json::Number("25"),
            ..
          }
        ),
        ..
      }
    ),
  )
}

///|
test "object_with_array" {
  assert_true(
    @json.parse("{\"numbers\": [1, 2, 3], \"name\": \"test\"}")
    is @json.Json::Object(
      {
        "numbers": @json.Json::Array(
          [
            @json.Json::Number("1"),
            @json.Json::Number("2"),
            @json.Json::Number("3"),
          ]
        ),
        "name": @json.Json::String("test"),
        ..
      }
    ),
  )
}

///|
test "whitespace_handling" {
  assert_true(
    @json.parse("  {  \"a\"  :  \"b\"  }  ")
    is @json.Json::Object({ "a": @json.Json::String("b"), .. }),
  )
}
