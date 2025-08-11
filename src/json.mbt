///|
enum Json {
  Null
  Bool(Bool)
  Number(@bytes.View)
  String(@bytes.View)
  Array(Array[Json])
  Object(Map[String, Json])
} derive(Eq, Show)
