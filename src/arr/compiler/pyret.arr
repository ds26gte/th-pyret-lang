#lang pyret

import either as E
import js-file("ts-pathlib") as P
import render-error-display as RED
import string-dict as D
import system as SYS
import json as J
import file("cmdline.arr") as C
import file("cli-module-loader.arr") as CLI
import file("compile-lib.arr") as CL
import file("compile-structs.arr") as CS
import file("file.arr") as F
import file("locators/builtin.arr") as B
import file("server.arr") as S
import js-file("./ts-compile-options") as CO

# this value is the limit of number of steps that could be inlined in case body
DEFAULT-COMPILE_MODE = "normal"
DEFAULT-INLINE-CASE-LIMIT = 5
DEFAULT-TYPE-CHECK = true

success-code = 0
failure-code = 1

fun main(args :: List<String>) -> Number block:

  this-pyret-dir = P.dirname(P.resolve(C.file-name))

  options = [D.string-dict:
    "serve",
      C.flag(C.once, "Start the Pyret server"),
    "port",
      C.next-val-default(C.Str, "1701", none, C.once, "Port to serve on (default 1701, can also be UNIX file socket or windows pipe)"),
    "build-standalone",
      C.next-val(C.Str, C.once, "Main Pyret (.arr) file to build as a standalone"),
    "build-runnable",
      C.next-val(C.Str, C.once, "Main Pyret (.arr) file to build as a standalone"),
    "require-config",
      C.next-val(C.Str, C.once, "JSON file to use for requirejs configuration of build-runnable"),
    "outfile",
      C.next-val(C.Str, C.once, "Output file for build-runnable"),
    "run",
      C.next-val(C.Str, C.once, "Pyret (.arr) file to compile and run"),
    "standalone-file",
      C.next-val-default(C.Str, "src/js/base/handalone.js", none, C.once, "Path to override standalone JavaScript file for main"),
    "builtin-js-dir",
      C.next-val(C.Str, C.many, "Directory to find the source of builtin js modules"),
    "builtin-arr-dir",
      C.next-val(C.Str, C.many, "Directory to find the source of builtin arr modules"),
    "allow-builtin-overrides",
      C.flag(C.once, "Allow overlapping builtins defined between builtin-js-dir and builtin-arr-dir"),
    "no-display-progress",
      C.flag(C.once, "Skip printing the \"Compiling X/Y\" progress indicator"),
    "compiled-read-only-dir",
      C.next-val(C.Str, C.many, "Additional directories to search to find precompiled versions of modules"),
    "compiled-dir",
      C.next-val-default(C.Str, "compiled", none, C.once, "Directory to save compiled files to; searched first for precompiled modules"),
    "library",
      C.flag(C.once, "Don't auto-import basics like list, option, etc."),
    "module-load-dir",
      C.next-val-default(C.Str, ".", none, C.once, "Base directory to search for modules"),
    "checks",
      C.next-val(C.Str, C.once, "Specify which checks to execute (all, none, or main)"),
    "profile",
      C.flag(C.once, "Add profiling information to the main file"),
    "check-all",
      C.flag(C.once, "Run checks all modules (not just the main module)"),
    "no-check-mode",
      C.flag(C.once, "Skip checks"),
    "no-spies",
      C.flag(C.once, "Disable printing of all `spy` statements"),
    "allow-shadow",
      C.flag(C.once, "Run without checking for shadowed variables"),
    "improper-tail-calls",
      C.flag(C.once, "Run without proper tail calls"),
    "collect-times",
      C.flag(C.once, "Collect timing information about compilation"),
    "type-check",
      C.next-val-default(C.Bool, DEFAULT-TYPE-CHECK, none, C.once, "Type-check the program during compilation"),
    "inline-case-body-limit",
      C.next-val-default(C.Num, DEFAULT-INLINE-CASE-LIMIT, none, C.once, "Set number of steps that could be inlined in case body"),
    "deps-file",
      C.next-val(C.Str, C.once, "Provide a path to override the default dependencies file"),
    "html-file",
      C.next-val(C.Str, C.once, "Name of the html file to generate that includes the standalone (only makes sense if deps-file is the result of browserify)"),
    "no-module-eval",
      C.flag(C.once, "Produce modules as literal functions, not as strings to be eval'd (may break error source locations)"),
    "no-user-annotations",
      C.flag(C.once, "Ignore all annotations in .arr files, treating them as if they were blank."),
    "no-runtime-annotations",
      C.flag(C.once, "Ignore all annotations in the runtime, treating them as if they were blank."),
    "runtime-builtin-relative-path",
      C.next-val(C.Str, C.once, "Relative path of builtins at runtime. Only used when compiling builtins using anchor."),
      "compile-mode",
      C.next-val-default(C.Str, DEFAULT-COMPILE_MODE, none, C.once, "Compilation mode (defaults to \"normal\")")
  ]

  params-parsed = C.parse-args(options, args)

  fun err-less(e1, e2):
    if (e1.loc.before(e2.loc)): true
    else if (e1.loc.after(e2.loc)): false
    else: tostring(e1) < tostring(e2)
    end
  end

  cases(C.ParsedArguments) params-parsed block:
    | success(r, rest) =>
      checks =
        if r.has-key("no-check-mode") or r.has-key("library"): "none"
        else if r.has-key("checks"): r.get-value("checks")
        else: "all" end
      builtin-js-dirs = if r.has-key("builtin-js-dir"):
        if is-List(r.get-value("builtin-js-dir")):
            r.get-value("builtin-js-dir")
          else:
            [list: r.get-value("builtin-js-dir")]
          end
      else:
        empty
      end

      when r.has-key("builtin-js-dir"):
        B.set-builtin-js-dirs(r.get-value("builtin-js-dir"))
      end
      when r.has-key("builtin-arr-dir"):
        B.set-builtin-arr-dirs(r.get-value("builtin-arr-dir"))
      end
      when r.has-key("allow-builtin-overrides"):
        B.set-allow-builtin-overrides(r.get-value("allow-builtin-overrides"))
      end
      if r.has-key("checks") and r.has-key("no-check-mode") and not(r.get-value("checks") == "none") block:
        print-error("Can't use --checks " + r.get-value("checks") + " with -no-check-mode\n")
        failure-code
      else:
        if r.has-key("checks") and r.has-key("check-all") and not(r.get-value("checks") == "all") block:
          print-error("Can't use --checks " + r.get-value("checks") + " with -check-all\n")
          failure-code
        else:
          if not(is-empty(rest)) block:
            print-error("No longer supported\n")
            failure-code
          else:
            if r.has-key("build-runnable") block:
              outfile = if r.has-key("outfile"):
                r.get-value("outfile")
              else:
                r.get-value("build-runnable") + ".jarr"
              end
              result = run-task(lam():
                CLI.build-runnable-standalone(
                  r.get-value("build-runnable"),
                  r.get("require-config").or-else(P.resolve(P.join(this-pyret-dir, "config.json"))),
                  outfile,
                  CO.populate-options(r, this-pyret-dir)
                )
              end)

              # result = compile(with-builtin-js-dirs)
              # run-task(lam():
              #  compile(with-require-config)
              # end)
              cases(E.Either) result block:
                | right(exn) =>
                  block:
                    err-str = RED.display-to-string(exn-unwrap(exn).render-reason(), tostring, empty)
                    print-error(err-str)
                    print-error("\n")
                    failure-code
                  end
                | left(val) =>
                  cases(E.Either) val block:
                  | left(errors) =>
                    block:
                      err-list = for map(e from errors) block:
                        err-str = RED.display-to-string(e.render-reason(), tostring, empty)
                        print-error(err-str)
                        print-error("\n")
                      end
                      failure-code
                    end
                  | right(value) =>
                    success-code
                  end
              end
            else if r.has-key("serve"):
              port = r.get-value("port")
              S.serve(port, this-pyret-dir)
              success-code
            else if r.has-key("build-standalone"):
              print-error("Use build-runnable instead of build-standalone\n")
              failure-code
            else if r.has-key("run"):
              run-args =
                if is-empty(rest):
                  empty
                else:
                  rest.rest
                end
              result = CLI.run(r.get-value("run"), CO.populate-options(r, this-pyret-dir), run-args)
              _ = print(result.message + "\n")
              result.exit-code
            else:
              block:
                print-error(C.usage-info(options).join-str("\n"))
                print-error("Unknown command line options\n")
                failure-code
              end
            end
          end
        end
      end
    | arg-error(message, partial) =>
      block:
        print-error(message + "\n")
        print-error(C.usage-info(options).join-str("\n"))
        failure-code
      end
  end
end

exit-code = main(C.other-args)
SYS.exit-quiet(exit-code)
