### true

# no-type-check-filter.arr

import global as G
import equality as E
import tables as T

my-table = table: name, age, favorite-color
  row: "Bob", 13, "blue"
  row: "Alice", 12, "green"
  row: "Eve", 10, "red"
  row: "Frank", 13, "yellow"
end

fun predicate(row):
  row.get-value("age") == 13
end

my-filtered-table = T.filter(my-table, predicate)

my-correct-table = table: name, age, favorite-color
  row: "Bob", 13, "blue"
  row: "Frank", 13, "yellow"
end

are-equal = E.equal-always(my-correct-table, my-filtered-table)
are-not-equal = E.equal-always(my-correct-table, my-table)

passes-when-true = are-equal and G.not(are-not-equal)

G.console-log(passes-when-true)
