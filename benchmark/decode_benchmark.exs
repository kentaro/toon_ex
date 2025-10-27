toon_small = "name: Alice\nage: 30"
json_small = Jason.encode!(%{"name" => "Alice", "age" => 30})

toon_medium = """
id: 123
name: Bob
email: bob@example.com
active: true
score: 98.5
tags[4]: elixir,toon,llm,encoding
"""

json_medium = Jason.encode!(%{
  "id" => 123,
  "name" => "Bob",
  "email" => "bob@example.com",
  "active" => true,
  "score" => 98.5,
  "tags" => ["elixir", "toon", "llm", "encoding"]
})

Benchee.run(
  %{
    "Toon.decode! (small)" => fn -> Toon.decode!(toon_small) end,
    "Jason.decode! (small)" => fn -> Jason.decode!(json_small) end,
    "Toon.decode! (medium)" => fn -> Toon.decode!(toon_medium) end,
    "Jason.decode! (medium)" => fn -> Jason.decode!(json_medium) end
  },
  time: 5,
  memory_time: 2
)
