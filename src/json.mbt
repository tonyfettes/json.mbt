///|
pub enum Json {
  Null
  Bool(Bool)
  Number(@bytes.View)
  String(@bytes.View)
  Array(Array[Json])
  Object(Map[Bytes, Json])
} derive(Eq, Show)
