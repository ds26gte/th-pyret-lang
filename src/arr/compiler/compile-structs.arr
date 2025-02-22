#lang pyret

provide *
provide-types *
import file("ast.arr") as A
import srcloc as SL
import error-display as ED
import string-dict as SD
import js-file("ts-pathlib") as P
import file("type-structs.arr") as T

t-nothing = T.t-nothing(A.dummy-loc)
t-str = T.t-string(A.dummy-loc)
t-boolean = T.t-boolean(A.dummy-loc)
t-number = T.t-number(A.dummy-loc)
t-arrow = T.t-arrow(_, _, A.dummy-loc, false)
t-top = T.t-top(A.dummy-loc, false)
t-bot = T.t-bot(A.dummy-loc, false)
t-record = T.t-record(_, A.dummy-loc, false)
t-forall = T.t-forall(_, _, A.dummy-loc, false)
t-var = T.t-var(_, A.dummy-loc, false)
t-array = T.t-array(_, A.dummy-loc)
t-string = T.t-string(A.dummy-loc)
t-option = T.t-option(_, A.dummy-loc)
t-data = T.t-data(_, _, _, _, A.dummy-loc)
t-variant = T.t-variant(_, _, _, A.dummy-loc)
t-singleton-variant = T.t-singleton-variant(_, _, A.dummy-loc)
t-app = T.t-app(_, _, A.dummy-loc, false)
t-name = T.t-name(_, _, A.dummy-loc, false)

is-t-app = T.is-t-app

type URI = String
type StringDict = SD.StringDict
string-dict = SD.string-dict
mutable-string-dict = SD.mutable-string-dict
type MutableStringDict = SD.MutableStringDict

is-s-block = A.is-s-block
is-s-app = A.is-s-app

type Loc = SL.Srcloc

data CompileMode:
  | cm-builtin-stage-1
  | cm-builtin-general
  | cm-normal
end

data Dependency:
  | dependency(protocol :: String, arguments :: List<String>)
    with:
    method key(self): self.protocol + "(" + self.arguments.join-str(", ") + ")" end
  | builtin(modname :: String)
    with:
    method key(self): "builtin(" + self.modname + ")" end
end

data NativeModule:
  | requirejs(path :: String)
end

data BindOrigin:
  | bind-origin(local-bind-site :: Loc, definition-bind-site :: Loc, new-definition :: Boolean, uri-of-definition :: URI, original-name :: A.Name)
end

fun bo-local(loc, original-name):
  cases(SL.Srcloc) loc:
    | builtin(source) =>
      bind-origin(loc, loc, true, source, original-name)
    | else =>
      bind-origin(loc, loc, true, loc.source, original-name)
  end
end

# NOTE(joe): If source information ends up in provides, we can add an extra arg
# here to provide better definition site info for names from other modules
fun bo-module(local-loc, def-loc, def-uri, original-name):
  # spy "bo-module":
  #   def-uri, original-name, local-loc, def-loc
  # end
  bind-origin(local-loc, def-loc, false, def-uri, original-name)
end

fun bo-global(opt-origin, uri, original-name):
  cases(Option) opt-origin block:
    | none =>
      bind-origin(A.dummy-loc, SL.builtin(uri), false, uri, original-name)
    | some(origin) =>
      bind-origin(origin.local-bind-site, origin.definition-bind-site, false, uri, original-name)
  end
end

data ValueBinder:
  | vb-letrec
  | vb-let
  | vb-var
end

data ValueBind:
  | value-bind(
      origin :: BindOrigin,
      binder :: ValueBinder,
      atom :: A.Name,
      ann :: A.Ann)
end

data TypeBinder:
  | tb-type-let
  | tb-type-var
end

data TypeBindTyp:
  | tb-typ(typ :: T.Type)
  | tb-none
end

data TypeBind:
  | type-bind(
      origin :: BindOrigin,
      binder :: TypeBinder,
      atom :: A.Name,
      typ :: TypeBindTyp)
end

data ModuleBind:
  | module-bind(
      origin :: BindOrigin,
      atom :: A.Name,
      uri :: URI)
end

data ScopeResolution:
  | resolved-scope(ast :: A.Program, errors :: List<CompileError>)
end

data ComputedEnvironment:
  | computed-none
  | computed-env(
      module-bindings :: SD.MutableStringDict<ModuleBind>,
      bindings :: SD.MutableStringDict<ValueBind>,
      type-bindings :: SD.MutableStringDict<TypeBind>,
      datatypes :: SD.MutableStringDict<A.Expr>,
      module-env :: SD.StringDict<ModuleBind>,
      env :: SD.StringDict<ValueBind>,
      type-env :: SD.StringDict<TypeBind>)
end

data NameResolution:
  | resolved-names(
      ast :: A.Program,
      errors :: List<CompileError>,
      env :: ComputedEnvironment
     )
end

# Used to describe when additional module imports should be added to a
# program.  See wrap-extra-imports
data ExtraImports:
  | extra-imports(imports :: List<ExtraImport>)
end

# Import this module, and bind the given value and type bindings from it
data ExtraImport:
  | extra-import(dependency :: Dependency, as-name :: String, values :: List<String>, types :: List<String>)
end

data Loadable:
  | module-as-string(provides :: Provides, compile-env :: CompileEnvironment, post-compile-env :: ComputedEnvironment, result-printer :: CompileResult<Any>)
    # NOTE(joe): there's a circular dependency between this module and js-of-pyret.arr; hence the Any above
end


data CompileEnvironment:
  | compile-env(
        globals :: Globals,
        all-modules :: MutableStringDict<Loadable>,
        my-modules :: StringDict<URI>
      )
sharing:
  method value-by-uri(self, uri :: String, name :: String) block:
    when not(self.all-modules.has-key-now(uri)):
      spy: keys: self.all-modules.keys-list-now(), uri, name end
    end
    cases(Option) self.all-modules
      .get-value-now(uri)
      .provides.values
      .get(name):

      | none => none
      | some(ve) =>
        cases(ValueExport) ve block:
          | v-alias(origin, shadow name) =>
            when uri == origin.uri-of-definition:
              raise("Self-referential alias for " + name + " in module " + uri)
            end
            self.value-by-uri(origin.uri-of-definition, name)
          | else => some(ve)
        end
    end
  end,
  method value-by-uri-value(self, uri :: String, name :: String):
    cases(Option) self.value-by-uri(uri, name):
      | none => raise("Could not find value " + name + " on module " + uri)
      | some(v) => v
    end
  end,
  method datatype-by-uri(self, uri, name):
    cases(Option) self.all-modules
      .get-value-now(uri)
      .provides.data-definitions
      .get(name):

      | none => none
      | some(de) =>
        cases(DataExport) de block:
          | d-alias(origin, shadow name) =>
            when uri == origin.uri-of-definition:
              raise("Self-referential alias for " + name + " in module " + uri)
            end
            self.datatype-by-uri(origin.uri-of-definition, name)
          | d-type(origin, typ) => some(de)
        end
    end
  end,
  method datatype-by-uri-value(self, uri, name):
    cases(Option) self.datatype-by-uri(uri, name):
      | none => raise("Could not find datatype " + name + " on module " + uri)
      | some(v) => v
    end
  end,
  method resolve-datatype-by-uri(self, uri, name):
    self.datatype-by-uri(uri, name).and-then(lam(dt):
      cases(DataExport) dt block:
        | d-type(origin, typ) => typ
        | else => raise("resolve-datatype-by-uri got a d-alias: " + to-repr(dt))
      end
    end)
  end,
  method resolve-datatype-by-uri-value(self, uri, name):
    cases(Option) self.resolve-datatype-by-uri(uri, name):
      | none => raise("Could not find datatype " + name + " on module " + uri)
      | some(v) => v
    end
  end,
  method value-by-origin(self, origin):
    self.value-by-uri(origin.uri-of-definition, origin.original-name.toname())
  end,
  method value-by-origin-value(self, origin):
    self.value-by-uri-value(origin.uri-of-definition, origin.original-name.toname())
  end,
  method type-by-uri(self, uri, name):
    provides-of-aliased = self.all-modules.get-value-now(uri).provides
    cases(Option) provides-of-aliased.data-definitions.get(name):
      | some(remote-datatype) =>
        de = cases(DataExport) remote-datatype:
          | d-alias(origin, remote-name) =>
            cases(Option) self.datatype-by-uri(origin.uri-of-definition, remote-name):
              | some(de) => de
              | none => raise("A datatype alias in an export was not found: " + to-repr(remote-datatype))
            end
          | d-type(_, _) => remote-datatype
        end
        some(T.t-name(T.module-uri(de.origin.uri-of-definition), A.s-type-global(de.typ.name), de.origin.local-bind-site, false))
      | none =>
        cases(Option) provides-of-aliased.aliases.get(name):
          | some(typ) =>
            cases(T.Type) typ:
              | t-name(a-mod, a-id, l, inferred) =>
                cases(T.NameOrigin) a-mod:
                  | module-uri(shadow uri) => self.type-by-uri(uri, a-id.toname())
                  | else => raise("A provided type alias referred to an unresolved module: " + to-repr(typ))
                end
              | else => some(typ)
            end
          | none => none
        end
    end
  end,
  method type-by-uri-value(self, uri, name):
    cases(Option) self.type-by-uri(uri, name):
      | none => raise("Could not find type " + name + " on module " + uri)
      | some(v) => v
    end
  end,
  method global-value-dep-key(self, name :: String):
    self.globals.values.get-value(name)
  end,
  method type-by-origin(self, origin):
    self.type-by-uri(origin.uri-of-definition, origin.original-name.toname())
  end,
  method type-by-origin-value(self, origin):
    self.type-by-uri-value(origin.uri-of-definition, origin.original-name.toname())
  end,
  method global-value(self, name :: String):
    self.globals.values.get(name)
      .and-then(self.value-by-origin(_))
      .and-then(_.value)
  end,
  method global-value-value(self, name :: String):
    cases(Option) self.global-value(name):
      | none => raise("Could not find value " + name + " as a global")
      | some(v) => v
    end
  end,
  method global-type(self, name :: String):
    self.globals.types.get(name)
      .and-then(self.type-by-origin(_))
      .and-then(_.value)
  end,
  method uri-by-dep-key(self, dep-key):
    self.my-modules.get-value(dep-key)
  end,
  method provides-by-uri(self, uri):
    self.all-modules.get-now(uri)
      .and-then(_.provides)
  end,
  method provides-by-uri-value(self, uri):
    cases(Option) self.provides-by-uri(uri):
      | none => raise("Could not find module with uri: " + uri + " in keys " + to-repr(self.all-modules.keys-list-now()))
      | some(shadow provides) => provides
    end
  end,
  method provides-by-origin(self, origin):
    self.provides-by-uri(origin.uri-of-definition)
  end,
  method provides-by-origin-value(self, origin):
    self.provides-by-uri-value(origin.uri-of-definition)
  end,
  method provides-by-dep-key(self, dep-key):
    self.my-modules.get(dep-key)
      .and-then(self.all-modules.get-value-now(_))
      .and-then(_.provides)
  end,
  method provides-by-dep-key-value(self, dep-key):
    cases(Option) self.provides-by-dep-key(dep-key):
      | none => raise("Could not find dep key: " + dep-key)
      | some(shadow provides) => provides
    end
  end,
  method provides-by-value-name(self, name):
    self.globals.values.get(name)
      .and-then(self.provides-by-origin-value(_))
  end,
  method provides-by-value-name-value(self, name):
    cases(Option) self.provides-by-value-name(name):
      | none => raise("Could not find value " + name)
      | some(shadow provides) => provides
    end
  end,
  method provides-by-type-name(self, name):
    self.globals.types.get(name)
      .and-then(self.provides-by-origin(_))
      .and-then(_.value)
  end,
  method provides-by-type-name-value(self, name):
    cases(Option) self.provides-by-type-name(name):
      | none => raise("Could not find type " + name)
      | some(shadow provides) => provides
    end
  end,
  method provides-by-module-name(self, name):
    self.globals.modules.get(name)
      .and-then(self.provides-by-origin(_))
      .and-then(_.value)
  end,
  method provides-by-module-name-value(self, name):
    cases(Option) self.provides-by-module-name(name):
      | none => raise("Could not find module " + name)
      | some(shadow provides) => provides
    end
  end,
  method value-by-dep-key(self, dep-key, name):
    uri = self.my-modules.get-value(dep-key)
    self.value-by-uri(uri, name)
  end,
  method value-by-dep-key-value(self, dep-key, name):
    cases(Option) self.value-by-dep-key(dep-key, name):
      | none => raise("Could not find " + name + " on " + dep-key)
      | some(v) => v
    end
  end,
  method type-by-dep-key(self, dep-key, name):
    uri = self.my-modules.get-value(dep-key)
    self.type-by-uri(uri, name)
  end,
  method uri-by-value-name-value(self, name):
    cases(Option) self.uri-by-value-name(name):
      | none => raise("Could not find " + name + " in global values.")
      | some(g) => g
    end
  end,
  method uri-by-module-name(self, name):
    self.globals.modules.get(name)
  end,
  method origin-by-module-name(self, name):
    self.globals.modules.get(name)
  end,
  method origin-by-value-name(self, name):
    self.globals.values.get(name)
  end,
  method origin-by-type-name(self, name):
    self.globals.types.get(name)
  end,
  method uri-by-module-name(self, name):
    self.globals.modules.get(name).and-then(_.uri-of-definition)
  end,
  method uri-by-value-name(self, name):
    self.globals.values.get(name).and-then(_.uri-of-definition)
  end,
  method uri-by-type-name(self, name):
    self.globals.types.get(name).and-then(_.uri-of-definition)
  end
end

# Globals maps from names to BindOrigins so we know the most recent binding and
# original binding for each
data Globals:
  | globals(modules :: StringDict<BindOrigin>, values :: StringDict<BindOrigin>, types :: StringDict<BindOrigin>)
end

data ValueExport:
  | v-alias(origin :: BindOrigin, original-name :: String)
  | v-just-type(origin :: BindOrigin, t :: T.Type)
  | v-var(origin :: BindOrigin, t :: T.Type)
  | v-fun(origin :: BindOrigin, t :: T.Type, name :: String, flatness :: Option<Number>)
end

data DataExport:
  | d-alias(origin :: BindOrigin, name :: String)
  | d-type(origin :: BindOrigin, typ :: T.DataType)
end

data Provides:
  | provides(
      from-uri :: URI,
      modules :: StringDict<URI>,
      values :: StringDict<ValueExport>,
      aliases :: StringDict<T.Type>,
      data-definitions :: StringDict<DataExport>
    )
end

fun make-dep(raw-dep) -> Dependency:
 if raw-dep.import-type == "builtin":
    builtin(raw-dep.name)
  else:
    dependency(raw-dep.protocol, raw-array-to-list(raw-dep.args))
  end
end

rag = raw-array-get

fun value-export-from-raw(uri, val-export, tyvar-env :: SD.StringDict<T.Type>) -> ValueExport block:
  t = val-export.tag
  typ = type-from-raw(uri, val-export.typ, tyvar-env)
  if t == "v-fun":
    v-fun(typ, t, none)
  else:
    v-just-type(typ)
  end
end

fun type-from-raw(uri, typ, tyvar-env :: SD.StringDict<T.Type>) block:
  tfr = type-from-raw(uri, _, tyvar-env)
  # TODO(joe): Make this do something intelligent when location information
  # is available
  l = SL.builtin(uri)
  t = typ.tag
  #print("\n\ntyp: " + tostring(typ))
  ask:
    | t == "any" then: T.t-top(l, false)
    | t == "bot" then: T.t-bot(l, false)
    | t == "record" then:
      T.t-record(typ.fields.foldl(lam(f, fields): fields.set(f.name, tfr(f.value)) end, [string-dict: ]), l, false)
    | t == "data-refinement" then:
      T.t-data-refinement(tfr(typ.basetype), typ.variant, l, false)
    | t == "tuple" then:
      T.t-tuple(for map(e from typ.elts): tfr(e) end, l, false)
    | t == "name" then:
      if typ.origin.import-type == "$ELF":
        T.t-name(T.module-uri(uri), A.s-type-global(typ.name), l, false)
      else if typ.origin.import-type == "uri":
        T.t-name(T.module-uri(typ.origin.uri), A.s-type-global(typ.name), l, false)
      else:
        T.t-name(T.dependency(make-dep(typ.origin)), A.s-type-global(typ.name), l, false)
      end
    | t == "tyvar" then:
      cases(Option<T.Type>) tyvar-env.get(typ.name):
        | none => raise("Unbound type variable " + typ.name + " in provided type when processing " + uri)
        | some(tv) => T.t-var(tv, l, false)
      end
    | t == "forall" then:
      new-env = for fold(new-env from tyvar-env, a from typ.args):
        tvn = A.global-names.make-atom(a)
        new-env.set(a, tvn)
      end
      params = for SD.map-keys(k from new-env):
        T.t-var(new-env.get-value(k), l, false)
      end
      T.t-forall(params, type-from-raw(uri, typ.onto, new-env), l, false)
    | t == "tyapp" then:
      T.t-app(tfr(typ.onto), map(tfr, typ.args), l, false)
    | t == "arrow" then:
      T.t-arrow(map(tfr, typ.args), tfr(typ.ret), l, false)
    | otherwise: raise("Unknown raw tag for type: " + t)
  end
end

fun tvariant-from-raw(uri, tvariant, env):
  l = SL.builtin(uri)
  t = tvariant.tag
  ask:
    | t == "variant" then:
      members = tvariant.vmembers.foldr(lam(tm, members):
        link({tm.name; type-from-raw(uri, tm.typ, env)}, members)
      end, empty)
      with-members = for fold(wmembers from [string-dict:], wm from tvariant.withmembers):
        wmembers.set(wm.name, type-from-raw(uri, wm.value, env))
      end
      t-variant(tvariant.name, members, with-members)
    | t == "singleton-variant" then:
      with-members = for fold(wmembers from [string-dict:], wm from tvariant.withmembers):
        wmembers.set(wm.name, type-from-raw(uri, wm.value, env))
      end
      t-singleton-variant(tvariant.name, with-members)
    | otherwise: raise("Unkonwn raw tag for variant: " + t)
  end
end

fun datatype-from-raw(uri, datatyp):
  l = SL.builtin(uri)

  if datatyp.tag == "data-alias":
    origin = origin-from-raw(uri, datatyp.origin, datatyp.name)
    d-alias(origin, datatyp.name)
  else if datatyp.tag == "data":
    pdict = for fold(pdict from SD.make-string-dict(), a from datatyp.params):
      tvn = A.global-names.make-atom(a)
      pdict.set(a, tvn)
    end
    params = for SD.map-keys(k from pdict):
      T.t-var(pdict.get-value(k), l, false)
    end
    variants = map(tvariant-from-raw(uri, _, pdict), datatyp.variants)
    members = datatyp.methods.foldl(lam(tm, members):
      members.set(tm.name, type-from-raw(uri, tm.value, pdict))
    end, [string-dict: ])
    origin = origin-from-raw(uri, datatyp.origin, datatyp.name)
    d-type(origin, t-data(datatyp.name, params, variants, members))
  else:
    raise("Unknown format for data export in " + uri + ": " + to-repr(datatyp))
  end
end

fun srcloc-from-raw(raw):
  if raw-array-length(raw) == 1:
    SL.builtin(raw-array-get(raw, 0))
  else:
    SL.srcloc(
      raw-array-get(raw, 0),
      raw-array-get(raw, 1),
      raw-array-get(raw, 2),
      raw-array-get(raw, 3),
      raw-array-get(raw, 4),
      raw-array-get(raw, 5),
      raw-array-get(raw, 6))
  end
end

fun origin-from-raw(uri, raw, name):
  if raw.provided:
    bind-origin(
      srcloc-from-raw(raw.local-bind-site),
      srcloc-from-raw(raw.definition-bind-site),
      raw.new-definition,
      raw.uri-of-definition,
      A.s-name(srcloc-from-raw(raw.definition-bind-site), name)
      )
  else:
    bind-origin(SL.builtin(uri), SL.builtin(uri), false, uri, A.s-name(A.dummy-loc, name))
  end
end

fun provides-from-raw-provides(uri, raw):
  mods = raw.modules
  mdict = for fold(mdict from SD.make-string-dict(), v from raw.modules):
    mdict.set(v.name, v.uri)
  end
  values = raw.values
  vdict = for fold(vdict from SD.make-string-dict(), v from raw.values):
    if is-string(v) block:
      vdict.set(v, v-just-type(origin-from-raw(uri, {provided:false}, v), t-top))
    else:
      if v.value.bind == "alias":
        origin = origin-from-raw(uri, v.value.origin, v.value.original-name)
        vdict.set(v.name, v-alias(origin, v.value.original-name))
      else if v.value.bind == "var":
        origin = origin-from-raw(uri, v.value.origin, v.name)
        vdict.set(v.name, v-var(origin, type-from-raw(uri, v.value.typ, SD.make-string-dict())))
      else if v.value.bind == "fun":
        origin = origin-from-raw(uri, v.value.origin, v.name)
        flatness = if is-number(v.value.flatness):
          some(v.value.flatness)
        else:
          none
        end
        vdict.set(v.name, v-fun(origin, type-from-raw(uri, v.value.typ, SD.make-string-dict()), v.value.name, flatness))
      else:
        origin = origin-from-raw(uri, v.value.origin, v.name)
        vdict.set(v.name, v-just-type(origin, type-from-raw(uri, v.value.typ, SD.make-string-dict())))
      end
    end
  end
  adict = for fold(adict from SD.make-string-dict(), a from raw.aliases):
    if is-string(a):
      adict.set(a, t-top)
    else:
      adict.set(a.name, type-from-raw(uri, a.typ, SD.make-string-dict()))
    end
  end
  ddict = for fold(ddict from SD.make-string-dict(), d from raw.datatypes):
    ddict.set(d.name, datatype-from-raw(uri, d.typ))
  end
  provides(uri, mdict, vdict, adict, ddict)
end



data CompileResult<C>:
  | ok(code :: C)
  | err(problems :: List<CompileError>)
end

fun draw-and-highlight(l):
  ED.loc-display(l, "error-highlight", ED.loc(l))
end

data CompileError:
  | wf-err(msg :: List<ED.ErrorDisplay>, loc :: A.Loc) with:
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        ED.paragraph([list: ED.highlight(ED.text("Well-formedness:"), [list: self.loc], 0), ED.text(" ")]
            + self.msg),
        ED.cmcode(self.loc)]
    end
  | wf-empty-block(loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("block"),[list: self.loc], 0),
          ED.text(" is empty:")],
        ED.cmcode(self.loc)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Pyret rejected your program because there is an empty block at")],
        [ED.para: draw-and-highlight(self.loc)]]
    end
  | wf-err-split(msg :: String, loc :: List<A.Loc>) with:
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Well-formedness: "),
          ED.text(self.msg),
          ED.text(" at")],
        ED.v-sequence(self.loc.map(lam(l): [ED.para: draw-and-highlight(l)] end))]
    end
  | wf-bad-method-expression(method-expr-loc :: A.Loc) with:
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Method expressions are only allowed as object fields, data share-members, or data with-members. Found one at")],
        [ED.para: draw-and-highlight(self.method-expr-loc)]]
    end
  | reserved-name(loc :: Loc, id :: String) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Reading a "),
          ED.highlight(ED.text("name"), [list: self.loc], 0),
          ED.text(" errored:")],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("This name is reserved is reserved by Pyret, and cannot be used as an identifier.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The name "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.loc),
          ED.text(" is reserved by Pyret, and cannot be used as an identifier.")]]
    end
  | contract-on-import(loc :: Loc, name :: String, import-loc :: Loc, import-uri :: String) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Contracts for functions can only be defined once, and the contract for "),
          ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0),
          ED.text(" is already defined in the "),
          ED.highlight(ED.code(ED.text(self.import-uri)),
            [list: self.import-loc], 1),
          ED.text(" library.")],
        ED.cmcode(self.loc)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Contracts for functions can only be defined once, and the contract for "),
          ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
          ED.text(" is already defined in the "),
          ED.code(ED.text(self.import-type.tosource().pretty(1000).join-str(""))),
          ED.text(" library.")]]
    end
  | contract-redefined(loc :: Loc, name :: String, defn-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Contracts for functions can only be defined once, and the contract for "),
          ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0),
          ED.text(" is "),
          ED.highlight(ED.text("already defined"), [list: self.defn-loc], -1),
          ED.text(": ")],
        ED.cmcode(self.defn-loc)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Contracts for functions can only be defined once, and the contract for "),
          ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
          ED.text(" is already defined at "), ED.loc(self.defn-loc)]]
    end
  | contract-non-function(loc :: Loc, name :: String, defn-loc :: Loc, defn-is-function :: Boolean) with:
    method render-fancy-reason(self):
      if self.defn-is-function:
        [ED.error:
          [ED.para:
            ED.text("The contract for "),
            ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0),
            ED.text(" is not a valid function contract, but "),
            ED.highlight(ED.code(ED.text(self.name)), [list: self.defn-loc], -1),
            ED.text(" is defined as a function.")],
          ED.cmcode(self.loc),
          [ED.para:
            ED.text("The contract and the "),
            ED.highlight(ED.text("definition"), [list: self.defn-loc], -1),
            ED.text(" must be consistent.")],
          ED.cmcode(self.defn-loc)]
      else:
        [ED.error:
          [ED.para:
            ED.text("The contract for "),
            ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0),
            ED.text(" is a function contract, but "),
            ED.highlight(ED.code(ED.text(self.name)), [list: self.defn-loc], -1),
            ED.text(" is not defined as a function.")],
          ED.cmcode(self.loc),
          [ED.para:
            ED.text("The contract and the "),
            ED.highlight(ED.text("definition"), [list: self.defn-loc], -1),
            ED.text(" must be consistent.")],
          ED.cmcode(self.defn-loc)]
      end
    end,
    method render-reason(self):
      if self.defn-is-function:
        [ED.error:
          [ED.para:
            ED.text("The contract for "),
            ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
            ED.text(" is not a valid function contract, but "),
            ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.defn-loc),
            ED.text(" is defined as a function.")],
          [ED.para: ED.text("The contract and the definition must be consistent.")]]
      else:
        [ED.error:
          [ED.para:
            ED.text("The contract for "),
            ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
            ED.text(" is a function contract, but "),
            ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.defn-loc),
            ED.text(" is not defined as a function.")],
          [ED.para: ED.text("The contract and the definition must be consistent.")]]
      end
    end
  | contract-inconsistent-names(loc :: Loc, name :: String, defn-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The contract for "),
          ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0)],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("specifies arguments that are inconsistent with the "),
          ED.highlight(ED.text("associated definition"), [list: self.defn-loc], -1), ED.text(":")],
        ED.cmcode(self.defn-loc)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The contract for "),
          ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
          ED.text(" specifies arguments that are inconsistent with the definition at "), ED.loc(self.defn-loc)]]
    end
  | contract-inconsistent-params(loc :: Loc, name :: String, defn-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The contract for "),
          ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0)],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("specifies type parameters that are inconsistent with the "),
          ED.highlight(ED.text("associated definition"), [list: self.defn-loc], -1), ED.text(":")],
        ED.cmcode(self.defn-loc)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The contract for "),
          ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
          ED.text(" specifies type parameters that are inconsistent with the definition at "), ED.loc(self.defn-loc)]]
    end
  | contract-unused(loc :: Loc, name :: String) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The contract for "),
          ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0)],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text(" does not match the name of any function definition.")],
        [ED.para:
          ED.text("Contracts must appear just before their function's definition (or just before the function's examples block).  Check the spelling of this contract's name, or move it closer to its function if necessary.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The contract for "), ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
          ED.text(" does not match the name of any function definition.")],
        [ED.para:
          ED.text("Contracts must appear just before their function's definition (or just before the function's examples block).  Check the spelling of this contract's name, or move it closer to its function if necessary.")]]
    end
  | contract-bad-loc(loc :: Loc, name :: String, defn-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Contracts must appear just before their associated definition (or just before the function's examples block).  The contract for "),
          ED.highlight(ED.code(ED.text(self.name)), [list: self.loc], 0)],
        ED.cmcode(self.loc),
        [ED.para: ED.text(" comes after its "),
          ED.highlight(ED.text("associated definition"), [list: self.defn-loc], -1), ED.text(".")],
        ED.cmcode(self.defn-loc),
        [ED.para: ED.text("Move the contract just before its function.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Contracts must appear just before their associated definition (or just before the function's examples block).  The contract for "), ED.code(ED.text(self.name)), ED.text(" at "), ED.loc(self.loc),
          ED.text(" comes after its associated definition at "), ED.loc(self.defn-loc), ED.text(". Move the contract just before its function.")]]
    end
  | zero-fraction(loc :: A.Loc, numerator :: Number) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Reading a "),
          ED.highlight(ED.text("fraction literal expression"), [ED.locs: self.loc], 0),
          ED.text(" errored:")],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("Its denominator is zero.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Pyret disallows the fraction literal expression")],
        [ED.para:
          ED.code([ED.sequence:
                    ED.embed(self.numerator),
                    ED.text(" / 0")])],
        [ED.para:
          ED.text("at "),
          ED.loc(self.loc),
          ED.text(" because its denominator is zero.")]]
    end
  | mixed-binops(exp-loc :: A.Loc, op-a-name :: String, op-a-loc :: A.Loc, op-b-name :: String, op-b-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Reading this "),
          ED.highlight(ED.text("expression"), [ED.locs: self.exp-loc], -1),
          ED.text(" errored:")],
        ED.cmcode(self.exp-loc),
        [ED.para:
          ED.text("The "),
          ED.code(ED.highlight(ED.text(self.op-a-name),[list: self.op-a-loc], 0)),
          ED.text(" operation is at the same level as the "),
          ED.code(ED.highlight(ED.text(self.op-b-name),[list: self.op-b-loc], 1)),
          ED.text(" operation.")],
        [ED.para:
          ED.text("Use parentheses to group the operations and to make the order of operations clear.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Operators of different kinds cannot be mixed at the same level, but "),
          ED.code(ED.text(self.op-a-name)),
          ED.text(" is at "),
          ED.loc(self.op-a-loc),
          ED.text(" at the same level as "),
          ED.code(ED.text(self.op-b-name)),
          ED.text(" at "),
          ED.loc(self.op-b-loc),
          ED.text(". Use parentheses to group the operations and to make the order of operations clear.")]]
    end
  | block-ending(l :: Loc, block-loc :: Loc, kind :: String) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("block"), [list: self.block-loc], -1),
          ED.text(" ends with a "),
          ED.highlight(ED.text(self.kind), [list: self.l], 0),
          ED.text(":")],
        ED.cmcode(self.l),
        [ED.para:
          ED.text("Blocks should end with an expression")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The block at "),
          ED.loc(self.block-loc),
          ED.text(" ends with a " + self.kind + " at "),
          ED.loc(self.l),
          ED.text(". Blocks should end with an expression.")]]
    end
  | single-branch-if(expr :: A.Expr) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("An "),
          ED.highlight(ED.text("if-expression"), [list: self.expr.l], -1),
          ED.text(" has only one "),
          ED.highlight(ED.text("branch"), [list: self.expr.branches.first.l], 0),
          ED.text(":")],
        ED.cmcode(self.expr.l)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("If-expressions may not only have one branch, but the if-expression at "),
          ED.loc(self.expr.l),
          ED.text(" does not have any other branches.")]]
    end
  | unwelcome-where(kind :: String, loc :: A.Loc, block-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("A "),
          ED.highlight(ED.code(ED.text("where")), [list: self.block-loc], 0),
          ED.text(" can't be added to a "),
          ED.highlight(ED.text(self.kind), [list: self.loc], -1),
          ED.text(":")],
        ED.cmcode(self.block-loc),
        [ED.para:
          ED.text("A "),
          ED.code(ED.text("where")),
          ED.text(" block may only be added to named function declarations"),
          ED.text(".")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.code(ED.text("`where`")),
          ED.text(" blocks are only allowed on named function and declarations; a where block may not be added to a "),
          ED.loc(self.kind),
          ED.text(" at "),
          ED.loc(self.loc),
          ED.text(".")]]
    end
  | non-example(expr :: A.Expr) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.highlight(ED.text("This"),[list: self.expr.l], 0),
          ED.text(" is not a testing statement:")],
        ED.cmcode(self.expr.l),
        [ED.para:
          ED.code(ED.text("example")),
          ED.text(" blocks must only contain testing statements.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.code(ED.text("example")),
          ED.text(" blocks must only contain testing statements, but the statement at "),
          ED.loc(self.expr.l),
          ED.text(" isn't a testing statement.")]]
    end
  | tuple-get-bad-index(l :: A.Loc, tup :: A.Expr, index :: Number, index-loc :: Loc) with:
    method render-fancy-reason(self):
      if not(num-is-integer(self.index)):
        [ED.error:
          [ED.para:
            ED.text("This "),
            ED.highlight(ED.text("tuple indexing"), [list: self.l], -1),
            ED.text(" expression cannot extract a "),
            ED.highlight(ED.text("non-integer position"),[list: self.index-loc],0),
            ED.text(".")],
          ED.cmcode(self.l)]
      else if self.index < 0:
        [ED.error:
          [ED.para:
            ED.text("This "),
            ED.highlight(ED.text("tuple indexing"), [list: self.l], -1),
            ED.text(" expression cannot extract a "),
            ED.highlight(ED.text("negative position"),[list: self.index-loc],0),
            ED.text(".")],
          ED.cmcode(self.l)]
      else:
        [ED.error:
          [ED.para:
            ED.text("This "),
            ED.highlight(ED.text("tuple indexing"), [list: self.l], -1),
            ED.text(" expression cannot extract an "),
            ED.highlight(ED.text("index"),[list: self.index-loc],0),
            ED.text(" that large. There are no tuples that big.")],
          ED.cmcode(self.l)]
      end
    end,
    method render-reason(self):
      if not(num-is-integer(self.index)):
        [ED.error:
          [ED.para:
            ED.text("The tuple indexing expression at "),
            ED.loc(self.l),
            ED.text(" was given an invalid, non-integer index.")]]
      else if self.index < 0:
        [ED.error:
          [ED.para:
            ED.text("The tuple indexing expression at "),
            ED.loc(self.l),
            ED.text(" was given an invalid, negative index.")]]
      else:
        [ED.error:
          [ED.para:
            ED.text("The tuple indexing expression at "),
            ED.loc(self.l),
            ED.text(" was given an index bigger than any tuple.")]]
      end
    end
  | import-arity-mismatch(l :: A.Loc, kind :: String, args :: List<String>, expected-arity :: Number, expected-args :: List<String>) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight([ED.sequence: ED.code(ED.text(self.kind)), ED.text(" import statement")],
                       [list: self.l], -1),
          ED.text(":")],
        ED.cmcode(self.l),
        [ED.para:
          ED.text("expects "),
          ED.ed-args(self.expected-arity),
          ED.text(":")],
         ED.bulleted-sequence(self.expected-args.map(ED.text))]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.code(ED.text(self.kind)),
          ED.text(" import statement at "),
          ED.loc(self.l),
          ED.text(" expects "),
          ED.ed-args(self.expected-arity),
          ED.text(":")],
         ED.bulleted-sequence(self.expected-args.map(ED.text))]
    end
  | no-arguments(expr #| :: A.Expr | A.Member%(is-s-method-field) |#) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("method declaration"), [list: self.expr.l], 0),
          ED.text(" should accept at least one argument:")],
        ED.cmcode(self.expr.l),
        [ED.para:
          ED.text("When a method is applied, the first argument is a reference to the object it belongs to.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Method declarations should accept at least one argument, but the method declaration at "),
          ED.loc(self.expr.l),
          ED.text(" has no arguments. When a method is applied, the first argument is a reference to the object it belongs to.")]]
    end
  | non-toplevel(kind :: String, l :: Loc, parent-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.code(ED.highlight(ED.text(self.kind), [ED.locs: self.l], 0)),
          ED.text(" is inside "),
          ED.highlight(ED.text("another block"), [list: self.parent-loc], -1),
          ED.text(":")],
        ED.cmcode(self.l),
        [ED.para:
          ED.text(self.kind),
          ED.text(" may only occur at the top-level of the program.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("You may only define the "),
          ED.code(ED.text(self.kind)),
          ED.text(" at "),
          ED.loc(self.l),
          ED.text(" at the top-level.")]]
    end
  | unwelcome-test(loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("testing statement"),[list: self.loc], 0)],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("is not inside a "),
          ED.code(ED.text("check")),
          ED.text(", "), ED.code(ED.text("where")),
          ED.text(" or "),
          ED.code(ED.text("examples")),
          ED.text(" block.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The testing statement at "),
          ED.loc(self.loc),
          ED.text(" is not inside a "),
          ED.code(ED.text("check")),
          ED.text(", "), ED.code(ED.text("where")),
          ED.text(" or "),
          ED.code(ED.text("examples")),
          ED.text(" block.")]]
    end
  | unwelcome-test-refinement(refinement :: A.Expr, op :: A.CheckOp) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("testing operator"),[list: self.op.l], 0),
          ED.text(" may not be used with a "),
          ED.highlight(ED.text("refinement"),[list: self.refinement.l], 1),
          ED.text(":")],
        ED.cmcode(self.op.l + self.refinement.l)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The testing operator at "),
          ED.loc(self.op.l),
          ED.text(" may not be used with the refinement syntax, "),
          ED.code(ED.text("%(...)"))]]
    end
  | underscore-as(l :: Loc, kind :: String) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.highlight(ED.text("_"), [ED.locs: self.l], 0)),
          ED.text(" cannot be used as "),
          ED.text(self.kind),
          ED.text(".")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.text("_")),
          ED.text(" at "),
          ED.loc(self.l),
          ED.text(" cannot be used as "),
          ED.text(self.kind),
          ED.text(".")]]
    end
  | underscore-as-pattern(l :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("An underscore cannot be used for this "),
          ED.highlight(ED.text("pattern"), [ED.locs: self.l], 0),
          ED.text(" in a cases expression:")],
        ED.cmcode(self.l),
        [ED.para:
          ED.text("To match all cases not matched by the other branches, use the pattern "),
          ED.code(ED.text("else")),
          ED.text(" instead.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.text("_")),
          ED.text(" at "),
          ED.loc(self.l),
          ED.text(" cannot be used as a pattern in a cases expression. To match all cases not matched by the previous branches, use the pattern "),
          ED.code(ED.text("else")),
          ED.text(" instead.")]]
    end
  | underscore-as-expr(l :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.highlight(ED.text("_"), [ED.locs: self.l], 0)),
          ED.text(" cannot be used where an expression is expected.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.text("_")),
          ED.text(" at "),
          ED.loc(self.l),
          ED.text(" cannot be used where an expression is expected.")]]
    end
  | underscore-as-ann(l :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.highlight(ED.text("_"), [ED.locs: self.l], 0)),
          ED.text(" cannot be used where a type annotation is expected.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The underscore "),
          ED.code(ED.text("_")),
          ED.text(" at "),
          ED.loc(self.l),
          ED.text(" cannot be used where a type annotation is expected.")]]
    end
  | block-needed(expr-loc :: Loc, blocks :: List<A.Expr % (is-s-block)>) with:
    method render-fancy-reason(self):
      if self.blocks.length() > 1:
        [ED.error:
          [ED.para:
            ED.text("This expression contains one or more "),
            ED.highlight(ED.text("blocks"), self.blocks.map(_.l), -1),
            ED.text(" that contain "),
           ED.highlight(ED.text("multiple expressions"), A.flatten(self.blocks.map(_.stmts)).filter({(e):not(A.is-binder(e))}).map(_.l), 0),
            ED.text(":")],
          ED.cmcode(self.expr-loc),
          [ED.para:
            ED.text("Either simplify each of these blocks to a single expression, or mark the outer expression with"),
            ED.code(ED.text("block:")), ED.text("to indicate this is deliberate.")]]
      else:
        [ED.error:
          [ED.para:
            ED.text("This expression contains a "),
            ED.highlight(ED.text("block"),[list: self.blocks.first.l],-1),
            ED.text(" that contains "),
            ED.highlight(ED.text("multiple expressions"), A.flatten(self.blocks.map(_.stmts)).filter({(e):not(A.is-binder(e))}).map(_.l), 0),
            ED.text(".")],
          ED.cmcode(self.expr-loc),
          [ED.para:
            ED.text("Either simplify this block to a single expression, or mark the outer expression with "),
            ED.code(ED.text("block:")), ED.text(" to indicate this is deliberate.")]]
      end
    end,
    method render-reason(self):
      if self.blocks.length() > 1:
        [ED.error:
          [ED.para: ED.text("The expression at "), draw-and-highlight(self.expr-loc),
            ED.text(" contains several blocks that each contain multiple expressions:")],
          ED.v-sequence(self.blocks.map(_.l).map(draw-and-highlight)),
          [ED.para:
            ED.text("Either simplify each of these blocks to a single expression, or mark the outer expression with "),
            ED.code(ED.text("block:")), ED.text(" to indicate this is deliberate.")]]
      else:
        [ED.error:
          [ED.para: ED.text("The expression at "), draw-and-highlight(self.expr-loc),
            ED.text(" contains a block that contains multiple expressions:")],
          ED.v-sequence(self.blocks.map(_.l).map(draw-and-highlight)),
          [ED.para:
            ED.text("Either simplify this block to a single expression, or mark the outer expression with "),
            ED.code(ED.text("block:")), ED.text(" to indicate this is deliberate.")]]
      end
    end
  | name-not-provided(name-loc :: Loc, imp-loc :: Loc, name :: A.Name, typ :: String) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.name-loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin import that's not defined"),
            ED.text(self.name.toname()), ED.text("at"),
            draw-and-highlight(self.name-loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The name "),
              ED.code(ED.highlight(ED.text(self.name.toname()), [ED.locs: self.name-loc], 0)),
              ED.text(" is not provided as a " + self.typ + " in the import at ")],
            ED.cmcode(self.imp-loc)]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.name-loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin import that's not defined"),
            ED.text(self.name.toname()), ED.text("at"),
            draw-and-highlight(self.name-loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The identifier "),
              ED.code(ED.text(self.name.toname())),
              ED.text(" at "),
              ED.loc(self.name-loc),
              ED.text(" is not provided as a " + self.typ + " in the import at "),
              ED.loc(self.imp-loc)]]
      end
    end
  | unbound-id(id :: A.Expr) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.id.l:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's unbound:"),
            ED.text(self.id.id.toname()), ED.text("at"),
            draw-and-highlight(self.id.l)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The identifier "),
              ED.code(ED.highlight(ED.text(self.id.id.toname()), [ED.locs: self.id.l], 0)),
              ED.text(" is unbound:")],
             ED.cmcode(self.id.l),
            [ED.para:
              ED.text("It is "),
              ED.highlight(ED.text("used"), [ED.locs: self.id.l], 0),
              ED.text(" but not previously defined.")]]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.id.l:
        | builtin(_) =>
          spy: id: self.id end
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's unbound:"),
            ED.text(self.id.id.toname()),
            draw-and-highlight(self.id.l)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The identifier "),
              ED.code(ED.text(self.id.id.toname())),
              ED.text(" at "),
              ED.loc(self.id.l),
              ED.text(" is unbound. It is "),
              ED.text("used but not previously defined.")]]
      end
    end
  | unbound-var(id :: String, loc :: Loc) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's unbound:"),
            ED.text(self.id),
            draw-and-highlight(self.loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The variable "),
              ED.code(ED.highlight(ED.text(self.id), [ED.locs: self.loc], 0)),
              ED.text(" is unbound. It is "),
              ED.highlight(ED.text("assigned to"), [ED.locs: self.loc], 0),
              ED.text(" but not previously defined.")]]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's unbound:"),
            ED.text(self.id),
            draw-and-highlight(self.loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The variable "),
              ED.code(ED.text(self.id)),
              ED.text(" at "),
              ED.loc(self.loc),
              ED.text(" is unbound. It is "),
              ED.text("used but not previously defined.")]]
      end
    end
  | unbound-type-id(ann :: A.Ann) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.ann.l:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's unbound:"),
            ED.text(self.ann.tosource().pretty(1000).first),
            draw-and-highlight(self.id.l)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The name "),
              ED.code(ED.highlight(ED.text(self.ann.tosource().pretty(1000).join-str("")), [ED.locs: self.ann.l], 0)),
              ED.text(" is used to indicate a type, but a definition of a type named "),
              ED.code(ED.highlight(ED.text(self.ann.tosource().pretty(1000).join-str("")), [ED.locs: self.ann.l], 0)),
              ED.text(" could not be found.")]]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.ann.l:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's unbound:"),
            ED.text(self.ann.tosource().pretty(1000).first), ED.text("at"),
            draw-and-highlight(self.id.l)]
        | srcloc(_, _, _, _, _, _, _) =>
          ann-name = self.ann.tosource().pretty(1000).join-str("")
          [ED.error:
            [ED.para:
              ED.text("The name "),
              ED.code(ED.text(ann-name)),
              ED.text(" at "),
              ED.loc(self.ann.l),
              ED.text(" is used to indicate a type, but a definition of a type named "),
              ED.code(ED.text(ann-name)),
              ED.text(" could not be found.")]]
      end
    end
  | type-id-used-in-dot-lookup(loc :: Loc, name :: A.Name) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("name"), [ED.locs: self.loc], 0),
          ED.text(" is being used with a dot accessor as if to access a type within another module.")],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("but it does not refer to a module.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("The name "),
          ED.text(tostring(self.name)),
          ED.text(" is being used with a dot accessor as if to access a type within another module at "),
          draw-and-highlight(self.loc),
          ED.text(", but it does not refer to a module.")]]
    end
  | type-id-used-as-value(id :: A.Name, origin :: BindOrigin) with:
    method render-fancy-reason(self):
      intro =
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("name"), [ED.locs: self.id.l], 0),
          ED.text(" is being used as a value:")]
      usage = ED.cmcode(self.id.l)
      cases(BindOrigin) self.origin:
        | bind-origin(lbind, ldef, newdef, uri, orig-name) =>
          if newdef:
            [ED.error: intro, usage,
              [ED.para:
                ED.text("But it is "),
                ED.highlight(ED.text("defined as a type"), [ED.locs: ldef], 1),
                ED.text(":")],
              ED.cmcode(ldef)]
          else:
            # TODO(joe/ben): This may be able to use lbind and ldef when they
            # are more refined; come back to this
            [ED.error: intro, usage,
              [ED.para:
                ED.text("But it is defined as a type in "),
                ED.embed(uri),
                ED.text(".")]]
          end
      end
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("The name "),
          ED.text(self.id.s),
          ED.text(" is used as a value at "),
          draw-and-highlight(self.id.l),
          ED.text(", but it is defined as a type.")]]
    end
  | unexpected-type-var(loc :: Loc, name :: A.Name) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("identifier"), [ED.locs: self.loc], self.loc),
          ED.text(" is used in a dot-annotation")],
        ED.cmcode(self.loc),
        [ED.para:
          ED.text("but is bound as a type variable.")]]
    end,
    method render-reason(self):
      #### TODO ###
      [ED.error:
        [ED.para-nospace:
          ED.text("Identifier "),
          ED.text(tostring(self.name)),
          ED.text(" is used in a dot-annotation at "),
          draw-and-highlight(self.loc),
          ED.text(", but is bound as a type variable")]]
    end
  | pointless-var(loc :: Loc) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.error:
            [ED.para:
              ED.text("ERROR: should not be allowed to have a builtin that's anonymous:"),
              draw-and-highlight(self.loc)]]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("This "),
              ED.highlight(ED.text("variable binding"), [list: self.loc], 0),
              ED.text(" is pointless:")],
            ED.cmcode(self.loc),
            [ED.para:
              ED.text("There is no name that can be used to mutate it later on.")]]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's anonymous:"),
            draw-and-highlight(self.loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("Defining the anonymous variable "),
              ED.code(ED.text("var _")),
              ED.text(" at "),
              ED.loc(self.loc),
              ED.text(" is pointless since there is no name that can be used to mutate it later on.")]]
      end
    end
  | pointless-rec(loc :: Loc) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.error:
            [ED.para:
              ED.text("ERROR: should not be allowed to have a builtin that's anonymous:"),
              draw-and-highlight(self.loc)]]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("This "),
              ED.highlight(ED.text("recursive binding"), [list: self.loc], 0),
              ED.text(" is pointless:")],
            ED.cmcode(self.loc),
            [ED.para:
              ED.text("There isn't a name that can be used to make a recursive call.")]]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.error:
            [ED.para:
              ED.text("ERROR: should not be allowed to have a builtin that's anonymous:"),
              draw-and-highlight(self.loc)]]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("Defining the anonymous recursive identifier "),
              ED.code(ED.text("rec _")),
              ED.text(" at "),
              ED.loc(self.loc),
              ED.text(" is pointless since there is no name to call recursively.")]]
      end
    end
  | pointless-shadow(loc :: Loc) with:
    method render-fancy-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's anonymous:"),
            draw-and-highlight(self.loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("This "),
              ED.highlight(ED.text("shadowing binding"), [list: self.loc], 0),
              ED.text(" is pointless:")],
            ED.cmcode(self.loc),
            [ED.para:
              ED.text("There is no name to shadow.")]]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.loc:
        | builtin(_) =>
          [ED.para:
            ED.text("ERROR: should not be allowed to have a builtin that's anonymous:"),
            draw-and-highlight(self.loc)]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The anonymous identifier "),
              ED.code(ED.text("shadow _")),
              ED.text(" at "),
              ED.loc(self.loc),
              ED.text(" cannot shadow anything: there is no name to shadow.")]]
      end
    end
  | bad-assignment(iuse :: A.Expr, idef :: Loc) with:
    method render-fancy-reason(self):
      use-loc-color = 0
      def-loc-color = 1
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("variable assignment statement"), [ED.locs: self.iuse.l], use-loc-color)],
        ED.cmcode(self.iuse.l),
        [ED.para:
          ED.text(" expects the name "),
          ED.code(ED.highlight(ED.text(self.iuse.id.toname()), [ED.locs: self.iuse.l], use-loc-color)),
          ED.text(" to refer to a variable definition statement, but "),
          ED.code(ED.text(self.iuse.id.toname())),
          ED.text(" is declared by an "),
          ED.highlight(ED.text("identifier definition statement."), [ED.locs: self.idef], def-loc-color)],
          ED.cmcode(self.idef)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The variable assignment expression "),
          ED.code(ED.text(self.iuse.tosource().pretty(1000).first)),
          ED.text(" at "),
          ED.loc(self.iuse.l),
          ED.text(" expects the name "),
          ED.code(ED.text(self.iuse.id.toname())),
          ED.text(" to refer to a variable definition expression, but "),
          ED.code(ED.text(self.iuse.id.toname())),
          ED.text(" is declared by an identifier definition expression at "),
          ED.loc(self.idef)]]
    end
  | mixed-id-var(id :: String, var-loc :: Loc, id-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The name "),
          ED.code(ED.text(self.id)),
          ED.text(" is both "),
          ED.highlight(ED.text("declared as a variable"), [ED.locs: self.var-loc], 0)],
        ED.cmcode(self.var-loc),
        [ED.para:
          ED.text("and "),
          ED.highlight(ED.text("declared as an identifier"), [ED.locs: self.id-loc], 1)],
        ED.cmcode(self.id-loc)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text(self.id + " is declared as both a variable (at " + tostring(self.var-loc) + ")"
              + " and an identifier (at " + self.id-loc.format(not(self.var-loc.same-file(self.id-loc))) + ")")]]
    end
  | shadow-id(id :: String, new-loc :: Loc, old-loc :: Loc, import-loc :: Option<Loc>) with:
    # TODO: disambiguate what is doing the shadowing and what is being shadowed.
    # it's not necessarily a binding; could be a function definition.
    method render-fancy-reason(self):


      # included in definitions, shadowed in definitions
      # included in definitions, shadowed in interactions
      # global in definitions, shadowed in definitions
      # global in definitions, shadowed in interactions
      # everything else mentions the name somewhere as a local-bind-site

      old-loc-color = 0
      new-loc-color = 1
      imp-loc-color = 2
      cases(SL.Srcloc) self.old-loc:
        | builtin(_) =>
          cases(Option) self.import-loc:
            | none =>
              [ED.error:
                [ED.para:
                  ED.text("The declaration of "),
                  ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                  ED.text(" shadows the declaration of a built-in of the same name.")]]
            | some(imp-loc) =>
              [ED.error:
                [ED.para:
                  ED.text("The declaration of "),
                  ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                  ED.text(" shadows the declaration of a built-in of the same name, which was imported "),
                  ED.highlight(ED.code(ED.text("here")), [list: imp-loc], imp-loc-color)]]
          end
        | srcloc(filename, _, _, _, _, _, _) =>
          is-builtin-loc = (string-index-of(filename, "builtin://") == 0)
          cases(Option) self.import-loc:
            | none =>
              [ED.error:
                if is-builtin-loc:
                  [ED.para:
                    ED.text("The declaration of "),
                    ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                    ED.text(" shadows a built-in declaration of the same name.")]
                else:
                  [ED.para:
                    ED.text("The declaration of "),
                    ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                    ED.text(" shadows a previous declaration of "),
                    ED.highlight(ED.code(ED.text(self.id)), [list: self.old-loc], old-loc-color)]
                end]
            | some(imp-loc) =>
              if imp-loc == self.old-loc:
                  [ED.para:
                    ED.text("The declaration of "),
                    ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                    ED.text(" shadows a previous declaration of "),
                    ED.highlight(ED.code(ED.text(self.id)), [list: self.old-loc], old-loc-color)]
              else:
                [ED.error:
                  if is-builtin-loc:
                    [ED.para:
                      ED.text("The declaration of "),
                      ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                      ED.text(" shadows a built-in declaration of the same name, which was imported "),
                      ED.highlight(ED.code(ED.text("here")), [list: imp-loc], imp-loc-color)]
                  else:
                    [ED.para:
                      ED.text("The declaration of "),
                      ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
                      ED.text(" shadows a previous declaration of "),
                      ED.highlight(ED.code(ED.text(self.id)), [list: self.old-loc], old-loc-color),
                      ED.text(", which was imported "),
                      ED.highlight(ED.code(ED.text("here")), [list: imp-loc], imp-loc-color)]
                  end]
              end
          end
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.old-loc:
        | builtin(_) =>
          cases(Option) self.import-loc:
            | none =>
              [ED.error:
                [ED.para:
                  ED.text("7The declaration of "),
                  ED.code(ED.text(self.id)),
                  ED.text(" at "),
                  ED.loc(self.new-loc),
                  ED.text(" shadows the declaration of a built-in of the same name, defined at "),
                  ED.loc(self.old-loc)]]
            | some(imp-loc) =>
              [ED.error:
                [ED.para:
                  ED.text("8The declaration of "),
                  ED.code(ED.text(self.id)),
                  ED.text(" at "),
                  ED.loc(self.new-loc),
                  ED.text(" shadows the declaration of a built-in of the same name, defined at "),
                  ED.loc(self.old-loc),
                  ED.text(" and imported from "),
                  ED.loc(imp-loc)]]
          end
        | srcloc(_, _, _, _, _, _, _) =>
          cases(Option) self.import-loc:
            | none =>
              [ED.error:
                [ED.para:
                  ED.text("9The declaration of "),
                  ED.code(ED.text(self.id)),
                  ED.text(" at "),
                  ED.loc(self.new-loc),
                  ED.text(" shadows a previous declaration of "),
                  ED.code(ED.text(self.id)),
                  ED.text(" defined at "),
                  ED.loc(self.old-loc)]]
            | some(imp-loc) =>
              [ED.error:
                [ED.para:
                  ED.text("0The declaration of "),
                  ED.code(ED.text(self.id)),
                  ED.text(" at "),
                  ED.loc(self.new-loc),
                  ED.text(" shadows a previous declaration of "),
                  ED.code(ED.text(self.id)),
                  ED.text(" defined at "),
                  ED.loc(self.old-loc),
                  ED.text(" and imported from "),
                  ED.loc(imp-loc)]]
          end
      end
    end
  | duplicate-id(id :: String, new-loc :: Loc, old-loc :: Loc) with:
    method render-fancy-reason(self):
      old-loc-color = 0
      new-loc-color = 1
      cases(SL.Srcloc) self.old-loc:
        | builtin(_) =>
          [ED.error:
            [ED.para:
              ED.text("The declaration of the identifier named "),
              ED.highlight(ED.code(ED.text(self.id)), [list: self.new-loc], new-loc-color),
              ED.text(" is preceeded in the same scope by a declaration of an identifier also named "),
              ED.highlight(ED.code(ED.text(self.id)), [list: self.old-loc], old-loc-color),
              ED.text(".")]]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("This declaration of a "),
              ED.highlight(ED.text("name"), [list: self.new-loc], 0),
              ED.text(" conflicts with an earlier declaration of the "),
              ED.highlight(ED.text("same name"), [list: self.old-loc], 1),
              ED.text(":")],
            ED.cmcode(self.old-loc),
            ED.cmcode(self.new-loc)]
      end
    end,
    method render-reason(self):
      cases(SL.Srcloc) self.old-loc:
        | builtin(_) =>
          [ED.error:
            [ED.para:
              ED.text("The declaration of the identifier named "),
              ED.code(ED.text(self.id)),
              ED.text(" at "),
              ED.loc(self.new-loc),
              ED.text(" is preceeded in the same scope by a declaration of an identifier also named "),
              ED.code(ED.text(self.id)),
              ED.text(" at "),
              ED.loc(self.old-loc)]]
        | srcloc(_, _, _, _, _, _, _) =>
          [ED.error:
            [ED.para:
              ED.text("The declaration of the identifier named "),
              ED.code(ED.text(self.id)),
              ED.text(" at "),
              ED.loc(self.new-loc),
              ED.text(" is preceeded in the same scope by a declaration of an identifier also named "),
              ED.code(ED.text(self.id)),
              ED.text(" at "),
              ED.loc(self.old-loc)]]
      end
    end
  | duplicate-field(id :: String, new-loc :: Loc, old-loc :: Loc) with:
    method render-fancy-reason(self):
      fun adjust(l):
        n = string-length(self.id)
        SL.srcloc(l.source,
          l.start-line, l.start-column, l.start-char,
          l.start-line, l.start-column + n, l.start-char + n)
      end
      old-loc-color = 0
      new-loc-color = 1
      [ED.error:
        [ED.para:
          ED.text("The declaration of the field named "),
          ED.highlight(ED.code(ED.text(self.id)), [list: adjust(self.new-loc)], new-loc-color),
          ED.text(" is preceeded by declaration of an field also named "),
          ED.highlight(ED.code(ED.text(self.id)), [list: adjust(self.old-loc)], old-loc-color),
          ED.text(":")],
        ED.cmcode(self.old-loc + self.new-loc),
        [ED.para: ED.text("Pick a different name for one of them.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The declaration of the field named "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.new-loc),
          ED.text(" is preceeded in the same object by a field of an identifier also named "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.old-loc),
          ED.text(".")],
        [ED.para: ED.text("Pick a different name for one of them.")]]
    end
  | same-line(a :: Loc, b :: Loc, b-is-paren :: Boolean) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.highlight(ED.text("This expression"), [list: self.a], 0),
          ED.text(" is on the same line as "),
          ED.highlight(ED.text("another expression"), [list: self.b], 1),
          ED.text(":")],
        ED.cmcode(self.a + self.b),
        if self.b-is-paren:
          [ED.para:
            ED.text("Each expression within a block should be on its own line.  "),
            ED.text("If you meant to write a function call, there should be no space between the "),
            ED.highlight(ED.text("function expression"), [list: self.a], 0),
            ED.text(" and the "), ED.highlight(ED.text("arguments"), [list: self.b], 1), ED.text(".")]
        else:
          [ED.para:
            ED.text("Each expression within a block should be on its own line.")]
        end]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Pyret expects each expression within a block to have its own line, but the expression at "),
          ED.loc(self.a),
          ED.text(" is on the same line as the expression at "),
          ED.loc(self.b),
          ED.text(".")]]
    end
  | template-same-line(a :: Loc, b :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("There are two "),
          ED.highlight(ED.text("unfinished template expressions"), [list: self.a, self.b], 0),
          ED.text(" on the same line.")],
        ED.cmcode(self.a + self.b),
        [ED.para:
          ED.text("Either remove one, or separate them.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("There are two unfinished template expressions on the same line at "),
          ED.loc(self.a + self.b),
          ED.text(". Either remove one, or separate them.")]]
    end
  | type-mismatch(type-1 :: T.Type, type-2 :: T.Type) with:
    method render-fancy-reason(self):
      {type-1; type-2} = if self.type-1.l.before(self.type-2.l): {self.type-1; self.type-2} else: {self.type-2; self.type-1} end
      [ED.error:
        [ED.para:
          ED.text("Type checking failed because of a type inconsistency.")],
        [ED.para:
          ED.text("The type constraint "),
          ED.highlight(ED.text(tostring(type-1)), [list: type-1.l], 0),
          ED.text(" was incompatible with the type constraint "),
          ED.highlight(ED.text(tostring(type-2)), [list: type-2.l], 1)]]
    end,
    method render-reason(self):
      {type-1; type-2} = if self.type-1.l.before(self.type-2.l): {self.type-1; self.type-2} else: {self.type-2; self.type-1} end
      [ED.error:
        [ED.para:
          ED.text("Type checking failed because of a type inconsistency.")],
        [ED.para:
          ED.text("The type constraint "),
          ED.code(ED.text(tostring(type-1))),
          ED.text(" at "), draw-and-highlight(type-1.l),
          ED.text(" was incompatible with the type constraint "),
          ED.code(ED.text(tostring(type-2))),
          ED.text(" at "), draw-and-highlight(type-2.l)]]
    end
  | incorrect-type(bad-name :: String, bad-loc :: A.Loc, expected-name :: String, expected-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because it found a "),
          ED.highlight(ED.text(self.bad-name), [list: self.bad-loc], 0),
          ED.text(" but it expected a "),
          ED.highlight(ED.text(self.expected-name), [list: self.expected-loc], 1)]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("Expected to find "), ED.code(ED.text(self.expected-name)),
          ED.text(" at "), draw-and-highlight(self.bad-loc),
          ED.text(", required by "), draw-and-highlight(self.expected-loc),
          ED.text(", but instead found "), ED.code(ED.text(self.bad-name)), ED.text(".")]]
    end
  | incorrect-type-expression(bad-name :: String, bad-loc :: A.Loc, expected-name :: String, expected-loc :: A.Loc, e :: A.Expr) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected the expression")],
        [ED.para:
          ED.cmcode(self.e.l)],
        [ED.para:
          ED.text("because it found a "),
          ED.highlight(ED.text(self.bad-name), [list: self.bad-loc], 0),
          ED.text(" but it expected a "),
          ED.highlight(ED.text(self.expected-name), [list: self.expected-loc], 1)]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected the expression")],
        [ED.para:
          ED.code(ED.v-sequence(self.e.tosource().pretty(80).map(ED.text)))],
        [ED.para:
          ED.text("because the expression at "), draw-and-highlight(self.bad-loc),
          ED.text(" was of type "), ED.code(ED.text(self.bad-name)),
          ED.text(" but it was expected to be of type "), ED.code(ED.text(self.expected-name)),
          ED.text(" because of "), draw-and-highlight(self.expected-loc)]]
    end
  | bad-type-instantiation(app-type :: T.Type%(is-t-app), expected-length :: Number) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the type application "),
          ED.highlight(ED.embed(self.app-type), [list: self.app-type.l], 0),
          ED.text(" expected " + tostring(self.expected-length) + " type arguments, "),
          ED.text("but it received " + tostring(self.app-type.args.length()))]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the type application "),
          ED.highlight(ED.embed(self.app-type), [list: self.app-type.l], 0),
          ED.text(" expected " + tostring(self.expected-length) + " type arguments, "),
          ED.text("but it received " + tostring(self.app-type.args.length()))]]
    end
  | incorrect-number-of-args(app-expr :: A.Expr%(is-s-app), fun-typ :: T.Type) with:
    method render-fancy-reason(self):
      ed-applicant = ED.highlight(ED.text("applicant"), [list: self.app-expr._fun.l], 0)
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("function application"), [ED.locs: self.app-expr.l], -1)],
        ED.cmcode(self.app-expr.l),
        [ED.para:
          ED.text("expects the "), ed-applicant,
          ED.text(" to evaluate to a function that accepts exactly the same number of arguments as are given to it.")],
        [ED.para:
          ED.highlight(ED.ed-args(self.app-expr.args.length()), self.app-expr.args.map(_.l), 1),
          ED.text(" " + if self.app-expr.args.length() == 1: "is " else: "are " end
                + "given, but the type signature of the "),
          ed-applicant],
        [ED.para:
          ED.embed(self.fun-typ)],
        [ED.para:
          ED.text("indicates that it evaluates to a function accepting exactly "),
          ED.ed-args(self.fun-typ.args.length()),
          ED.text(".")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the function application expression")],
        [ED.para:
          ED.code(ED.v-sequence(self.app-expr.tosource().pretty(80).map(ED.text)))],
        [ED.para:
          ED.text("expects the applicant at "),
          ED.loc(self.app-expr._fun.l),
          ED.text(" to evaluate to a function accepting exactly the same number of arguments as given to it in application.")],
        [ED.para:
          ED.text("However, the applicant is given "),
          ED.ed-args(self.app-expr.args.length()),
          ED.text(" and the type signature of the applicant")],
        [ED.para:
          ED.embed(self.fun-typ)],
        [ED.para:
          ED.text("indicates that it evaluates to a function accepting exactly "),
          ED.ed-args(self.fun-typ.args.length()),
          ED.text(".")]]
    end
  | method-missing-self(expr :: A.Expr) with:
    # TODO: is this a duplicate of `no-arguments`???
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("method declaration"), [list: self.expr.l], 0)],
        ED.cmcode(self.expr.l),
        [ED.para:
          ED.text(" does not accept at least one argument. When a method is applied, the first argument is a reference to the object it belongs to.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Method declarations are expected to accept at least one argument, but the method declaration at "),
          ED.loc(self.expr.l),
          ED.text(" has no arguments. When a method is applied, the first argument is a reference to the object it belongs to.")]]
    end
  | apply-non-function(app-expr :: A.Expr, typ :: T.Type) with:
    method render-fancy-reason(self):
      ed-applicant = ED.highlight(ED.text("applicant"), [list: self.app-expr._fun.l], 0)
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("function application"), [ED.locs: self.app-expr.l], -1)],
        ED.cmcode(self.app-expr.l),
        [ED.para:
          ED.text("expects the "), ed-applicant,
          ED.text(" to evaluate to a function value.")],
        [ED.para:
          ED.text("The "),
          ed-applicant,
          ED.text(" is a ")],
        ED.embed(self.typ)]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the function application expression")],
        [ED.para:
          ED.code(ED.v-sequence(self.app-expr.tosource().pretty(80).map(ED.text)))],
        [ED.para:
          ED.text("at "),
          ED.loc(self.app-expr._fun.l),
          ED.text(" expects the applicant to evaluate to a function value. However, the type of the applicant is "),
          ED.embed(self.typ)]]
    end
  | tuple-too-small(index :: Number, tup-length :: Number, tup :: String, tup-loc :: A.Loc, access-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the tuple type")],
         ED.highlight(ED.embed(self.tup), [list: self.tup-loc], 0),
        [ED.para:
          ED.text(" has only " + tostring(self.tup-length) + " elements, so the index"),
          ED.code(ED.highlight(ED.text(tostring(self.index)), [list: self.access-loc], 1)),
          ED.text(" is too large")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the tuple type ")],
          ED.embed(self.tup),
          ED.text(" at "),
          ED.loc(self.tup-loc),
          ED.text(" does not have a value at index "),
          ED.code(ED.text(self.index)),
          ED.text(" as indicated by the access of at "),
          ED.loc(self.access-loc)]
    end
  | object-missing-field(field-name :: String, obj :: String, obj-loc :: A.Loc, access-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the object type")],
         ED.highlight(ED.text(self.obj), [list: self.obj-loc], 0),
        [ED.para:
          ED.text("does not have a field named "),
          ED.code(ED.highlight(ED.text(self.field-name), [list: self.access-loc], 1))]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the object type ")],
          ED.embed(self.obj),
          ED.text(" at "),
          ED.loc(self.obj-loc),
          ED.text(" does not have a field named "),
          ED.code(ED.text(self.field-name)),
          ED.text(" as indicated by the access of that field at "),
          ED.loc(self.access-loc)]
    end
  | duplicate-variant(id :: String, found :: Loc, previous :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("variant"), [list: self.found], 0),
          ED.text(" is preceeded by "),
          ED.highlight(ED.text("another variant"), [list: self.previous], 1),
          ED.text(" of the same name:")],
        ED.cmcode(self.previous),
        ED.cmcode(self.found),
        [ED.para:
          ED.text("A data declaration may not have two variants with the same names.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("A variant may not have the same name as any other variant in the type, but the declaration of a variant "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.found),
          ED.text(" is preceeded by a declaration of a variant also named "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.previous),
          ED.text(".")]]
    end,
  | data-variant-duplicate-name(id :: String, found :: Loc, data-loc :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("variant"), [list: self.found], 0),
          ED.text(" has the same name as its "),
          ED.highlight(ED.text("containing datatype"), [list: self.data-loc], 1), ED.text(".")],
        ED.cmcode(self.found),
        ED.cmcode(self.data-loc),
        [ED.para:
          ED.text("The "),
          ED.code(ED.text("is-" + self.id)),
          ED.text(" predicates will shadow each other.  Please rename either the variant or the datatype to avoid this.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The variant "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.found),
          ED.text(" has the same name as its containing datatype.  The "),
          ED.code(ED.text("is-" + self.id)),
          ED.text(" predicates will shadow each other.  Please rename either the variant or the datatype to avoid this.")]]
    end,
  | duplicate-is-variant(id :: String, is-found :: Loc, base-found :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("variant"), [list: self.base-found], 0),
          ED.text(" will create a predicate named "), ED.code(ED.text("is-" + self.id)),
          ED.text(", but "),
          ED.highlight(ED.text("another variant"), [list: self.is-found], 1),
          ED.text(" is defined with that name:")],
        ED.cmcode(self.base-found),
        ED.cmcode(self.is-found),
        [ED.para:
          ED.text("Please rename one of the variants so their names do not collide.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The variant "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.base-found),
          ED.text(" will create a predicate named "),
          ED.code(ED.text("is-" + self.id)),
          ED.text(", but another variant is defined with that name.  Please rename one of the variants so their names do not collide.")]]
    end,
  | duplicate-is-data(id :: String, is-found :: Loc, base-found :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("data definition"), [list: self.base-found], 0),
          ED.text(" will create a predicate named "), ED.code(ED.text("is-" + self.id)),
          ED.text(", but "),
          ED.highlight(ED.text("one of its variants"), [list: self.is-found], 1),
          ED.text(" is defined with that name:")],
        ED.cmcode(self.base-found),
        ED.cmcode(self.is-found),
        [ED.para:
          ED.text("Please rename either the variant or the data definition so their names do not collide.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The data definition "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.base-found),
          ED.text(" will create a predicate named "),
          ED.code(ED.text("is-" + self.id)),
          ED.text(", but one of its variants is defined with that name.  Please rename either the variant or the data definition so their names do not collide.")]]
    end,
  | duplicate-is-data-variant(id :: String, is-found :: Loc, base-found :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("variant"), [list: self.base-found], 0),
          ED.text(" will create a predicate named "), ED.code(ED.text("is-" + self.id)),
          ED.text(", but "),
          ED.highlight(ED.text("the data definition"), [list: self.is-found], 1),
          ED.text(" already uses that name:")],
        ED.cmcode(self.base-found),
        ED.cmcode(self.is-found),
        [ED.para:
          ED.text("Please rename either the variant or the data definition so their names do not collide.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The variant "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.base-found),
          ED.text(" will create a predicate named "),
          ED.code(ED.text("is-" + self.id)),
          ED.text(", but its surrounding data definition already uses that name.  Please rename either the variant or the data definition so their names do not collide.")]]
    end,
  | duplicate-branch(id :: String, found :: Loc, previous :: Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This "),
          ED.highlight(ED.text("branch"), [list: self.found], 0),
          ED.text(" is preceeded by "),
          ED.highlight(ED.text("another branch"), [list: self.previous], 1),
          ED.text(" that matches the same name: ")],
        ED.cmcode(self.previous),
        ED.cmcode(self.found),
        [ED.para:
          ED.text("A variant may not be matched more than once in a cases expression.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("A variant may not be matched more than once in a cases expression, but the branch matching the variant "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.found),
          ED.text(" is preceeded by a branch also matching "),
          ED.code(ED.text(self.id)),
          ED.text(" at "),
          ED.loc(self.previous),
          ED.text(".")]]
    end,
  | unnecessary-branch(branch :: A.CasesBranch, data-type :: T.DataType, cases-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the "),
          ED.highlight(ED.text("cases expression"),[list: self.cases-loc], 0),
          ED.text(" expects that all of its branches have a variant of the same name in the data-type "),
          ED.code(ED.text(self.data-type.name)),
          ED.text(". However, no variant named "),
          ED.code(ED.highlight(ED.text(self.branch.name), [list: self.branch.pat-loc], 1)),
          ED.text(" exists in "),
          ED.code(ED.text(self.data-type.name)),
          ED.text("'s "),
          ED.highlight(ED.text("variants"),self.data-type.variants.map(_.l), 2),
          ED.text(":")],
        ED.bulleted-sequence(self.data-type.variants.map(lam(variant):
            ED.code(ED.highlight(ED.text(variant.name), [list: variant.l], 2)) end))]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the cases expression at "),
          ED.loc(self.cases-loc),
          ED.text(" expects that all of its branches have a variant of the same name in the data-type "),
          ED.code(ED.text(self.data-type.name)),
          ED.text(". However, no variant named "),
          ED.code(ED.text(self.branch.name)),
          ED.text(" (mentioned in the branch at "),
          ED.loc(self.branch.pat-loc),
          ED.text(")"),
          ED.text(" exists in the type "),
          ED.code(ED.text(self.data-type.name)),
          ED.text("'s variants:")],
         ED.bulleted-sequence(self.data-type.variants.map(_.name).map(ED.text))]
    end
  | unnecessary-else-branch(type-name :: String, loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker rejected your program because the "),
          ED.highlight(ED.text("cases expression"),[list: self.loc], 0),
          ED.text(" has a branch for every variant of "),
          ED.code(ED.text(self.type-name)),
          ED.text(". Therefore, the "),
          ED.code(ED.text("else")),
          ED.text(" branch is unreachable.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("The else branch for the cases expression at "),
          draw-and-highlight(self.loc),
          ED.text(" is not needed since all variants of " + self.type-name + " have been exhausted.")]]
    end
  | non-exhaustive-pattern(missing :: List<T.TypeVariant>, type-name :: String, loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("cases expression"),[list: self.loc], 0),
          ED.text(" should be able to handle all possible values of "),
          ED.code(ED.text(self.type-name)),
          ED.text(", but its branches cannot handle "),
          ED.highlight(ED.text(
              if self.missing.length() > 1: "several variants"
              else: "a variant"
              end), self.missing.map(_.l), 1),
          ED.text(".")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The cases expression at"),
          draw-and-highlight(self.loc),
          ED.text("does not exhaust all variants of " + self.type-name
            + ". It is missing: " + self.missing.map(_.name).join-str(", ") + ".")]]
    end
  | cant-match-on(ann :: A.Ann, type-name :: String, loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("A "),
          ED.code(ED.highlight(ED.text("cases expressions"), [list: self.loc], 0)),
          ED.text(" can only branch on variants of "),
          ED.code(ED.text("data")),
          ED.text(" types. The type "),
          ED.code(ED.highlight(ED.text(self.type-name), [list: self.ann.l], 1)),
          ED.text(" cannot be used in cases expressions.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type specified " + self.type-name),
          ED.text("at"),
          draw-and-highlight(self.loc),
          ED.text("cannot be used in a cases expression.")]]
    end
  | different-branch-types(l :: A.Loc, branch-types :: List<T.Type>) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The branches of this expression evaluate to different types and no common type encompasses all of them:")],
        ED.bulleted-sequence(map_n(lam(n, branch):
            ED.highlight(ED.embed(branch), [list: branch.l], n) end,
            0, self.branch-types))]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The branches of this expression evaluate to different types and no common type encompasses all of them:")],
        ED.bulleted-sequence(map_n(lam(n, branch):
         [ED.sequence:
              ED.loc(branch.l), ED.text(" has type "), ED.embed(branch)] end,
            0, self.branch-types))]
    end
  | incorrect-number-of-bindings(branch :: A.CasesBranch, variant :: T.TypeVariant) with:
    method render-fancy-reason(self):
      fun ed-fields(n):
        [ED.sequence:
          ED.embed(n),
          ED.text(if n == 1: " field" else: " fields" end)]
      end
      [ED.error:
        [ED.para:
          ED.text("The type checker expects that the "),
          ED.highlight(ED.text("pattern"), [list: self.branch.pat-loc], 0),
          ED.text(" in the cases branch has the same number of "),
          ED.highlight(ED.text("field bindings"), self.branch.args.map(_.l), 1),
          ED.text(" as the data variant "),
          ED.code(ED.highlight(ED.text(self.variant.name), [list: self.variant.l], 2)),
          ED.text(" has "),
          ED.highlight(ED.text("fields"), [list: A.dummy-loc], 3),
          ED.text(". However, the branch pattern binds "),
          ED.highlight(ed-fields(self.branch.args.length()), self.branch.args.map(_.l), 1),
          ED.text(" and the variant is declared as having "),
          ED.highlight(ed-fields(self.variant.fields.count()), [list: A.dummy-loc], 3)]]
    end,
    method render-reason(self):
      fun ed-fields(n):
        [ED.sequence:
          ED.embed(n),
          ED.text(if n == 1: " field" else: " fields" end)]
      end
      [ED.error:
        [ED.para:
          ED.text("The type checker expects that the pattern at "),
          ED.loc(self.branch.pat-loc),
          ED.text(" in the cases branch has the same number of field bindings as the data variant "),
          ED.code(ED.text(self.variant.name)),
          ED.text(" at "),
          ED.loc(self.variant.l),
          ED.text(" has fields. However, the branch pattern binds "),
          ed-fields(self.branch.args.length()),
          ED.text(" and the variant is declared as having "),
          ed-fields(self.variant.fields.length())]]
    end
  | cases-singleton-mismatch(name :: String, branch-loc :: A.Loc, should-be-singleton :: Boolean) with:
    method render-fancy-reason(self):
      if self.should-be-singleton:
        [ED.error:
          [ED.para:
            ED.text("The type checker rejected your program because the cases branch named "),
            ED.code(ED.highlight(ED.text(self.name), [list: self.branch-loc], 0)),
            ED.text(" has an argument list, but the variant is a singleton.")]]
      else:
        [ED.error:
          [ED.para:
            ED.text("The type checker rejected your program because the cases branch named "),
            ED.code(ED.highlight(ED.text(self.name), [list: self.branch-loc], 0)),
            ED.text(" has an argument list, but the variant is not a singleton.")]]
      end
    end,
    method render-reason(self):
      if self.should-be-singleton:
        [ED.error:
          [ED.para:
            ED.text("The type checker rejected your program because the cases branch named "),
            ED.code(ED.text(self.name)),
            ED.text(" at "),
            ED.loc(self.branch-loc),
            ED.text(" has an argument list, but the variant is a singleton.")]]
      else:
        [ED.error:
          [ED.para:
            ED.text("The type checker rejected your program because the cases branch named "),
            ED.code(ED.text(self.name)),
            ED.text(" at "),
            ED.loc(self.branch-loc),
            ED.text(" has an argument list, but the variant is not a singleton.")]]
      end
    end
  | given-parameters(data-type :: String, loc :: A.Loc) with:
    # duplicate of `bad-type-instantiation` ?
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The data type"),  ED.code(ED.text(self.data-type)),
          ED.text("does not take any parameters, but is given some at"),
          draw-and-highlight(self.loc)]]
    end
  | unable-to-instantiate(loc :: A.Loc) with:
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("In the type at"), draw-and-highlight(self.loc),
          ED.text("there was not enough information to instantiate the type, "
            + "or the given arguments are incompatible.")]]
    end
  | unable-to-infer(loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("Unable to infer the type of "),
          ED.highlight(ED.text("the expression"), [list: self.loc], 0),
          ED.text(" at "),
          ED.cmcode(self.loc),
          ED.text("Please add an annotation.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("Unable to infer the type of "), draw-and-highlight(self.loc),
          ED.text(". Please add an annotation.")]]
    end
  | unann-failed-test-inference(function-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker could not infer the type of the "),
          ED.highlight(ED.text("function"), [list: self.function-loc], 0),
          ED.text(". Please add type annotations to the arguments.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The type checker could not infer the type of the function at"),
          draw-and-highlight(self.function-loc),
          ED.text(". Please add type annotations to the arguments.")]]
    end
  | toplevel-unann(arg :: A.Bind) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("argument"), [list: self.arg.l], 0),
          ED.text(" at "),
          ED.cmcode(self.arg.l),
          ED.text(" needs a type annotation. Alternatively, provide a where: block with examples of the function's use.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.text("argument at"), draw-and-highlight(self.arg.l),
          ED.text(" needs a type annotation. Alternatively, provide a where: block with examples of the function's use.")]]
    end
  | polymorphic-return-type-unann(function-loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The "),
          ED.highlight(ED.text("function"), [list: self.function-loc], 0),
          ED.text(" is polymorphic. Please annotate its return type.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The function at "),
          draw-and-highlight(self.function-loc),
          ED.text(" is polymorphic. Please annotate its return type.")]]
    end
  | binop-type-error(binop :: A.Expr, tl :: T.Type, tr :: T.Type, etl :: T.Type, etr :: T.Type) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The typechecker thinks there's a problem with the "),
          ED.code(ED.highlight(ED.text(self.binop.op),[list: self.binop.op-l], 0)),
          ED.text(" binary operator expression:")],
         ED.cmcode(self.binop.l),
        [ED.para:
          ED.text("where the it thinks the "),
          ED.highlight(ED.text("left hand side"), [list: self.binop.left.l], 1),
          ED.text(" is a "), ED.embed(self.tl),
          ED.text(" and the "),
          ED.highlight(ED.text("right hand side"), [list: self.binop.right.l], 2),
          ED.text(" is a "), ED.embed(self.tr), ED.text(".")],
        [ED.para:
          ED.text("When the type checker sees a "),
          ED.highlight(ED.embed(self.etl), [list: self.binop.left.l], 1),
          ED.text("to the left of a "),
          ED.code(ED.highlight(ED.text(self.binop.op),[list: self.binop.op-l], 0)),
          ED.text(" it thinks that the "),
          ED.highlight(ED.text("right hand side"), [list: self.binop.right.l], 2),
          ED.text(" should be a "),
          ED.embed(self.etr)]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The typechecker thinks there's a problem with the "),
          ED.code(ED.highlight(ED.text(self.binop.op),[list: self.binop.op-l], 0)),
          ED.text(" binary operator expression at "), ED.loc(self.binop.op-l)],
        [ED.para:
          ED.text("where the it thinks the "),
          ED.highlight(ED.text("left hand side"), [list: self.binop.left.l], 1),
          ED.text(" is a "), ED.embed(self.tl),
          ED.text(" and the "),
          ED.highlight(ED.text("right hand side"), [list: self.binop.right.l], 2),
          ED.text(" is a "), ED.embed(self.tr), ED.text(".")],
        [ED.para:
          ED.text("When the type checker sees a "),
          ED.highlight(ED.embed(self.tl), [list: self.binop.left.l], 1),
          ED.text("to the left of a "),
          ED.code(ED.highlight(ED.text(self.binop.op),[list: self.binop.op-l], 0)),
          ED.text(" it thinks that the "),
          ED.highlight(ED.text("right hand side"), [list: self.binop.right.l], 2),
          ED.text(" should be a "),
          ED.embed(self.etr)]]
    end
  | cant-typecheck(reason :: String, loc :: A.Loc) with:
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("This program cannot be type-checked. " + "The reason that it cannot be type-checked is: " + self.reason +
        " at "), ED.cmcode(self.loc)]]
    end
  | unsupported(message :: String, blame-loc :: A.Loc) with:
    #### TODO ###
    method render-fancy-reason(self):
      self.render-reason()
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text(self.message + " (found at "),
          draw-and-highlight(self.blame-loc),
          ED.text(")")]]
    end
  | non-object-provide(loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("Couldn't read the program because the provide statement must contain an object literal"),
          ED.cmcode(self.loc)]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("Couldn't read the program because the provide statement must contain an object literal at "),
          draw-and-highlight(self.loc)]]
    end
  | no-module(loc :: A.Loc, mod-name :: String) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("There is no module imported with the name "),
          ED.highlight(ED.text(self.mod-name), [list: self.loc], 0)]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para-nospace:
          ED.text("There is no module imported with the name " + self.mod-name),
          ED.text(" (used at "),
          draw-and-highlight(self.loc),
          ED.text(")")]]
    end
  | table-empty-header(loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.highlight(ED.text("This table"), [list: self.loc], 0),
          ED.text(" has no column names, but tables must have at least one column.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The table at "),
          ED.loc(self.loc),
          ED.text(" has no column names, but tables must have at least one column.")]]
    end
  | table-empty-row(loc :: A.Loc) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.highlight(ED.text("This table row"), [list: self.loc], 0),
          ED.text(" is empty, but table rows cannot be empty.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The table row at "),
          ED.loc(self.loc),
          ED.text(" is empty, but table rows cannot be empty.")]]
    end
  | table-row-wrong-size(header-loc :: A.Loc, header :: List<A.FieldName>, row :: A.TableRow) with:
    method render-fancy-reason(self):
      fun ed-cols(n, ls, c):
        ED.highlight([ED.sequence:
            ED.embed(n),
            if n <> 1:
              ED.text("columns")
            else:
              ED.text("column")
            end], ls, c)
      end
      [ED.error:
        [ED.para:
          ED.text("The table row")],
        ED.cmcode(self.row.l),
        [ED.para:
          ED.text("has "),
          ed-cols(self.row.elems.length(), self.row.elems.map(_.l), 0),
          ED.text(", but the table header")],
        ED.cmcode(self.header-loc),
        [ED.para:
          ED.text(" declares "),
          ed-cols(self.header.length(), self.header.map(_.l), 1),
          ED.text(".")]]
    end,
    method render-reason(self):
      fun ed-cols(n):
        [ED.sequence:
          ED.embed(n),
          if n <> 1:
            ED.text("columns")
          else:
            ED.text("column")
          end]
      end
      [ED.error:
        [ED.para:
          ED.text("The table row at "),
          ED.loc(self.row.l),
          ED.text(" has "),
          ed-cols(self.row.elems.length()),
          ED.text(", but the table header "),
          ED.loc(self.header-loc),
          ED.text(" declares "),
          ed-cols(self.header.length()),
          ED.text(".")]]
    end
  | table-duplicate-column-name(column1 :: A.FieldName, column2 :: A.FieldName) with:
    method render-fancy-reason(self):
      [ED.error:
        [ED.para:
          ED.text("Column "),
          ED.highlight(ED.text(self.column1.name), [list: self.column1.l], 0),
          ED.text(" and column "),
          ED.highlight(ED.text(self.column2.name), [list: self.column2.l], 0),
          ED.text(" have the same name, but table columns must have different names.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The table columns at "),
          ED.loc(self.column1.l),
          ED.text(" and at "),
          ED.loc(self.column2.l),
          ED.text(" have the same name, but columns in a table must have different names.")]]
    end
  | table-reducer-bad-column(extension :: A.TableExtendField, col-defs :: A.Loc) with:
    method render-fancy-reason(self):
      bad-column = self.extension.col
      bad-column-name = bad-column.tosource().pretty(80).join-str("\n")
      reducer = self.extension.reducer
      reducer-name = reducer.tosource().pretty(80).join-str("\n")
      [ED.error:
        [ED.para:
          ED.text("The column "),
          ED.highlight(ED.text(bad-column-name), [list: bad-column.l], 0),
          ED.text(" is used with the reducer "),
          ED.highlight(ED.text(reducer-name), [list: reducer.l], 1),
          ED.text(", but it is not one of the "),
          ED.highlight(ED.text("used columns"), [list: self.col-defs], 2),
          ED.text(".")]]
    end,
    method render-reason(self):
      bad-column = self.extension.col
      reducer = self.extension.reducer
      [ED.error:
        [ED.para:
          ED.text("The column at "),
          ED.loc(bad-column.l),
          ED.text(" is used with the reducer at "),
          ED.loc(reducer.l),
          ED.text(", but it is not one of the used columns listed at "),
          ED.loc(self.col-defs),
          ED.text(".")]]
    end
  | table-sanitizer-bad-column(sanitize-expr :: A.LoadTableSpec, col-defs :: A.Loc) with:
    method render-fancy-reason(self):

      bad-column = self.sanitize-expr.name
      bad-column-name = bad-column.toname()
      sanitizer = self.sanitize-expr.sanitizer
      sanitizer-name = sanitizer.tosource().pretty(80).join-str(" ")
      [ED.error:
        [ED.para:
          ED.text("The column "),
          ED.highlight(ED.text(bad-column-name), [list: bad-column.l], 0),
          ED.text(" is used with the sanitizer "),
          ED.highlight(ED.text(sanitizer-name), [list: sanitizer.l], 1),
          ED.text(", but it is not one of the "),
          ED.highlight(ED.text("used columns"), [list: self.col-defs], 2),
          ED.text(".")]]
    end,
    method render-reason(self):
      bad-column = self.sanitize-expr.name
      sanitizer = self.sanitize-expr.sanitizer
      [ED.error:
        [ED.para:
          ED.text("The column at "),
          ED.loc(bad-column.l),
          ED.text(" is used with the sanitizer at "),
          ED.loc(sanitizer.l),
          ED.text(", but it is not one of the used columns listed at "),
          ED.loc(self.col-defs),
          ED.text(".")]]
    end
  | load-table-bad-number-srcs(lte :: A.Expr#|%(A.is-s-load-table)|#, num-found :: Number) with:
    method render-fancy-reason(self):
      load-table-expr = self.lte.tosource().pretty(80)
      [ED.error:
        [ED.para:
          ED.text("The table loader "),
          ED.highlight(ED.text(load-table-expr), [list: self.lte.l], 0),
          ED.text(" specifies "
              + num-to-string(self.num-found)
              + " sources, but it should only specify one.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The table loader at "),
          ED.loc(self.lte.l),
          ED.text(" specifies "
              + num-to-string(self.num-found)
              + " sources, but it should only specify one.")]]
    end
  | load-table-duplicate-sanitizer(original :: A.LoadTableSpec, col-name :: String, duplicate-exp :: A.LoadTableSpec) with:
    method render-fancy-reason(self):
      orig-pretty = self.original.tosource().pretty(80)
      dup-pretty = self.duplicate-exp.tosource().pretty(80)
      [ED.error:
        [ED.para:
          ED.text("The column "),
          ED.highlight(ED.text(self.col-name), [list: self.duplicate-exp.l], 0),
          ED.text(" is already sanitized by the sanitizer "),
          ED.highlight(ED.text(orig-pretty), [list: self.original.l], 1),
          ED.text(".")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The column at "),
          ED.loc(self.duplicate-exp.l),
          ED.text(" is already sanitized by the sanitizer at "),
          ED.loc(self.original.l),
          ED.text(".")]]
    end
  | load-table-no-body(load-table-exp :: A.Expr#|%(A.is-s-load-table)|#) with:
    method render-fancy-reason(self):
      pretty = self.load-table-exp.tosource().pretty(80)
      [ED.error:
        [ED.para:
          ED.text("The table loader "),
          ED.highlight(ED.text(pretty), [list: self.load-table-exp.l], 0),
          ED.text(" has no information about how to load the table. "
              + "It should at least contain a source.")]]
    end,
    method render-reason(self):
      [ED.error:
        [ED.para:
          ED.text("The table loader at "),
          ED.loc(self.load-table-exp.l),
          ED.text(" has no information about how to load the table. "
              + "It should at least contain a source.")]]
    end
end

data Pipeline:
  | pipeline-anchor
  | pipeline-ts-anchor(modules :: List<String>)
end

type CompileOptions = {
  check-mode :: Boolean,
  check-all :: Boolean,
  type-check :: Boolean,
  enable-spies :: Boolean,
  allow-shadowed :: Boolean,
  collect-all :: Boolean,
  collect-times :: Boolean,
  ignore-unbound :: Boolean,
  proper-tail-calls :: Boolean,
  user-annotations :: Boolean,
  compiled-cache :: String,
  display-progress :: Boolean,
  standalone-file :: String,
  log :: (String -> Nothing),
  on-compile :: Function, # NOTE: skipping types because the are in compile-lib
  before-compile :: Function,
  pipeline :: Pipeline
}

default-compile-options = {
  add-profiling: false,
  base-dir: ".",
  this-pyret-dir: ".",
  check-mode : true,
  check-all : true,
  checks: "all",
  type-check : false,
  enable-spies: true,
  allow-shadowed : false,
  collect-all: false,
  collect-times: false,
  ignore-unbound: false,
  proper-tail-calls: true,
  inline-case-body-limit: 5,
  module-eval: true,
  user-annotations: true,
  runtime-annotations: true,
  runtime-path: "../builtin/src/runtime",
  compiled-cache: "compiled",
  compiled-read-only: empty,
  recompile-builtins: true,
  display-progress: true,
  should-profile: method(_, locator): false end,
  log: lam(s, to-clear):
    cases(Option) to-clear block:
      | none => print(s)
      | some(n) =>
        print("\r")
        print(string-repeat(" ", n))
        print("\r")
        print(s)
    end
  end,
  log-error: lam(s):
    print-error(s)
  end,
  method on-compile(_, locator, loadable, _): loadable end,
  method before-compile(_, _): nothing end,
  html-file: none,
  deps-file: "build/bundled-node-deps.js",
  standalone-file: "src/js/base/handalone.js",
  pipeline: pipeline-anchor,
  session: "empty",
  session-filter: none,
  session-delete: false
}

fun make-default-compile-options(this-pyret-dir):
  default-compile-options.{
    base-dir: ".",
    this-pyret-dir: this-pyret-dir,
    deps-file: P.resolve(P.join(this-pyret-dir, "bundled-node-deps.js")),
    standalone-file: P.resolve(P.join(this-pyret-dir, "js/handalone.js")),
    builtin-js-dirs: [list: ],
    compile-mode: cm-normal,
  }
end

t-pred = t-arrow([list: t-top], t-boolean)
t-pred2 = t-arrow([list: t-top, t-top], t-boolean)

t-number-binop = t-arrow([list: t-number, t-number], t-number)
t-number-unop = t-arrow([list: t-number], t-number)
t-number-pred1 = t-arrow([list: t-number], t-boolean)
t-within-num = t-arrow([list: t-number], t-arrow([list: t-number, t-number], t-boolean))
t-within-any = t-arrow([list: t-number], t-arrow([list: t-top, t-top], t-boolean))

fun t-forall1(f):
  n = A.global-names.make-atom("a")
  t-forall([list: t-var(n)], f(t-var(n)))
end

# NOTE(alex): Removed runtime-values to avoid name weird name clashes
#   _times and co desugar to functions calls on the runtime module
runtime-provides = provides("builtin://global",
  [string-dict:],
  [string-dict:],
  [string-dict:
     "Number", t-top,
     "String", t-str,
     "Boolean", t-top,
     "RawArray", t-top,
     "Nothing", t-top,
     "Function", t-top,
     "NumPositive", t-top ],
  [string-dict:])

runtime-values = [string-dict:
  "nothing", bind-origin(SL.builtin("primitive-types"), SL.builtin("primitive-types"), true, "builtin://primitive-types", A.s-name(A.dummy-loc, "nothing"))
]

runtime-types = for SD.fold-keys(rt from [string-dict:], k from runtime-provides.aliases):
  rt.set(k, bind-origin(SL.builtin("primitive-types"), SL.builtin("primitive-types"), true, "builtin://primitive-types", A.s-name(A.dummy-loc, k)))
end

shadow runtime-types = for SD.fold-keys(rt from runtime-types, k from runtime-provides.data-definitions):
  rt.set(k, bind-origin(SL.builtin("primitive-types"), SL.builtin("primitive-types"), true, "builtin://primitive-types", A.s-name(A.dummy-loc, k)))
end

# MARK(joe/ben): modules
# no-builtins = compile-env(globals([string-dict: ], [string-dict: ], [string-dict: ]), [mutable-string-dict:],[string-dict:])

# MARK(joe/ben): modules
# standard-globals = globals([string-dict:], runtime-values, runtime-types)

# minimal-imports = extra-imports(
#  [list:
#    extra-import(builtin("global"), "$global", [list:], [list:])]
# )
minimal-imports = extra-imports([list:
])

standard-imports = extra-imports(
   [list:
      extra-import(builtin("global"), "$global", [list:], [list:]),
      extra-import(builtin("base"), "$base", [list:], [list:]),
      extra-import(builtin("arrays"), "arrays", [list:
          "array",
          "build-array",
          "array-from-list",
          "is-array",
          "array-of",
          "array-set-now",
          "array-get-now",
          "array-length",
          "array-to-list-now"
        ],
        [list: "Array"]),
      extra-import(builtin("lists"), "lists", [list:
          "list",
          "is-List",
          "is-empty",
          "is-link",
          "empty",
          "link",
          "range",
          "range-by",
          "repeat",
          "filter",
          "partition",
          "split-at",
          "any",
          "find",
          "map",
          "map2",
          "map3",
          "map4",
          "map_n",
          "map2_n",
          "map3_n",
          "map4_n",
          "each",
          "each2",
          "each3",
          "each4",
          "each_n",
          "each2_n",
          "each3_n",
          "each4_n",
          "fold",
          "fold2",
          "fold3",
          "fold4"
        ],
        [list: "List"]),
      extra-import(builtin("option"), "option", [list:
          "is-Option",
          "is-none",
          "is-some",
          "none",
          "some"
        ],
        [list: "Option"]),
      extra-import(builtin("error"), "error", [list: ], [list:]),
      extra-import(builtin("sets"), "sets", [list:
          "set",
          "tree-set",
          "list-set",
          "empty-set",
          "empty-list-set",
          "empty-tree-set",
          "list-to-set",
          "list-to-list-set",
          "list-to-tree-set"
        ],
        [list: "Set"])
    ])

# MARK(joe/ben): modules
no-builtins = compile-env(globals([string-dict: ], [string-dict: ], [string-dict: ]), [mutable-string-dict:],[string-dict:])

# MARK(joe/ben): modules
standard-globals = globals([string-dict:], runtime-values, runtime-types)


reactor-optional-fields = [SD.string-dict:
  "last-image",       {(l): A.a-name(l, A.s-type-global("Function"))},
  "on-tick",          {(l): A.a-name(l, A.s-type-global("Function"))},
  "to-draw",          {(l): A.a-name(l, A.s-type-global("Function"))},
  "on-key",           {(l): A.a-name(l, A.s-type-global("Function"))},
  "on-mouse",         {(l): A.a-name(l, A.s-type-global("Function"))},
  "stop-when",        {(l): A.a-name(l, A.s-type-global("Function"))},
  "seconds-per-tick", {(l): A.a-name(l, A.s-type-global("NumPositive"))},
  "title",            {(l): A.a-name(l, A.s-type-global("String"))},
  "close-when-stop",  {(l): A.a-name(l, A.s-type-global("Boolean"))}
]

reactor-fields = reactor-optional-fields.set("init", {(l): A.a-any(l)})
