provide *

import either as E
import json as J
import js-file("ts-pathlib") as P
import string-dict as SD
import render-error-display as RED
import js-file("server") as S
import file("./cli-module-loader.arr") as CLI
import file("./compile-structs.arr") as CS
import file("locators/builtin.arr") as B
import js-file("./ts-compile-options") as CO

fun compile(options):
  outfile = cases(Option) options.get("outfile"):
    | some(v) => v
    | none => options.get-value("program") + ".jarr"
  end
  
  compile-opts = CO.populate-options(options, options.get-value("this-pyret-dir"))
  CLI.build-runnable-standalone(
    options.get-value("program"),
    compile-opts.require-config,
    outfile,
    compile-opts
    )
end

fun serve(port, pyret-dir):
  S.make-server(port, lam(msg, send-message) block:
    # print("Got message in pyret-land: " + msg)
    opts = J.read-json(msg).native()
    # print(torepr(opts))
    # print("\n")
    fun log(s, to-clear):
      d = [SD.string-dict: "type", J.j-str("echo-log"), "contents", J.j-str(s)]
      with-clear = cases(Option) to-clear:
        | none => d.set("clear-first", J.j-bool(false))
        | some(n) => d.set("clear-first", J.j-num(n))
      end
      send-message(J.j-obj(with-clear).serialize())
    end
    fun err(s):
      d = [SD.string-dict: "type", J.j-str("echo-err"), "contents", J.j-str(s)]
      send-message(J.j-obj(d).serialize())
    end
    with-logger = opts.set("log", log)
    with-error = with-logger.set("log-error", err)
    with-pyret-dir = with-error.set("this-pyret-dir", pyret-dir)
    with-compiled-read-only-dirs =
      if opts.has-key("perilous") and opts.get-value("perilous"):
        with-pyret-dir.set("compiled-read-only",
          link(P.resolve(P.join(pyret-dir, "../../src/runtime")), empty)
        ).set("user-annotations", false)
      else:
        with-pyret-dir.set("compiled-read-only",
          link(P.resolve(P.join(pyret-dir, "../../src/runtime")), empty)
        )
      end

    result = run-task(lam():
      compile(with-compiled-read-only-dirs)
    end)
    cases(E.Either) result block:
      | right(exn) =>
        err-str = RED.display-to-string(exn-unwrap(exn).render-reason(), tostring, empty)
        err-list = [list: J.j-str(err-str)]
        d = [SD.string-dict: "type", J.j-str("compile-failure"), "data", J.j-arr(err-list)]
        send-message(J.j-obj(d).serialize())
      | left(val) =>
        cases(E.Either) val block:
        | left(errors) =>
          err-list = for map(e from errors):
            J.j-str(RED.display-to-string(e.render-reason(), tostring, empty))
          end
          d = [SD.string-dict: "type", J.j-str("compile-failure"), "data", J.j-arr(err-list)]
          send-message(J.j-obj(d).serialize())
        | right(value) =>
          d = [SD.string-dict: "type", J.j-str("compile-success")]
          send-message(J.j-obj(d).serialize())
          nothing
        end
    end
  end)
end
