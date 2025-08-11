///| JSON Parser Implementation

///|
pub suberror ParseError {
  ParseError(String, Int)
}

///|
priv struct Parser {
  data : Bytes
  len : Int
  mut pos : Int
}

///|
fn Parser::new(input : @bytes.View) -> Parser {
  Parser::{ data: input.data(), pos: input.start_offset(), len: input.length() }
}

///|
fn Parser::view(self : Parser) -> @bytes.View {
  self.data[self.pos:]
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
  while self.pos < self.len {
    match self.data[self.pos] {
      ' ' | '\t' | '\n' | '\r' => self.pos = self.pos + 1
      _ => break
    }
  }
}

fn Parser::peek(self : Parser) -> Byte? {
  if self.pos >= self.len {
    None
  } else {
    Some(self.data[self.pos])
  }
}

///|
fn Parser::parse_value(self : Parser) -> Json raise ParseError {
  self.skip_whitespace()
  if self.pos >= self.len {
    raise ParseError("Unexpected end of input", self.pos)
  }
  match self.data[self.pos] {
    'n' => self.parse_null()
    't' | 'f' => self.parse_bool()
    '"' => self.parse_string()
    '[' => self.parse_array()
    '{' => self.parse_object()
    '-' | '0'..='9' => self.parse_number()
    _ => raise ParseError("Unexpected character", self.pos)
  }
}

///|
fn Parser::parse_null(self : Parser) -> Json raise ParseError {
  if self.pos + 4 <= self.len &&
    self.data[self.pos] == 'n' &&
    self.data[self.pos + 1] == 'u' &&
    self.data[self.pos + 2] == 'l' &&
    self.data[self.pos + 3] == 'l' {
    self.pos = self.pos + 4
    Null
  } else {
    raise ParseError("Invalid null literal", self.pos)
  }
}

///|
fn Parser::parse_bool(self : Parser) -> Json raise ParseError {
  if self.pos + 4 <= self.len &&
    self.data[self.pos] == 't' &&
    self.data[self.pos + 1] == 'r' &&
    self.data[self.pos + 2] == 'u' &&
    self.data[self.pos + 3] == 'e' {
    self.pos = self.pos + 4
    Bool(true)
  } else if self.pos + 5 <= self.len &&
    self.data[self.pos] == 'f' &&
    self.data[self.pos + 1] == 'a' &&
    self.data[self.pos + 2] == 'l' &&
    self.data[self.pos + 3] == 's' &&
    self.data[self.pos + 4] == 'e' {
    self.pos = self.pos + 5
    Bool(false)
  } else {
    raise ParseError("Invalid boolean literal", self.pos)
  }
}

///|
fn Parser::parse_number(self : Parser) -> Json raise ParseError {
  let start = self.pos

  // Optional minus sign
  if self.pos < self.len && self.data[self.pos] == '-' {
    self.pos = self.pos + 1
  }
  if self.pos >= self.len {
    raise ParseError("Invalid number: missing digits", start)
  }

  // Integer part
  if self.data[self.pos] == '0' {
    self.pos = self.pos + 1
  } else if self.data[self.pos] >= '1' && self.data[self.pos] <= '9' {
    self.pos = self.pos + 1
    while self.pos < self.len &&
          self.data[self.pos] >= '0' &&
          self.data[self.pos] <= '9' {
      self.pos = self.pos + 1
    }
  } else {
    raise ParseError("Invalid number: invalid digit", start)
  }

  // Optional fractional part
  if self.pos < self.len && self.data[self.pos] == '.' {
    self.pos = self.pos + 1
    if self.pos >= self.len ||
      self.data[self.pos] < '0' ||
      self.data[self.pos] > '9' {
      raise ParseError("Invalid number: missing fractional digits", start)
    }
    while self.pos < self.len &&
          self.data[self.pos] >= '0' &&
          self.data[self.pos] <= '9' {
      self.pos = self.pos + 1
    }
  }

  // Optional exponent part
  if self.pos < self.len &&
    (self.data[self.pos] == 'e' || self.data[self.pos] == 'E') {
    self.pos = self.pos + 1
    if self.pos < self.len &&
      (self.data[self.pos] == '+' || self.data[self.pos] == '-') {
      self.pos = self.pos + 1
    }
    if self.pos >= self.len ||
      self.data[self.pos] < '0' ||
      self.data[self.pos] > '9' {
      raise ParseError("Invalid number: missing exponent digits", start)
    }
    while self.pos < self.len &&
          self.data[self.pos] >= '0' &&
          self.data[self.pos] <= '9' {
      self.pos = self.pos + 1
    }
  }
  Number(self.data[start:self.pos])
}

///|
fn Parser::parse_string(self : Parser) -> Json raise ParseError {
  if self.pos >= self.len || self.data[self.pos] != '"' {
    raise ParseError("Expected opening quote", self.pos)
  }
  let start = self.pos + 1
  self.pos = self.pos + 1
  while self.pos < self.len {
    match self.data[self.pos] {
      '"' => {
        let content = self.data[start:self.pos]
        self.pos = self.pos + 1
        return String(content)
      }
      '\\' => {
        self.pos = self.pos + 1
        if self.pos >= self.len {
          raise ParseError("Unexpected end of string after escape", self.pos)
        }
        match self.data[self.pos] {
          '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' =>
            self.pos = self.pos + 1
          'u' => {
            self.pos = self.pos + 1
            if self.pos + 4 > self.len {
              raise ParseError("Invalid unicode escape sequence", self.pos)
            }
            // Validate 4 hex digits
            for j = 0; j < 4; j = j + 1 {
              let c = self.data[self.pos + j]
              if not(
                  (c >= '0' && c <= '9') ||
                  (c >= 'a' && c <= 'f') ||
                  (c >= 'A' && c <= 'F'),
                ) {
                raise ParseError(
                  "Invalid unicode escape sequence",
                  self.pos + j,
                )
              }
            }
            self.pos = self.pos + 4
          }
          _ => raise ParseError("Invalid escape sequence", self.pos)
        }
      }
      c => {
        if c < 0x20 {
          raise ParseError("Unescaped control character in string", self.pos)
        }
        self.pos = self.pos + 1
      }
    }
  }
  raise ParseError("Unterminated string", start - 1)
}

///|
fn Parser::parse_array(self : Parser) -> Json raise ParseError {
  if self.pos >= self.len || self.data[self.pos] != '[' {
    raise ParseError("Expected opening bracket", self.pos)
  }
  self.pos = self.pos + 1
  self.skip_whitespace()
  let elements : Array[Json] = []

  // Empty array
  if self.pos < self.len && self.data[self.pos] == ']' {
    self.pos = self.pos + 1
    return Array(elements)
  }

  // Parse elements
  while true {
    let value = self.parse_value()
    elements.push(value)
    self.skip_whitespace()
    if self.pos >= self.len {
      raise ParseError("Unterminated array", self.pos)
    }
    match self.data[self.pos] {
      ',' => {
        self.pos = self.pos + 1
        self.skip_whitespace()
      }
      ']' => {
        self.pos = self.pos + 1
        return Array(elements)
      }
      _ => raise ParseError("Expected comma or closing bracket", self.pos)
    }
  } else {
    raise ParseError("Unexpected error in array parsing", self.pos)
  }
}

///|
fn Parser::parse_object(self : Parser) -> Json raise ParseError {
  if self.pos >= self.len || self.data[self.pos] != '{' {
    raise ParseError("Expected opening brace", self.pos)
  }
  self.pos = self.pos + 1
  self.skip_whitespace()
  let obj : Map[Bytes, Json] = {}

  // Empty object
  if self.pos < self.len && self.data[self.pos] == '}' {
    self.pos = self.pos + 1
    return Object(obj)
  }

  // Parse key-value pairs
  while true {
    // Parse key (must be string)
    let key_json = self.parse_string()
    match key_json {
      String(key) => {
        self.skip_whitespace()

        // Expect colon
        if self.pos >= self.len || self.data[self.pos] != ':' {
          raise ParseError("Expected colon after object key", self.pos)
        }
        self.pos = self.pos + 1
        self.skip_whitespace()

        // Parse value
        let value = self.parse_value()
        obj[[..key]] = value
        self.skip_whitespace()
        if self.pos >= self.len {
          raise ParseError("Unterminated object", self.pos)
        }
        match self.data[self.pos] {
          ',' => {
            self.pos = self.pos + 1
            self.skip_whitespace()
          }
          '}' => {
            self.pos = self.pos + 1
            return Object(obj)
          }
          _ => raise ParseError("Expected comma or closing brace", self.pos)
        }
      }
      _ => raise ParseError("Expected string key in object", self.pos)
    }
  } else {
    raise ParseError("Unexpected error in object parsing", self.pos)
  }
}

///| Main parsing function that takes a @bytes.View and returns Json
pub fn parse_json(input : @bytes.View) -> Json raise ParseError {
  let parser = Parser::new(input)
  let value = parser.parse_value()
  parser.skip_whitespace()
  if parser.pos < parser.len {
    raise ParseError("Unexpected content after JSON value", parser.pos)
  } else {
    value
  }
}
