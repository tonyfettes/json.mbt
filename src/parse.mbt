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
fn Parser::peek_at(self : Parser, offset : Int) -> Byte? {
  let target_pos = self.pos + offset
  if target_pos >= self.len {
    None
  } else {
    Some(self.data[target_pos])
  }
}

///|
fn Parser::skip_whitespace(self : Parser) -> Unit {
  while self.pos < self.len {
    match self.peek() {
      Some(' ' | '\t' | '\n' | '\r') => self.pos = self.pos + 1
      _ => break
    }
  }
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
  if self.pos + 4 <= self.len &&
    self.peek_at(0) == Some('n') &&
    self.peek_at(1) == Some('u') &&
    self.peek_at(2) == Some('l') &&
    self.peek_at(3) == Some('l') {
    self.pos = self.pos + 4
    Null
  } else {
    raise ParseError("Invalid null literal", self.pos)
  }
}

///|
fn Parser::parse_bool(self : Parser) -> Json raise ParseError {
  if self.pos + 4 <= self.len &&
    self.peek_at(0) == Some('t') &&
    self.peek_at(1) == Some('r') &&
    self.peek_at(2) == Some('u') &&
    self.peek_at(3) == Some('e') {
    self.pos = self.pos + 4
    Bool(true)
  } else if self.pos + 5 <= self.len &&
    self.peek_at(0) == Some('f') &&
    self.peek_at(1) == Some('a') &&
    self.peek_at(2) == Some('l') &&
    self.peek_at(3) == Some('s') &&
    self.peek_at(4) == Some('e') {
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
  Number(self.view()[0:self.pos - start])
}

///|
fn Parser::parse_string(self : Parser) -> Json raise ParseError {
  if self.peek() != Some('"') {
    raise ParseError("Expected opening quote", self.pos)
  }
  let start = self.pos + 1
  self.pos = self.pos + 1
  while self.pos < self.len {
    match self.peek() {
      Some('"') => {
        let content = self.data[start:self.pos]
        self.pos = self.pos + 1
        return String(content)
      }
      Some('\\') => {
        self.pos = self.pos + 1
        match self.peek() {
          Some('"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't') =>
            self.pos = self.pos + 1
          Some('u') => {
            self.pos = self.pos + 1
            if self.pos + 4 > self.len {
              raise ParseError("Invalid unicode escape sequence", self.pos)
            }
            // Validate 4 hex digits
            for j = 0; j < 4; j = j + 1 {
              match self.peek_at(j) {
                Some('0'..='9' | 'a'..='f' | 'A'..='F') => ()
                _ =>
                  raise ParseError(
                    "Invalid unicode escape sequence",
                    self.pos + j,
                  )
              }
            }
            self.pos = self.pos + 4
          }
          Some(_) => raise ParseError("Invalid escape sequence", self.pos)
          None =>
            raise ParseError("Unexpected end of string after escape", self.pos)
        }
      }
      Some(c) => {
        if c < 0x20 {
          raise ParseError("Unescaped control character in string", self.pos)
        }
        self.pos = self.pos + 1
      }
      None => break
    }
  }
  raise ParseError("Unterminated string", start - 1)
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
