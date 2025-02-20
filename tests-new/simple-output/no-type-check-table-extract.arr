### true

# no-type-check-table-extract.arr
# `extract` syntax.

import global as G
import equality as E
import tables as T
import lists as L

my-table = table: a, b, c
  row: 1, 2, 3
  row: 4, 5, 6
  row: 7, 8, 9
end

column-a = extract a from my-table end
column-b = extract b from my-table end
column-c = extract c from my-table end

correct-a = [L.list: 1, 4, 7]
correct-b = [L.list: 2, 5, 8]
correct-c = [L.list: 3, 6, 9]

a-equal = E.equal-always(column-a, correct-a)
b-equal = E.equal-always(column-b, correct-b)
c-equal = E.equal-always(column-c, correct-c)

passes-when-true = a-equal and b-equal and c-equal

G.console-log(passes-when-true)
