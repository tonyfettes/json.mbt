///| JSON Parser Implementation

///|
pub suberror ParseError {
  ParseError(String, Int)
}

///| Skip whitespace characters and return the next non-whitespace position
fn skip_whitespace(input : @bytes.View, pos : Int) -> Int {
  let len = input.length()
  let mut i = pos
  while i < len {
    match input[i] {
      ' ' | '\t' | '\n' | '\r' => i = i + 1
      _ => break
    }
  }
  i
}

///| Parse a JSON value from bytes starting at the given position
fn parse_value(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  let pos = skip_whitespace(input, pos)
  if pos >= input.length() {
    raise ParseError("Unexpected end of input", pos)
  }
  match input[pos] {
    'n' => parse_null(input, pos)
    't' | 'f' => parse_bool(input, pos)
    '"' => parse_string(input, pos)
    '[' => parse_array(input, pos)
    '{' => parse_object(input, pos)
    '-' | '0'..='9' => parse_number(input, pos)
    _ => raise ParseError("Unexpected character", pos)
  }
}

///| Parse null literal
fn parse_null(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  if pos + 4 <= input.length() &&
    input[pos] == 'n' &&
    input[pos + 1] == 'u' &&
    input[pos + 2] == 'l' &&
    input[pos + 3] == 'l' {
    (Null, pos + 4)
  } else {
    raise ParseError("Invalid null literal", pos)
  }
}

///| Parse boolean literal
fn parse_bool(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  if pos + 4 <= input.length() &&
    input[pos] == 't' &&
    input[pos + 1] == 'r' &&
    input[pos + 2] == 'u' &&
    input[pos + 3] == 'e' {
    (Bool(true), pos + 4)
  } else if pos + 5 <= input.length() &&
    input[pos] == 'f' &&
    input[pos + 1] == 'a' &&
    input[pos + 2] == 'l' &&
    input[pos + 3] == 's' &&
    input[pos + 4] == 'e' {
    (Bool(false), pos + 5)
  } else {
    raise ParseError("Invalid boolean literal", pos)
  }
}

///| Parse number literal
fn parse_number(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  let start = pos
  let len = input.length()
  let mut i = pos

  // Optional minus sign
  if i < len && input[i] == '-' {
    i = i + 1
  }
  if i >= len {
    raise ParseError("Invalid number: missing digits", pos)
  }

  // Integer part
  if input[i] == '0' {
    i = i + 1
  } else if input[i] >= '1' && input[i] <= '9' {
    i = i + 1
    while i < len && input[i] >= '0' && input[i] <= '9' {
      i = i + 1
    }
  } else {
    raise ParseError("Invalid number: invalid digit", pos)
  }

  // Optional fractional part
  if i < len && input[i] == '.' {
    i = i + 1
    if i >= len || input[i] < '0' || input[i] > '9' {
      raise ParseError("Invalid number: missing fractional digits", pos)
    }
    while i < len && input[i] >= '0' && input[i] <= '9' {
      i = i + 1
    }
  }

  // Optional exponent part
  if i < len && (input[i] == 'e' || input[i] == 'E') {
    i = i + 1
    if i < len && (input[i] == '+' || input[i] == '-') {
      i = i + 1
    }
    if i >= len || input[i] < '0' || input[i] > '9' {
      raise ParseError("Invalid number: missing exponent digits", pos)
    }
    while i < len && input[i] >= '0' && input[i] <= '9' {
      i = i + 1
    }
  }
  (Number(input[start:i]), i)
}

///| Parse string literal
fn parse_string(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  if pos >= input.length() || input[pos] != '"' {
    raise ParseError("Expected opening quote", pos)
  }
  let start = pos + 1
  let len = input.length()
  let mut i = start
  while i < len {
    match input[i] {
      '"' => return (String(input[start:i]), i + 1)
      '\\' => {
        i = i + 1
        if i >= len {
          raise ParseError("Unexpected end of string after escape", i)
        }
        match input[i] {
          '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' => i = i + 1
          'u' => {
            i = i + 1
            if i + 4 > len {
              raise ParseError("Invalid unicode escape sequence", i)
            }
            // Validate 4 hex digits
            for j = 0; j < 4; j = j + 1 {
              let c = input[i + j]
              if not(
                  (c >= '0' && c <= '9') ||
                  (c >= 'a' && c <= 'f') ||
                  (c >= 'A' && c <= 'F'),
                ) {
                raise ParseError("Invalid unicode escape sequence", i + j)
              }
            }
            i = i + 4
          }
          _ => raise ParseError("Invalid escape sequence", i)
        }
      }
      c => {
        if c < 0x20 {
          raise ParseError("Unescaped control character in string", i)
        }
        i = i + 1
      }
    }
  }
  raise ParseError("Unterminated string", pos)
}

///| Parse array literal
fn parse_array(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  if pos >= input.length() || input[pos] != '[' {
    raise ParseError("Expected opening bracket", pos)
  }
  let mut i = skip_whitespace(input, pos + 1)
  let elements : Array[Json] = []

  // Empty array
  if i < input.length() && input[i] == ']' {
    return (Array(elements), i + 1)
  }

  // Parse elements
  while true {
    let (value, next_pos) = parse_value(input, i)
    elements.push(value)
    i = skip_whitespace(input, next_pos)
    if i >= input.length() {
      raise ParseError("Unterminated array", i)
    }
    match input[i] {
      ',' => i = skip_whitespace(input, i + 1)
      ']' => return (Array(elements), i + 1)
      _ => raise ParseError("Expected comma or closing bracket", i)
    }
  } else {
    raise ParseError("Unexpected error in array parsing", pos)
  }
}

///| Parse object literal
fn parse_object(input : @bytes.View, pos : Int) -> (Json, Int) raise ParseError {
  if pos >= input.length() || input[pos] != '{' {
    raise ParseError("Expected opening brace", pos)
  }
  let mut i = skip_whitespace(input, pos + 1)
  let obj : Map[Bytes, Json] = {}

  // Empty object
  if i < input.length() && input[i] == '}' {
    return (Object(obj), i + 1)
  }

  // Parse key-value pairs
  while true {
    // Parse key (must be string)
    let (key_json, next_pos) = parse_string(input, i)
    match key_json {
      String(key) => {
        i = skip_whitespace(input, next_pos)

        // Expect colon
        if i >= input.length() || input[i] != ':' {
          raise ParseError("Expected colon after object key", i)
        }
        i = skip_whitespace(input, i + 1)

        // Parse value
        let (value, next_pos) = parse_value(input, i)
        obj[[..key]] = value
        i = skip_whitespace(input, next_pos)
        if i >= input.length() {
          raise ParseError("Unterminated object", i)
        }
        match input[i] {
          ',' => i = skip_whitespace(input, i + 1)
          '}' => return (Object(obj), i + 1)
          _ => raise ParseError("Expected comma or closing brace", i)
        }
      }
      _ => raise ParseError("Expected string key in object", i)
    }
  } else {
    raise ParseError("Unexpected error in object parsing", pos)
  }
}

///| Main parsing function that takes a @bytes.View and returns Json
pub fn parse_json(input : @bytes.View) -> Json raise ParseError {
  let (value, final_pos) = parse_value(input, 0)
  let final_pos = skip_whitespace(input, final_pos)
  if final_pos < input.length() {
    raise ParseError("Unexpected content after JSON value", final_pos)
  } else {
    value
  }
}
