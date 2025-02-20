### true

# no-type-check-table-build-column.arr
# table.build-column test.

import global as G
import equality as E
import tables as T

my-table = table: a, b
  row: 1, 2
  row: 3, 4
  row: 5, 6
end

fun adder(r):
  r.get-value("a") + r.get-value("b")
end

my-new-table = my-table.build-column("c", adder)

expected-table = table: a, b, c
  row: 1, 2, 3
  row: 3, 4, 7
  row: 5, 6, 11
end

passes-when-true = E.equal-always(expected-table, my-new-table)

G.console-log(passes-when-true)
