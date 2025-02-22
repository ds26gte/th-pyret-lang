provide *
import js-file("../builtin-modules") as B
import js-file("../ts-pathlib") as P
import js-file("../parse-pyret") as PP
import file("../compile-lib.arr") as CL
import file("../compile-structs.arr") as CM
import file("../file.arr") as F
import js-file("../ts-js-of-pyret") as JSP

# NOTE(joe): These conversions are done in Pyret-land because
# "builtin-modules" in JS is as spartan as possible to make module load-order
# dependencies as painless as possible; if importing builtin modules required
# access to compile-lib and sets and so on, it would be very difficult to
# bootstrap things.  So make-dep and make-provides handle this transition

make-dep = CM.make-dep

convert-provides = CM.provides-from-raw-provides

var _defunct-builtin-js-dirs = [list: "src/js/runtime"]
var builtin-arr-dirs = [list:]
var typable-builtins = [list: ]
var allow-builtin-overrides = false

fun set-builtin-js-dirs(paths :: List<String>):
  _defunct-builtin-js-dirs := paths
end

fun set-builtin-arr-dirs(paths :: List<String>):
  builtin-arr-dirs := paths
end

fun set-allow-builtin-overrides(flag :: Boolean):
  allow-builtin-overrides := flag
end

fun set-typable-builtins(uris :: List<String>):
  typable-builtins := uris
end

fun make-builtin-js-locator(basedir, builtin-name):
  raw = B.builtin-raw-locator(P.join(basedir, builtin-name))
  source-path = P.join(basedir, builtin-name + ".arr.js")
  header-path = P.join(basedir, builtin-name + ".arr.json")
  {
    method needs-compile(_, _): false end,
    method get-uncached(_): none end,
    method get-modified-time(self):
      F.file-times(P.join(basedir, builtin-name + ".arr.js")).mtime
    end,
    method get-options(self, options):
      options.{ check-mode: false, type-check: false }
    end,
    method get-module(_):
      raise("Should never fetch source for builtin module " + builtin-name)
    end,
    method get-extra-imports(self):
      CM.minimal-imports
    end,
    method get-dependencies(_):
      deps = raw.get-raw-dependencies()
      raw-array-to-list(deps).map(make-dep)
    end,
    method get-native-modules(_):
      natives = raw.get-raw-native-modules()
      raw-array-to-list(natives).map(CM.requirejs)
    end,
    method get-globals(_):
      CM.standard-globals
    end,

    method uri(_): "builtin://" + builtin-name end,
    method name(_): builtin-name end,

    method set-compiled(_, _, _): nothing end,
    method get-compiled(self, options):
      provs = convert-provides(self.uri(), {
        uri: self.uri(),
        modules: raw-array-to-list(raw.get-raw-module-provides()),
        values: raw-array-to-list(raw.get-raw-value-provides()),
        aliases: raw-array-to-list(raw.get-raw-alias-provides()),
        datatypes: raw-array-to-list(raw.get-raw-datatype-provides())
      })
      CL.arr-js-file(provs, header-path, source-path)
    end,

    method _equals(self, other, req-eq):
      req-eq(self.uri(), other.uri())
    end
  }
end

fun make-builtin-arr-locator(basedir, builtin-name):
  path = P.join(basedir, builtin-name + ".arr")
  
  var ast = nothing
  unused = {
    method get-modified-time(self):
      F.file-times(path).mtime
    end,
    method get-uncached(_): none end,
    method get-options(self, options):
      type-check = typable-builtins.member(self.uri())
      options.{ check-mode: false, type-check: type-check }
    end,
    method get-module(self) block:
      when ast == nothing block:
        when not(F.file-exists(path)):
          raise("File " + path + " does not exist")
        end
        ast := CL.pyret-ast(PP.surface-parse(F.file-to-string(path), self.uri()))
      end
      ast
    end,
    method get-dependencies(self):
      CL.get-dependencies(self.get-module(), self.uri())
    end,
    method get-native-modules(self):
      [list:]
    end,
    method get-extra-imports(self):
      CM.minimal-imports
    end,
    method get-globals(self):
      CM.standard-globals
    end,
    method set-compiled(self, cr, deps) block:
      ast := nothing
      nothing
    end,
    method needs-compile(self, provides):
      # does not handle provides from dependencies currently
      # NOTE(joe): Until we serialize provides correctly, just return false here
      cpath = path + ".js"
      if F.file-exists(path) and F.file-exists(cpath):
        stimes = F.file-times(path)
        ctimes = F.file-times(cpath)
        ctimes.mtime <= stimes.mtime
      else:
        true
      end
    end,
    method get-compiled(self, options):
      cpath = path + ".js"

      if F.file-exists(path) and F.file-exists(cpath):
        # NOTE(joe):
        # Since we're not explicitly acquiring locks on files, there is a race
        # condition in the next few lines – a user could potentially delete or
        # overwrite the original file for the source while this method is
        # running.  We can explicitly open and lock files with appropriate
        # APIs to mitigate this in the happy, sunny future.
        stimes = F.file-times(path)
        ctimes = F.file-times(cpath)
        if ctimes.mtime > stimes.mtime:
          raw = B.builtin-raw-locator(path)
          provs = convert-provides(self.uri(), {
            uri: self.uri(),
            values: raw-array-to-list(raw.get-raw-value-provides()),
            aliases: raw-array-to-list(raw.get-raw-alias-provides()),
            datatypes: raw-array-to-list(raw.get-raw-datatype-provides())
          })
          CL.already-done(CL.module-as-string(provs, CM.no-builtins, CM.computed-none, CM.ok(JSP.ccp-file(cpath))))
        else:
          none
        end
      else:
        none
      end
    end,
    method uri(self): "builtin://" + builtin-name end,
    method name(self): builtin-name end,
    method _equals(self, other, eq): eq(self.uri(), other.uri()) end
  }
  raise("Builtin arr files not supported")
end

fun maybe-make-builtin-locator(builtin-name :: String, options) -> Option<CL.Locator> block:

  #NOTE(jose) - options.builtin-js-dirs did not have the path specified by --builtin-js-dir argument,
  #             instead it had {base-dir}/src/src/runtime, which caused it to not find our compiled
  #             module files
  builtin-js-dirs = options.builtin-js-dirs
  
  matching-arr-files = for map(p from builtin-arr-dirs):
    full-path = P.join(p, builtin-name + ".arr")
    if F.file-exists(full-path):
      some(full-path)
    else:
      none
    end
  end.filter(is-some).map(_.value)
  matching-js-files = for map(p from builtin-js-dirs):
    full-path = P.join(p, builtin-name + ".arr.js")
    if F.file-exists(full-path):
      some(full-path)
    else:
      none
    end
  end.filter(is-some).map(_.value)
  when not(allow-builtin-overrides) block:
    when matching-arr-files.length() > 1:
      raise("The module " + builtin-name + " is defined in several locations: " +
        matching-arr-files.join-str(", ") + ".  Use --allow-builtin-overrides to permit this.")
    end
    when matching-js-files.length() > 1:
      raise("The module " + builtin-name + " is defined in several locations: " +
        matching-js-files.join-str(", ") + ".  Use --allow-builtin-overrides to permit this.")
    end
    when is-link(matching-arr-files) and is-link(matching-js-files):
      raise("The module " + builtin-name + " is defined in several locations: " +
        (matching-arr-files + matching-js-files).join-str(", ") + ".  Use --allow-builtin-overrides to permit this.")
    end
  end
  ask:
    | is-link(matching-arr-files) then:
      some(make-builtin-arr-locator(P.dirname(matching-arr-files.first), builtin-name))
    | is-link(matching-js-files) then:
      some(make-builtin-js-locator(P.dirname(matching-js-files.first), builtin-name))
    | otherwise:
      none
  end
end

fun make-builtin-locator(builtin-name, options):
  cases(Option) maybe-make-builtin-locator(builtin-name, options):
    | none =>
      raise("Could not find module " + builtin-name + " in any of " + (builtin-arr-dirs + options.builtin-js-dirs).join-str(", "))
    | some(v) => v
  end
end
