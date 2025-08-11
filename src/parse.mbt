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
fn Parser::peek(self : Parser) -> Byte? {
  if self.pos >= self.len {
    None
  } else {
    Some(self.data[self.pos])
  }
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
  let view = loop self.view() {
    [' ' | '\t' | '\n' | '\r', .. view] => continue view
    [.. view] => view
  }
  self.pos = view.start_offset()
}

///|
fn Parser::parse_value(self : Parser) -> Json raise ParseError {
  self.skip_whitespace()
  if self.pos >= self.len {
    raise ParseError("Unexpected end of input", self.pos)
  }
  match self.peek() {
    Some('n') => self.parse_null()
    Some('t' | 'f') => self.parse_bool()
    Some('"') => self.parse_string()
    Some('[') => self.parse_array()
    Some('{') => self.parse_object()
    Some('-' | '0'..='9') => self.parse_number()
    Some(_) => raise ParseError("Unexpected character", self.pos)
    None => raise ParseError("Unexpected end of input", self.pos)
  }
}

///|
fn Parser::parse_null(self : Parser) -> Json raise ParseError {
  match self.view() {
    [.. "null", .. view] => {
      self.pos = view.start_offset()
      Null
    }
    [..] => raise ParseError("Invalid null literal", self.pos)
  }
}

///|
fn Parser::parse_bool(self : Parser) -> Json raise ParseError {
  match self.view() {
    [.. "true", .. view] => {
      self.pos = view.start_offset()
      Bool(true)
    }
    [.. "false", .. view] => {
      self.pos = view.start_offset()
      Bool(false)
    }
    [..] => raise ParseError("Invalid boolean literal", self.pos)
  }
}

///|
fn Parser::parse_number(self : Parser) -> Json raise ParseError {
  let start = self.pos

  // Optional minus sign
  if self.peek() == Some('-') {
    self.pos = self.pos + 1
  }
  if self.pos >= self.len {
    raise ParseError("Invalid number: missing digits", start)
  }

  // Integer part
  match self.peek() {
    Some('0') => self.pos = self.pos + 1
    Some('1'..='9') => {
      self.pos = self.pos + 1
      while self.pos < self.len {
        match self.peek() {
          Some('0'..='9') => self.pos = self.pos + 1
          _ => break
        }
      }
    }
    _ => raise ParseError("Invalid number: invalid digit", start)
  }

  // Optional fractional part
  if self.peek() == Some('.') {
    self.pos = self.pos + 1
    match self.peek() {
      Some('0'..='9') => {
        self.pos = self.pos + 1
        while self.pos < self.len {
          match self.peek() {
            Some('0'..='9') => self.pos = self.pos + 1
            _ => break
          }
        }
      }
      _ => raise ParseError("Invalid number: missing fractional digits", start)
    }
  }

  // Optional exponent part
  match self.peek() {
    Some('e' | 'E') => {
      self.pos = self.pos + 1
      if self.peek() == Some('+') || self.peek() == Some('-') {
        self.pos = self.pos + 1
      }
      match self.peek() {
        Some('0'..='9') => {
          self.pos = self.pos + 1
          while self.pos < self.len {
            match self.peek() {
              Some('0'..='9') => self.pos = self.pos + 1
              _ => break
            }
          }
        }
        _ => raise ParseError("Invalid number: missing exponent digits", start)
      }
    }
    _ => ()
  }
  Number(self.data[start:self.pos])
}

///|
fn Parser::parse_string(self : Parser) -> Json raise ParseError {
  if self.peek() != Some('"') {
    raise ParseError("Expected opening quote", self.pos)
  }
  self.pos = self.pos + 1 // Skip opening quote
  let buffer = @buffer.new()
  let final_view = loop self.view() {
    // Handle closing quote
    ['"', .. view] => break view
    [
      '\\',
      // Handle escaped characters using array pattern matching
      '"',
      .. view,
    ] => {
      buffer.write_byte(b'"')
      continue view
    }
    ['\\', '\\', .. view] => {
      buffer.write_byte(b'\\')
      continue view
    }
    ['\\', '/', .. view] => {
      buffer.write_byte(b'/')
      continue view
    }
    ['\\', 'b', .. view] => {
      buffer.write_byte(b'\b')
      continue view
    }
    ['\\', 'f', .. view] => {
      buffer.write_byte(b'\x0C') // Form feed
      continue view
    }
    ['\\', 'n', .. view] => {
      buffer.write_byte(b'\n')
      continue view
    }
    ['\\', 'r', .. view] => {
      buffer.write_byte(b'\r')
      continue view
    }
    ['\\', 't', .. view] => {
      buffer.write_byte(b'\t')
      continue view
    }
    ['\\', 'u', h1, h2, h3, h4, .. view] => {
      // Parse 4 hex digits for unicode escape
      let mut code_point = 0
      let hex_chars = [h1, h2, h3, h4]
      for i = 0; i < 4; i = i + 1 {
        let c = hex_chars[i]
        let digit = match c {
          '0'..='9' => (c - '0').to_int()
          'a'..='f' => (c - 'a').to_int() + 10
          'A'..='F' => (c - 'A').to_int() + 10
          _ =>
            raise ParseError(
              "Invalid unicode escape sequence",
              view.start_offset() - (4 - i),
            )
        }
        code_point = code_point * 16 + digit
      }

      // Convert Unicode code point to UTF-8 bytes
      if code_point <= 0x7F {
        buffer.write_byte(code_point.to_byte())
      } else if code_point <= 0x7FF {
        buffer.write_byte((0xC0 | (code_point >> 6)).to_byte())
        buffer.write_byte((0x80 | (code_point & 0x3F)).to_byte())
      } else {
        buffer.write_byte((0xE0 | (code_point >> 12)).to_byte())
        buffer.write_byte((0x80 | ((code_point >> 6) & 0x3F)).to_byte())
        buffer.write_byte((0x80 | (code_point & 0x3F)).to_byte())
      }
      continue view
    }
    ['\\', 'u', ..] =>
      raise ParseError(
        "Invalid unicode escape sequence",
        self.view().start_offset(),
      )
    ['\\', _, .. view] =>
      raise ParseError("Invalid escape sequence", view.start_offset() - 1)
    ['\\'] =>
      raise ParseError(
        "Unexpected end of string after escape",
        self.view().start_offset(),
      )
    [c, .. view] => {
      // Regular character
      if c < 0x20 {
        raise ParseError(
          "Unescaped control character in string",
          view.start_offset() - 1,
        )
      }
      buffer.write_byte(c)
      continue view
    }
    [] => raise ParseError("Unterminated string", self.view().start_offset())
  }
  self.pos = final_view.start_offset()
  String(buffer.contents())
}

///|
fn Parser::parse_array(self : Parser) -> Json raise ParseError {
  if self.peek() != Some('[') {
    raise ParseError("Expected opening bracket", self.pos)
  }
  self.pos = self.pos + 1
  self.skip_whitespace()
  let elements : Array[Json] = []

  // Empty array
  if self.peek() == Some(']') {
    self.pos = self.pos + 1
    return Array(elements)
  }

  // Parse elements
  while true {
    let value = self.parse_value()
    elements.push(value)
    self.skip_whitespace()
    match self.peek() {
      Some(',') => {
        self.pos = self.pos + 1
        self.skip_whitespace()
      }
      Some(']') => {
        self.pos = self.pos + 1
        return Array(elements)
      }
      Some(_) => raise ParseError("Expected comma or closing bracket", self.pos)
      None => raise ParseError("Unterminated array", self.pos)
    }
  } else {
    raise ParseError("Unexpected error in array parsing", self.pos)
  }
}

///|
fn Parser::parse_object(self : Parser) -> Json raise ParseError {
  if self.peek() != Some('{') {
    raise ParseError("Expected opening brace", self.pos)
  }
  self.pos = self.pos + 1
  self.skip_whitespace()
  let obj : Map[Bytes, Json] = {}

  // Empty object
  if self.peek() == Some('}') {
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
        if self.peek() != Some(':') {
          raise ParseError("Expected colon after object key", self.pos)
        }
        self.pos = self.pos + 1
        self.skip_whitespace()

        // Parse value
        let value = self.parse_value()
        obj[[..key]] = value
        self.skip_whitespace()
        match self.peek() {
          Some(',') => {
            self.pos = self.pos + 1
            self.skip_whitespace()
          }
          Some('}') => {
            self.pos = self.pos + 1
            return Object(obj)
          }
          Some(_) =>
            raise ParseError("Expected comma or closing brace", self.pos)
          None => raise ParseError("Unterminated object", self.pos)
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
