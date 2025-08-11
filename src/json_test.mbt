///|
test "numbers_edge_cases" {
  assert_true(@json.parse_json(b"-0") is @json.Json::Number("-0"))
  assert_true(@json.parse_json(b"0.0") is @json.Json::Number("0.0"))
  assert_true(@json.parse_json(b"-1.23") is @json.Json::Number("-1.23"))
  assert_true(@json.parse_json(b"1E10") is @json.Json::Number("1E10"))
  assert_true(@json.parse_json(b"1e-10") is @json.Json::Number("1e-10"))
}

///|
test "array_with_all_types" {
  assert_true(
    @json.parse_json(b"[null, true, false, 42, \"hello\", [], {}]")
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
    @json.parse_json(b"[{\"arr\": [1]}, [\"str\"], 123]")
    is @json.Json::Array(
      [
        @json.Json::Object(
          { "arr": @json.Json::Array([@json.Json::Number(_)]), .. }
        ),
        @json.Json::Array([@json.Json::String(_)]),
        @json.Json::Number(_),
      ]
    ),
  )
}

///|
test "object_with_special_keys" {
  assert_true(
    @json.parse_json(
      b"{\"key with spaces\": \"value1\", \"key_with_underscores\": \"value2\", \"key-with-dashes\": \"value3\"}",
    )
    is @json.Json::Object(
      {
        "key with spaces": @json.Json::String(_),
        "key_with_underscores": @json.Json::String(_),
        "key-with-dashes": @json.Json::String(_),
        ..
      }
    ),
  )
}

///|
test "empty_string_key" {
  assert_true(
    @json.parse_json(b"{\"\": \"empty key\"}")
    is @json.Json::Object({ "": @json.Json::String(_), .. }),
  )
}

///|
test "complex_nested_structure" {
  let json_str = b"{\"users\": [{\"id\": 1, \"name\": \"Alice\", \"active\": true}, {\"id\": 2, \"name\": \"Bob\", \"active\": false}], \"count\": 2}"
  assert_true(
    @json.parse_json(json_str)
    is @json.Json::Object(
      {
        "users": @json.Json::Array(
          [
            @json.Json::Object(
              {
                "id": @json.Json::Number(_),
                "name": @json.Json::String(_),
                "active": @json.Json::Bool(true),
                ..
              }
            ),
            @json.Json::Object(
              {
                "id": @json.Json::Number(_),
                "name": @json.Json::String(_),
                "active": @json.Json::Bool(false),
                ..
              }
            ),
          ]
        ),
        "count": @json.Json::Number(_),
        ..
      }
    ),
  )
}

///|
test "string_with_backslash" {
  assert_true(
    @json.parse_json(b"\"path\\\\to\\\\file\"")
    is @json.Json::String(b"path\\\\to\\\\file"),
  )
}

///|
test "string_with_forward_slash" {
  assert_true(
    @json.parse_json(b"\"http:\\/\\/example.com\"")
    is @json.Json::String(b"http:\\/\\/example.com"),
  )
}

///|
test "string_with_control_chars" {
  assert_true(
    @json.parse_json(b"\"line1\\nline2\\tindented\"")
    is @json.Json::String(b"line1\\nline2\\tindented"),
  )
}

///|
test "mixed_array_object_nesting" {
  assert_true(
    @json.parse_json(b"[{\"items\": [1, 2]}, {\"items\": [3, 4]}]")
    is @json.Json::Array(
      [
        @json.Json::Object(
          {
            "items": @json.Json::Array(
              [@json.Json::Number(_), @json.Json::Number(_)]
            ),
            ..
          }
        ),
        @json.Json::Object(
          {
            "items": @json.Json::Array(
              [@json.Json::Number(_), @json.Json::Number(_)]
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
    @json.parse_json(b"{\"key\": \"first\", \"key\": \"second\"}")
    is @json.Json::Object({ "key": @json.Json::String(_), .. }),
  )
}

///|
test "string_with_various_escapes" {
  assert_true(
    @json.parse_json(b"\"\\\"\\\\\\n\\r\\t\\b\\f\"") is @json.Json::String(_),
  )
}

///|
test "number_zero" {
  assert_true(@json.parse_json(b"0") is @json.Json::Number(_))
}

///|
test "number_with_positive_exponent" {
  assert_true(@json.parse_json(b"1.5e+10") is @json.Json::Number(_))
}

///|
test "number_large_integer" {
  assert_true(@json.parse_json(b"123456789") is @json.Json::Number(_))
}

///|
test "string_with_backslash" {
  assert_true(
    @json.parse_json(b"\"path\\\\to\\\\file\"") is @json.Json::String(_),
  )
}

///|
test "string_with_forward_slash" {
  assert_true(
    @json.parse_json(b"\"http:\\/\\/example.com\"") is @json.Json::String(_),
  )
}

///|
test "string_with_control_chars" {
  assert_true(
    @json.parse_json(b"\"line1\\nline2\\tindented\"") is @json.Json::String(_),
  )
}

///|
test "string_with_carriage_return" {
  assert_true(
    @json.parse_json(b"\"line1\\rline2\"")
    is @json.Json::String(b"line1\\rline2"),
  )
}

///|
test "string_with_backspace" {
  assert_true(
    @json.parse_json(b"\"text\\bmore\"") is @json.Json::String(b"text\\bmore"),
  )
}

///|
test "string_with_form_feed" {
  assert_true(
    @json.parse_json(b"\"page1\\fpage2\"")
    is @json.Json::String(b"page1\\fpage2"),
  )
}

///|
test "large_nested_object" {
  let json_str = b"{\"level1\": {\"level2\": {\"level3\": {\"level4\": {\"value\": \"nested\"}}}}}"
  assert_true(
    @json.parse_json(json_str)
    is @json.Json::Object(
      {
        "level1": @json.Json::Object(
          {
            "level2": @json.Json::Object(
              {
                "level3": @json.Json::Object(
                  {
                    "level4": @json.Json::Object(
                      { "value": @json.Json::String(_), .. }
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
    @json.parse_json(b"{\"a\":\"b\"}")
    is @json.Json::Object({ "a": @json.Json::String(_), .. }),
  )
}

///|
test "null" {
  assert_true(@json.parse_json(b"null") is @json.Json::Null)
}

///|
test "boolean_true" {
  assert_true(@json.parse_json(b"true") is @json.Json::Bool(true))
}

///|
test "boolean_false" {
  assert_true(@json.parse_json(b"false") is @json.Json::Bool(false))
}

///|
test "number_integer" {
  assert_true(@json.parse_json(b"42") is @json.Json::Number(_))
}

///|
test "number_negative" {
  assert_true(@json.parse_json(b"-123") is @json.Json::Number(_))
}

///|
test "number_float" {
  assert_true(@json.parse_json(b"3.14") is @json.Json::Number(_))
}

///|
test "number_exponential" {
  assert_true(@json.parse_json(b"1.23e4") is @json.Json::Number(_))
}

///|
test "number_exponential_negative" {
  assert_true(@json.parse_json(b"5e-3") is @json.Json::Number(_))
}

///|
test "string_simple" {
  assert_true(@json.parse_json(b"\"hello\"") is @json.Json::String(_))
}

///|
test "string_empty" {
  assert_true(@json.parse_json(b"\"\"") is @json.Json::String(_))
}

///|
test "string_with_escapes" {
  assert_true(@json.parse_json(b"\"hello\\nworld\"") is @json.Json::String(_))
}

///|
test "string_with_quotes" {
  assert_true(
    @json.parse_json(b"\"Say \\\"hello\\\"\"") is @json.Json::String(_),
  )
}

///|
test "string_with_unicode" {
  assert_true(
    @json.parse_json(b"\"\\u0048\\u0065\\u006c\\u006c\\u006f\"")
    is @json.Json::String(_),
  )
}

///|
test "object_empty" {
  assert_true(@json.parse_json(b"{}") is @json.Json::Object({ .. }))
}

///|
test "object_single_property" {
  assert_true(
    @json.parse_json(b"{\"name\": \"John\"}")
    is @json.Json::Object({ "name": @json.Json::String(_), .. }),
  )
}

///|
test "object_multiple_properties" {
  assert_true(
    @json.parse_json(b"{\"age\": 30, \"active\": true, \"name\": \"Alice\"}")
    is @json.Json::Object(
      {
        "age": @json.Json::Number(_),
        "active": @json.Json::Bool(true),
        "name": @json.Json::String(_),
        ..
      }
    ),
  )
}

///|
test "object_nested" {
  assert_true(
    @json.parse_json(b"{\"person\": {\"name\": \"Bob\", \"age\": 25}}")
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
    @json.parse_json(b"{\"numbers\": [1, 2, 3], \"name\": \"test\"}")
    is @json.Json::Object(
      {
        "numbers": @json.Json::Array(
          [@json.Json::Number(_), @json.Json::Number(_), @json.Json::Number(_)]
        ),
        "name": @json.Json::String(_),
        ..
      }
    ),
  )
}

///|
test "whitespace_handling" {
  assert_true(
    @json.parse_json(b"  {  \"a\"  :  \"b\"  }  ")
    is @json.Json::Object({ "a": @json.Json::String(b"b"), .. }),
  )
}

///|
test "complex_nested_structure" {
  let json_bytes = b"{\"users\": [{\"id\": 1, \"name\": \"Alice\", \"active\": true}, {\"id\": 2, \"name\": \"Bob\", \"active\": false}], \"count\": 2}"
  assert_true(
    @json.parse_json(json_bytes)
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
        ..
      }
    ),
  )
}
