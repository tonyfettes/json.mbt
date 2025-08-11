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
