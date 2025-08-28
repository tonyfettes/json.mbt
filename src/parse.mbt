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
fn Parser::update(self : Parser, view : @bytes.View) -> Unit {
  self.pos = view.start_offset()
}

///|
fn Parser::parse_value(self : Parser) -> Json raise ParseError {
  self.skip_whitespace()
  match self.view() {
    [.. "null", .. view] => {
      self.update(view)
      Null
    }
    [.. "true", .. view] => {
      self.update(view)
      Bool(true)
    }
    [.. "false", .. view] => {
      self.update(view)
      Bool(false)
    }
    ['"', .. view] => {
      self.update(view)
      let buffer = @buffer.new()
      self.parse_string(buffer)
      String(buffer.contents())
    }
    ['[', .. view] => {
      self.update(view)
      let array = []
      self.parse_array(array)
      Array(array)
    }
    ['{', .. view] => {
      self.update(view)
      let object_ = {}
      self.parse_object(object_)
      Object(object_)
    }
    ['-' | '0'..='9', ..] => Number(self.parse_number())
    [..] => raise ParseError("Unexpected character", self.pos)
  }
}

///|
fn Parser::parse_number(self : Parser) -> @bytes.View raise ParseError {
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
  self.data[start:self.pos]
}

///|
fn Parser::parse_string(
  self : Parser,
  buffer : @buffer.T,
) -> Unit raise ParseError {
  let view = loop self.view() {
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
    ['\\', 'u', ..] as view =>
      raise ParseError("Invalid unicode escape sequence", view.start_offset())
    ['\\', _, .. view] =>
      raise ParseError("Invalid escape sequence", view.start_offset() - 1)
    ['\\'] as view =>
      raise ParseError(
        "Unexpected end of string after escape",
        view.start_offset(),
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
    [] as view => raise ParseError("Unterminated string", view.start_offset())
  }
  self.update(view)
}

///|
fn Parser::parse_array(
  self : Parser,
  elements : Array[Json],
) -> Unit raise ParseError {
  self.skip_whitespace()

  // Check for empty array
  match self.view() {
    [']', .. view] => {
      self.update(view)
      return
    }
    [..] => ()
  }

  // Parse elements
  while true {
    let value = self.parse_value()
    elements.push(value)
    self.skip_whitespace()
    match self.view() {
      [',', .. view] => {
        self.update(view)
        self.skip_whitespace()
      }
      [']', .. view] => {
        self.update(view)
        return
      }
      [_, ..] => raise ParseError("Expected comma or closing bracket", self.pos)
      [] => raise ParseError("Unterminated array", self.pos)
    }
  }
}

///|
fn Parser::parse_object(
  self : Parser,
  obj : Map[Bytes, Json],
) -> Unit raise ParseError {
  self.skip_whitespace()
  loop self.view() {
    ['}', .. view] => {
      self.update(view)
      return
    }
    ['"', .. view] => {
      self.update(view)
      let buffer = @buffer.new()
      self.parse_string(buffer)
      let key = buffer.contents()
      self.skip_whitespace()

      // Expect colon
      match self.view() {
        [':', .. view] => {
          self.update(view)
          self.skip_whitespace()
        }
        [..] => raise ParseError("Expected colon after object key", self.pos)
      }

      // Parse value
      let value = self.parse_value()
      obj[[..key]] = value
      self.skip_whitespace()
      match self.view() {
        [',', .. view] => {
          self.update(view)
          self.skip_whitespace()
          continue self.view()
        }
        ['}', .. view] => {
          self.update(view)
          return
        }
        [_, ..] => raise ParseError("Expected comma or closing brace", self.pos)
        [] => raise ParseError("Unterminated object", self.pos)
      }
    }
    [..] => raise ParseError("Invalid object key", self.pos)
  }
}

///|
/// Main parsing function that takes a @bytes.View and returns Json
pub fn parse(input : @bytes.View) -> Json raise ParseError {
  let parser = Parser::new(input)
  let value = parser.parse_value()
  parser.skip_whitespace()
  if parser.pos < parser.len {
    raise ParseError("Unexpected content after JSON value", parser.pos)
  } else {
    value
  }
}
