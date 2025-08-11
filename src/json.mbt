///|
pub enum Json[Number] {
  Null
  Bool(Bool)
  Number(Number)
  String(@bytes.View)
  Array(Array[Json[Number]])
  Object(Map[Bytes, Json[Number]])
} derive(Eq, Show)

///|
pub(open) trait Number {
  parse(bytes : @bytes.View) -> Self?
}

///|
pub impl Number for @bytes.View with parse(bytes : @bytes.View) -> @bytes.View? {
  Some(bytes)
}

///|
pub impl Number for Bytes with parse(bytes : @bytes.View) -> Bytes? {
  Some([..bytes])
}

///|
pub impl Number for Unit with parse(_ : @bytes.View) -> Unit? {
  None
}

///|
pub impl Number for Double with parse(view : @bytes.View) -> Double? {
  fn parse_positive(view : @bytes.View) -> Double? {
    if view.length() == 0 {
      return None
    }
    let mut pos = 0
    let len = view.length()
    let mut result = 0.0
    let mut has_digits = false

    // Parse integer part
    if pos < len && view[pos] == b'0' {
      has_digits = true
      pos = pos + 1
    } else if pos < len && view[pos] >= b'1' && view[pos] <= b'9' {
      has_digits = true
      while pos < len && view[pos] >= b'0' && view[pos] <= b'9' {
        result = result * 10.0 + (view[pos] - b'0').to_double()
        pos = pos + 1
      }
    } else {
      return None
    }

    // Parse fractional part
    if pos < len && view[pos] == b'.' {
      pos = pos + 1
      if pos >= len || view[pos] < b'0' || view[pos] > b'9' {
        return None // Invalid: decimal point must be followed by digits
      }
      let mut decimal_places = 0.1
      while pos < len && view[pos] >= b'0' && view[pos] <= b'9' {
        result = result + (view[pos] - b'0').to_double() * decimal_places
        decimal_places = decimal_places * 0.1
        pos = pos + 1
      }
    }

    // Parse exponent part
    if pos < len && (view[pos] == b'e' || view[pos] == b'E') {
      pos = pos + 1
      if pos >= len {
        return None // Invalid: exponent must be followed by digits
      }
      let mut exp_negative = false
      if view[pos] == b'+' {
        pos = pos + 1
      } else if view[pos] == b'-' {
        exp_negative = true
        pos = pos + 1
      }
      if pos >= len || view[pos] < b'0' || view[pos] > b'9' {
        return None // Invalid: exponent must have digits
      }
      let mut exponent = 0
      while pos < len && view[pos] >= b'0' && view[pos] <= b'9' {
        exponent = exponent * 10 + (view[pos] - b'0').to_int()
        pos = pos + 1
      }
      if exp_negative {
        exponent = -exponent
      }

      // Apply exponent
      let mut power = 1.0
      if exponent >= 0 {
        for _i = 0; _i < exponent; _i = _i + 1 {
          power = power * 10.0
        }
        result = result * power
      } else {
        for _i = 0; _i < -exponent; _i = _i + 1 {
          power = power * 10.0
        }
        result = result / power
      }
    }

    // Ensure we've consumed the entire view
    if pos == len && has_digits {
      Some(result)
    } else {
      None
    }
  }

  match view {
    ['-', .. view] =>
      match parse_positive(view) {
        Some(value) => Some(-value)
        None => None
      }
    _ => parse_positive(view)
  }
}
