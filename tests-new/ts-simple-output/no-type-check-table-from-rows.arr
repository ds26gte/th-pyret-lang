### true

# no-type-check-table-from-rows.arr
# `table-from-rows` function.

import global as G
import equality as E
import tables as T

my-table =
  [T.table-from-rows:
    [T.raw-row: {"A"; 5}, {"B"; 7}, {"C"; 8}],
    [T.raw-row: {"A"; 1}, {"B"; 2}, {"C"; 3}]]

my-correct-table = table: A, B, C
  row: 5, 7, 8
  row: 1, 2, 3
end

passes-when-true = E.equal-always(my-correct-table, my-table)

G.console-log(passes-when-true)
