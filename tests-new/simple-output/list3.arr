### 1357
import lists as L
import global as G

list = [L.list: 11, 33, 55]
big-list = L.append( list, [L.list: 77] )

G.assert( L.length( big-list ), 4, "Incorrect new list length" )
G.assert( L.member( big-list, 77 ), true, "Does not contain new value" )

mapped = L.map( lam( x ): x / 11 end, big-list )

msg = for L.fold(string from "", e from mapped):
  string + G.js-to-string(e)
end

G.console-log(msg)
