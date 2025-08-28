///|
pub suberror ParseError {
  InvalidNumber(@bytes.View)
  InvalidUnicodeEscapeSequence(@bytes.View)
  InvalidEscapeSequence(@bytes.View)
  UnescapedControlCharacter(@bytes.View)
  UnterminatedString
  UnexpectedCharacter(@bytes.View)
  UnterminatedArray
  ExpectCommaOrClosingBracket(@bytes.View)
  ExpectColon(@bytes.View)
  ExpectCommaOrClosingBrace(@bytes.View)
  UnterminatedObject
  InvalidObjectKey
  ExtraContent
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
fn Parser::advance(self : Parser, view : @bytes.View) -> Unit {
  self.pos = view.start_offset()
}

///|
fn Parser::parse_value(self : Parser) -> Json raise ParseError {
  self.skip_whitespace()
  match self.view() {
    [.. "null", .. view] => {
      self.advance(view)
      Null
    }
    [.. "true", .. view] => {
      self.advance(view)
      Bool(true)
    }
    [.. "false", .. view] => {
      self.advance(view)
      Bool(false)
    }
    ['"', .. view] => {
      self.advance(view)
      let buffer = @buffer.new()
      self.parse_string(buffer)
      String(buffer.contents())
    }
    ['[', .. view] => {
      self.advance(view)
      let array = []
      self.parse_array(array)
      Array(array)
    }
    ['{', .. view] => {
      self.advance(view)
      let object_ = {}
      self.parse_object(object_)
      Object(object_)
    }
    ['-' | '0'..='9', ..] => Number(self.parse_number())
    [..] as view => raise UnexpectedCharacter(view)
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
    raise InvalidNumber(self.data[start:])
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
    _ => raise InvalidNumber(self.data[start:])
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
      _ => raise InvalidNumber(self.data[start:])
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
        _ => raise InvalidNumber(self.data[start:])
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
    ['"', .. view] => break view
    ['\\', '"' | '\\' | '/' | 'b' | 'f' | 'n' | 'r' | 't' as b, .. view] => {
      buffer.write_byte(b)
      continue view
    }
    ['\\', 'u', .. view] => {
      let mut code_point = 0
      fn parse_unicode_digit(b : @bytes.View) -> @bytes.View raise ParseError {
        match b {
          ['0'..='9' as b, .. rest] => {
            code_point = code_point * 16 + (b - '0').to_int()
            rest
          }
          ['a'..='f' as b, .. rest] => {
            code_point = code_point * 16 + (b - 'a').to_int() + 10
            rest
          }
          ['A'..='F' as b, .. rest] => {
            code_point = code_point * 16 + (b - 'A').to_int() + 10
            rest
          }
          _ => raise InvalidUnicodeEscapeSequence(b)
        }
      }

      let view = view
        |> parse_unicode_digit()
        |> parse_unicode_digit()
        |> parse_unicode_digit()
        |> parse_unicode_digit()
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
    ['\\', .. view] => raise InvalidEscapeSequence(view)
    [0x00..<0x20, .. view] => raise UnescapedControlCharacter(view)
    [b, .. view] => {
      buffer.write_byte(b)
      continue view
    }
    [] => raise UnterminatedString
  }
  self.advance(view)
}

///|
fn Parser::parse_array(
  self : Parser,
  elements : Array[Json],
) -> Unit raise ParseError {
  self.skip_whitespace()
  match self.view() {
    [']', .. view] => {
      self.advance(view)
      return
    }
    [..] => ()
  }
  while true {
    let value = self.parse_value()
    elements.push(value)
    self.skip_whitespace()
    match self.view() {
      [',', .. view] => {
        self.advance(view)
        self.skip_whitespace()
      }
      [']', .. view] => {
        self.advance(view)
        return
      }
      [_, ..] as view => raise ExpectCommaOrClosingBracket(view)
      [] => raise UnterminatedArray
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
      self.advance(view)
      return
    }
    ['"', .. view] => {
      self.advance(view)
      let buffer = @buffer.new()
      self.parse_string(buffer)
      let key = buffer.contents()
      self.skip_whitespace()

      // Expect colon
      match self.view() {
        [':', .. view] => {
          self.advance(view)
          self.skip_whitespace()
        }
        [..] as view => raise ExpectColon(view)
      }

      // Parse value
      let value = self.parse_value()
      obj[[..key]] = value
      self.skip_whitespace()
      match self.view() {
        [',', .. view] => {
          self.advance(view)
          self.skip_whitespace()
          continue self.view()
        }
        ['}', .. view] => {
          self.advance(view)
          return
        }
        [_, ..] as view => raise ExpectCommaOrClosingBrace(view)
        [] => raise UnterminatedObject
      }
    }
    [..] => raise InvalidObjectKey
  }
}

///|
/// Main parsing function that takes a @bytes.View and returns Json
pub fn parse(input : @bytes.View) -> Json raise ParseError {
  let parser = Parser::new(input)
  let value = parser.parse_value()
  parser.skip_whitespace()
  let view = parser.view()
  if view is [] {
    value
  } else {
    raise ExtraContent
  }
}
