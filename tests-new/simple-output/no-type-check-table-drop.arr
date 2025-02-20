### true

# no-type-check-table-drop.arr
# drop function

import global as G
import equality as E
import tables as T

my-table = table: name, age, favNum
  row: "Bob", 12, 1
  row: "Alice", 17, 2
  row: "Eve", 13, 3
end

my-dropped-table = T.drop(my-table, "age")

my-correct-table = table: name, favNum
  row: "Bob", 1
  row: "Alice", 2
  row: "Eve", 3
end

are-equal = E.equal-always(my-correct-table, my-dropped-table)

are-not-equal = E.equal-always(my-correct-table, my-table)

passes-when-true = are-equal and G.not(are-not-equal)

G.console-log(passes-when-true)
