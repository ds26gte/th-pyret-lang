({
  requires: [ ],
  provides: {
    shorthands: {
      "AnyPred":  ["arrow", ["Any"], "Boolean"],
      "AnyPred2": ["arrow", ["Any", "Any"], "Boolean"],
      "EqualityPred": ["arrow", ["Any", "Any"],
                       { tag: "name", 
                         origin: { "import-type": "uri", uri: "builtin://equality" },
                         name: "EqualityResult" }],
      "NumPred":  ["arrow", ["Number"], "Boolean"],
      "NumPred2": ["arrow", ["Number", "Number"], "Boolean"],
      "NumBinop": ["arrow", ["Number", "Number"], "Number"],
      "NumUnop":  ["arrow", ["Number"], "Number"],
      "StrPred":  ["arrow", ["String"], "Boolean"],
      "StrPred2": ["arrow", ["String", "String"], "Boolean"],
      "StrBinop": ["arrow", ["String", "String"], "String"],
      "StrUnop":  ["arrow", ["String"], "String"],
      "tva":      ["tid", "a"],
      "tvb":      ["tid", "b"],
      "tvc":      ["tid", "c"],
      "tvd":      ["tid", "d"],
      "tve":      ["tid", "e"],
      "Equality": { tag: "name", 
                    origin: { "import-type": "uri", uri: "builtin://equality" },
                    name: "EqualityResult" }
    },
    values: {
      "print": ["forall", "a", ["arrow", ["tva"], "tva"]],
      "test-print": ["forall", "a", ["arrow", ["tva"], "tva"]],
      "print-error": ["forall", "a", ["arrow", ["tva"], "tva"]],
      "display": ["forall", "a", ["arrow", ["tva"], "tva"]],
      "display-error": ["forall", "a", ["arrow", ["tva"], "tva"]],

      "run-task": ["arrow", [["arrow", [], "Any"]], "Any"],
      "brander": "Any",
      "raise": ["arrow", ["Any"], "tbot"],
      "nothing": "Nothing",
      "builtins": ["record", {
        "trace-value": ["forall", ["a"], ["arrow", ["Any", "tva"], "tva"]],
        "has-field": ["arrow", [["record", {}], "String"], "Boolean"],
        "raw-array-from-list": ["forall", ["a"], ["arrow", [["List", "tva"]], ["RawArray", "tva"]]],
        "raw-array-join-str": ["forall", ["a"], ["arrow", [["RawArray", "tva"]], "String"]],
        "raw-array-sort-nums" : ["arrow", [["RawArray", "Number"], "Boolean"], ["RawArray", "Number"]],
        "raw-list-map": ["forall", ["a", "b"], ["arrow", [["arrow", ["tva"], "tvb"], ["List", "tva"]], ["List", "tvb"]]],
        "raw-list-filter": ["forall", ["a"], ["arrow", [["arrow", ["tva"], "Boolean"], ["List", "tva"]], ["List", "tva"]]],
        "raw-list-fold": ["forall", ["a", "b"], ["arrow", [["arrow", ["tvb", "tva"], "tvb"], "tvb", ["List", "tva"]], "tvb"]],
        "spy": ["arrow", ["Any", "String", ["RawArray", "Any"], ["RawArray", "String"], ["RawArray", "Any"]], "Nothing"],
        "current-checker": ["arrow", [], ["record", {
          "run-checks": "tbot",
          "check-is": "tbot",
          "check-is-not": "tbot",
          "check-is-refinement": "tbot",
          "check-is-not-refinement": "tbot",
          "check-satisfies": "tbot",
          "check-satisfies-not": "tbot",
          "check-raises-str": "tbot",
          "check-raises-not": "tbot",
          "check-raises-other-str": "tbot",
          "check-raises-satisfies": "tbot",
          "check-raises-violates":  "tbot"
        }]]
      }],

      "torepr": ["arrow", ["Any"], "String"],
      "to-repr": ["arrow", ["Any"], "String"],
      "tostring": ["arrow", ["Any"], "String"],
      "to-string": ["arrow", ["Any"], "String"],
      "not": ["arrow", ["Boolean"], "Boolean"],

      "isBoolean": "AnyPred",

      "is-boolean":{'bind': 'fun', 'flatness': 0, 'name': 'is-boolean', 'typ': 'AnyPred'},
      "is-function":{'bind': 'fun', 'flatness': 0, 'name': 'is-function', 'typ': 'AnyPred'},
      "is-nothing":{'bind': 'fun', 'flatness': 0, 'name': 'is-nothing', 'typ': 'AnyPred'},
      "is-number":{'bind': 'fun', 'flatness': 0, 'name': 'is-number', 'typ': 'AnyPred'},
      "is-object":{'bind': 'fun', 'flatness': 0, 'name': 'is-object', 'typ': 'AnyPred'},
      "is-raw-array":{'bind': 'fun', 'flatness': 0, 'name': 'is-raw-array', 'typ': 'AnyPred'},
      "is-string":{'bind': 'fun', 'flatness': 0, 'name': 'is-string', 'typ': 'AnyPred'},
      "is-table":{'bind': 'fun', 'flatness': 0, 'name': 'is-table', 'typ': 'AnyPred'},
      "is-row":{'bind': 'fun', 'flatness': 0, 'name': 'is-row', 'typ': 'AnyPred'},
      "is-tuple":{'bind': 'fun', 'flatness': 0, 'name': 'is-tuple', 'typ': 'AnyPred'},

      // Array functions
      "raw-array":           ["forall", ["a"], ["Maker", "tva", ["RawArray", "tva"]]],
      "raw-array-get": {'bind': 'fun',
                        'flatness': 0,
                        'name': 'raw-array-get',
                        'typ': ["forall", ["a"], ["arrow", [["RawArray", "tva"], "Number"], "tva"]]},
      "raw-array-sort-nums" : {'bind' : 'fun',
                        'flatness': 0,
                        'name': 'raw-array-sort-nums',
                        'typ': ["arrow", [["RawArray", "Number"], "Boolean"], ["RawArray", "Number"]]},
      "raw-array-set": {'bind': 'fun',
                        'flatness': 0,
                        'name': 'raw-array-set',
                        'typ': ["forall", ["a"], ["arrow", [["RawArray", "tva"], "Number", "tva"], 
                                                  ["RawArray", "tva"]]]},
      "raw-array-of": {'bind': 'fun',
                       'flatness': 0,
                       'name': 'raw-array-of',
                       'typ':["forall", ["a"], ["arrow", ["tva", "Number"], ["RawArray", "tva"]]]},
      "raw-array-build-opt": ["forall", ["a"], ["arrow", [["arrow", ["Number"], ["Option", "tva"]], "Number"],
                                                ["RawArray", "tva"]]],
      "raw-array-build":     ["forall", ["a"], ["arrow", [["arrow", ["Number"], "tva"], "Number"],
                                                ["RawArray", "tva"]]],

      "raw-array-length": {'bind': 'fun',
                           'flatness': 0,
                           'name': 'raw-array-length',
                           'typ':["forall", ["a"], ["arrow", [["RawArray", "tva"]], "Number"]]},
      "raw-array-join-str":  ["forall", ["a"], ["arrow", [["RawArray", "tva"]], "String"]],
      "raw-array-to-list": {'bind': 'fun',
                            'flatness': 0,
                            'name': 'raw-array-to-list',
                            'typ':["forall", ["a"], ["arrow", [["RawArray", "tva"]], ["List", "tva"]]]},
      "raw-array-from-list": {'bind': 'fun',
                              'flatness': 0,
                              'name': 'raw-array-from-list',
                              'typ':["forall", ["a"], ["arrow", [["List", "tva"]], ["RawArray", "tva"]]]},
      "raw-array-filter":    ["forall", ["a"], ["arrow", [["arrow", ["tva"], "Boolean"], ["RawArray", "tva"]], ["RawArray", "tva"]]],
      "raw-array-and-mapi":   ["forall", ["a"], ["arrow", [["arrow", ["tva", "Number"], "Boolean"], ["RawArray", "tva"]], "Boolean"]],
      "raw-array-or-mapi":    ["forall", ["a"], ["arrow", [["arrow", ["tva", "Number"], "Boolean"], ["RawArray", "tva"]], "Boolean"]],
      "raw-array-map":    ["forall", ["a", "b"], ["arrow", [["arrow", ["tva"], "tvb"], ["RawArray", "tva"]], ["RawArray", "tvb"]]],
      "raw-array-map-1":    ["forall", ["a", "b"], ["arrow", [["arrow", ["tva"], "tvb"], ["RawArray", ["RawArray", "tva"]]], ["RawArray", "tvb"]]],
      "raw-array-fold":      ["forall", ["a", "b"], ["arrow", [["arrow", ["tvb", "tva", "Number"], "tvb"], 
                                                               "tvb", ["RawArray", "tva"], "Number"], "tvb"]],

      // Equality functions

      "roughly-equal-always3": "EqualityPred",
      "roughly-equal-now3":    "EqualityPred",
      "equal-always3": "EqualityPred",
      "equal-now3":    "EqualityPred",
      "identical3":    "EqualityPred",
      "roughly-equal-always": "AnyPred2",
      "roughly-equal-now": "AnyPred2",
      "roughly-equal": "AnyPred2",
      "equal-always": "AnyPred2",
      "equal-now": "AnyPred2",
      "identical": "AnyPred2",
      "within": {'bind': 'fun',
           'flatness': 0,
           'name': 'within',
           'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-abs": {'bind': 'fun',
                 'flatness': 0,
                 'name': 'within-abs',
                     'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-rel": {'bind': 'fun',
                     'flatness': 0,
                     'name': 'within-rel',
                     'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-now": {'bind': 'fun',
                     'flatness': 0,
                     'name': 'within-now',
                     'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-abs-now": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-abs-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-rel-now": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within3": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-abs3": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-rel3": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-now3": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-abs-now3": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},
      "within-rel-now3": {'bind': 'fun',
                         'flatness': 0,
                         'name': 'within-rel-now',
                         'typ':["arrow", ["Number"], "AnyPred2"]},

      // Number functions

      "num-is-fixnum":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-fixnum', 'typ': 'NumPred'},
      "num-is-integer":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-integer', 'typ': 'NumPred'},
      "num-is-negative":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-negative', 'typ': 'NumPred'},
      "num-is-non-negative":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-non-negative', 'typ': 'NumPred'},
      "num-is-non-positive":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-non-positive', 'typ': 'NumPred'},
      "num-is-positive":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-positive', 'typ': 'NumPred'},
      "num-is-rational":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-rational', 'typ': 'NumPred'},
      "num-is-roughnum":{'bind': 'fun', 'flatness': 0, 'name': 'num-is-roughnum', 'typ': 'NumPred'},
      "string-to-number":{'bind': 'fun',
                          'flatness': 0,
                          'name': 'string-to-number',
                          'typ': ['arrow', ['String'], ['Option', 'Number']]},
      "string-tonumber":{'bind': 'fun',
                         'flatness': 0,
                         'name': 'string-tonumber',
                         'typ': ['arrow', ['String'], ['Option', 'Number']]},

      "num-equal":{'bind': 'fun', 'flatness': 0, 'name': 'num-equal', 'typ': 'NumPred2'},
      "num-max":{'bind': 'fun', 'flatness': 0, 'name': 'num-max', 'typ': 'NumBinop'},
      "num-min":{'bind': 'fun', 'flatness': 0, 'name': 'num-min', 'typ': 'NumBinop'},
      "num-within":{'bind': 'fun',
                    'flatness': 0,
                    'name': 'num-within',
                    'typ': ['arrow', ['Number'], 'NumPred2']},
      "num-within-abs":{'bind': 'fun',
                        'flatness': 0,
                        'name': 'num-within-abs',
                        'typ': ['arrow', ['Number'], 'NumPred2']},
      "num-within-rel":{'bind': 'fun',
                        'flatness': 0,
                        'name': 'num-within-rel',
                        'typ': ['arrow', ['Number'], 'NumPred2']},

      "num-abs":{'bind': 'fun', 'flatness': 0, 'name': 'num-abs', 'typ': 'NumUnop'},
      "num-acos":{'bind': 'fun', 'flatness': 0, 'name': 'num-acos', 'typ': 'NumUnop'},
      "num-asin":{'bind': 'fun', 'flatness': 0, 'name': 'num-asin', 'typ': 'NumUnop'},
      "num-atan":{'bind': 'fun', 'flatness': 0, 'name': 'num-atan', 'typ': 'NumUnop'},
      "num-atan2":{'bind': 'fun', 'flatness': 0, 'name': 'num-atan2', 'typ': 'NumBinop'},
      "num-cos":{'bind': 'fun', 'flatness': 0, 'name': 'num-cos', 'typ': 'NumUnop'},
      "num-sin":{'bind': 'fun', 'flatness': 0, 'name': 'num-sin', 'typ': 'NumUnop'},
      "num-tan":{'bind': 'fun', 'flatness': 0, 'name': 'num-tan', 'typ': 'NumUnop'},

      "num-modulo":{'bind': 'fun', 'flatness': 0, 'name': 'num-modulo', 'typ': 'NumBinop'},
      "num-remainder":{'bind': 'fun', 'flatness': 0, 'name': 'num-remainder', 'typ': 'NumBinop'},

      "num-ceiling":{'bind': 'fun', 'flatness': 0, 'name': 'num-ceiling', 'typ': 'NumUnop'},
      "num-exact":{'bind': 'fun', 'flatness': 0, 'name': 'num-exact', 'typ': 'NumUnop'},
      "num-exp":{'bind': 'fun', 'flatness': 0, 'name': 'num-exp', 'typ': 'NumUnop'},
      "num-floor":{'bind': 'fun', 'flatness': 0, 'name': 'num-floor', 'typ': 'NumUnop'},
      "num-log":{'bind': 'fun', 'flatness': 0, 'name': 'num-log', 'typ': 'NumUnop'},
      "num-round":{'bind': 'fun', 'flatness': 0, 'name': 'num-round', 'typ': 'NumUnop'},
      "num-round-even":{'bind': 'fun', 'flatness': 0, 'name': 'num-round-even', 'typ': 'NumUnop'},
      "num-sqr":{'bind': 'fun', 'flatness': 0, 'name': 'num-sqr', 'typ': 'NumUnop'},
      "num-sqrt":{'bind': 'fun', 'flatness': 0, 'name': 'num-sqrt', 'typ': 'NumUnop'},
      "num-to-fixnum":{'bind': 'fun', 'flatness': 0, 'name': 'num-to-fixnum', 'typ': 'NumUnop'},
      "num-to-rational":{'bind': 'fun', 'flatness': 0, 'name': 'num-to-rational', 'typ': 'NumUnop'},
      "num-to-roughnum":{'bind': 'fun', 'flatness': 0, 'name': 'num-to-roughnum', 'typ': 'NumUnop'},
      "num-truncate":{'bind': 'fun', 'flatness': 0, 'name': 'num-truncate', 'typ': 'NumUnop'},

      "num-expt":{'bind': 'fun', 'flatness': 0, 'name': 'num-expt', 'typ': 'NumBinop'},
      "num-to-string":{'bind': 'fun',
                       'flatness': 0,
                       'name': 'num-to-string',
                       'typ': ['arrow', ['Number'], 'String']},
      "num-to-string-digits":{'bind': 'fun',
                              'flatness': 0,
                              'name': 'num-to-string-digits',
                              'typ': ['arrow', ['Number', 'Number'], 'String']},
      "num-tostring":{'bind': 'fun',
                      'flatness': 0,
                      'name': 'num-tostring',
                      'typ': ['arrow', ['Number'], 'String']},

      "num-random":{'bind': 'fun', 'flatness': 0, 'name': 'num-random', 'typ': 'NumUnop'},
      "num-random-seed":{'bind': 'fun',
                         'flatness': 0,
                         'name': 'num-random-seed',
                         'typ': ['arrow', ['Number'], 'Nothing']},
      "random":{'bind': 'fun', 'flatness': 0, 'name': 'random', 'typ': 'NumUnop'},

      // Time functions

      "time-now":{'bind': 'fun',
                  'flatness': 0,
                  'name': 'time-now',
                  'typ': ['arrow', [], 'Number']},

      // String functions

      "gensym":{'bind': 'fun', 'flatness': 0, 'name': 'gensym', 'typ': ['arrow', ['String'], 'String']},
      "string-repeat":{'bind': 'fun',
                       'flatness': 0,
                       'name': 'string-repeat',
                       'typ': ['arrow', ['String', 'Number'], 'String']},
      "string-substring":{'bind': 'fun',
                          'flatness': 0,
                          'name': 'string-substring',
                          'typ': ['arrow', ['String', 'Number', 'Number'], 'String']},
      "string-to-lower":{'bind': 'fun', 'flatness': 0, 'name': 'string-to-lower', 'typ': 'StrUnop'},
      "string-to-upper":{'bind': 'fun', 'flatness': 0, 'name': 'string-to-upper', 'typ': 'StrUnop'},
      "string-tolower":{'bind': 'fun', 'flatness': 0, 'name': 'string-tolower', 'typ': 'StrUnop'},
      "string-toupper":{'bind': 'fun', 'flatness': 0, 'name': 'string-toupper', 'typ': 'StrUnop'},

      "string-append":{'bind': 'fun', 'flatness': 0, 'name': 'string-append', 'typ': 'StrBinop'},
      "string-char-at":{'bind': 'fun',
                        'flatness': 0,
                        'name': 'string-char-at',
                        'typ': ['arrow', ['String', 'Number'], 'String']},
      "string-contains":{'bind': 'fun', 'flatness': 0, 'name': 'string-contains', 'typ': 'StrPred2'},
      "string-starts-with":{'bind': 'fun', 'flatness': 0, 'name': 'string-contains', 'typ': 'StrPred2'},
      "string-ends-with":{'bind': 'fun', 'flatness': 0, 'name': 'string-contains', 'typ': 'StrPred2'},
      "string-equal":{'bind': 'fun', 'flatness': 0, 'name': 'string-equal', 'typ': 'StrPred2'},
      "string-explode":{'bind': 'fun',
                        'flatness': 0,
                        'name': 'string-explode',
                        'typ': ['arrow', ['String'], ['List', 'String']]},
      "string-from-code-point":{'bind': 'fun',
                                'flatness': 0,
                                'name': 'string-from-code-point',
                                'typ': ['arrow', ['Number'], 'String']},
      "string-from-code-points":{'bind': 'fun',
                                 'flatness': 0,
                                 'name': 'string-from-code-points',
                                 'typ': ['arrow', [['List', 'Number']], 'String']},
      "string-index-of":{'bind': 'fun',
                         'flatness': 0,
                         'name': 'string-index-of',
                         'typ': ['arrow', ['String', 'String'], 'Number']},
      "string-is-number":{'bind': 'fun', 'flatness': 0, 'name': 'string-is-number', 'typ': 'StrPred'},
      "string-isnumber":{'bind': 'fun', 'flatness': 0, 'name': 'string-isnumber', 'typ': 'StrPred'},
      "string-length":{'bind': 'fun',
                       'flatness': 0,
                       'name': 'string-length',
                       'typ': ['arrow', ['String'], 'Number']},
      "string-replace":{'bind': 'fun',
                        'flatness': 0,
                        'name': 'string-replace',
                        'typ': ['arrow', ['String', 'String', 'String'], 'String']},
      "string-split":{'bind': 'fun',
                      'flatness': 0,
                      'name': 'string-split',
                      'typ': ['arrow', ['String', 'String'], ['List', 'String']]},
      "string-split-all":{'bind': 'fun',
                          'flatness': 0,
                          'name': 'string-split-all',
                          'typ': ['arrow', ['String', 'String'], ['List', 'String']]},
      "string-to-code-point":{'bind': 'fun',
                              'flatness': 0,
                              'name': 'string-to-code-point',
                              'typ': ['arrow', ['String'], 'Number']},
      "string-to-code-points":{'bind': 'fun',
                               'flatness': 0,
                               'name': 'string-to-code-points',
                               'typ': ['arrow', ['String'], ['List', 'Number']]},
      "_plus":   {'bind': 'fun',
                  'flatness': false,
                  'name': '_plus',
                  'typ': ['arrow', ['Any', 'Any'], 'Any']},
      "_minus":  {'bind': 'fun',
                  'flatness': false,
                  'name': '_minus',
                  'typ': ['arrow', ['Any', 'Any'], 'Any']},
      "_times":  {'bind': 'fun',
                  'flatness': false,
                  'name': '_times',
                  'typ': ['arrow', ['Any', 'Any'], 'Any']},
      "_divide": {'bind': 'fun',
                  'flatness': false,
                  'name': '_divide',
                  'typ': ['arrow', ['Any', 'Any'], 'Any']},
      "_lessthan": {'bind': 'fun',
                  'flatness': false,
                  'name': '_lessthan',
                  'typ': ['arrow', ['Any', 'Any'], 'Boolean']},
      "_lessequal": {'bind': 'fun',
                  'flatness': false,
                  'name': '_lessequal',
                  'typ': ['arrow', ['Any', 'Any'], 'Boolean']},
      "_greaterthan": {'bind': 'fun',
                  'flatness': false,
                  'name': '_greaterthan',
                  'typ': ['arrow', ['Any', 'Any'], 'Boolean']},
      "_greaterequal": {'bind': 'fun',
                  'flatness': false,
                  'name': '_greaterequal',
                  'typ': ['arrow', ['Any', 'Any'], 'Boolean']},

      "ref-get": "Any",
      "ref-set": "Any",
      "ref-freeze": "Any",

      "exn-unwrap": "Any"

    },
    aliases: {
      "Any": "tany",
      "Method": "tany",
      "Object": "tany",
      "Function": "tany",
      "NumNonNegative": "Number",
      "NumNonPositive": "Number",
      "NumNegative": "Number",
      "NumPositive": "Number",
      "NumRational": "Number",
      "NumInteger": "Number",
      "Roughnum": "Number",
      "Exactnum": "Number",
      "Boolean": "Boolean",
      "Number": "Number",
      "String": "String",
      "Nothing": "Nothing",
      "RawArray": { tag: "name", 
                    origin: { "import-type": "uri", uri: "builtin://global" },
                    name: "RawArray" },
      "Row": { tag: "name", 
                    origin: { "import-type": "uri", uri: "builtin://global" },
                    name: "Row" },
      "Table": { tag: "name", 
                    origin: { "import-type": "uri", uri: "builtin://global" },
                    name: "Table" }
    },
    datatypes: {
      "Number": ["data", "Number", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "Exactnum": ["data", "Exactnum", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "Roughnum": ["data", "Roughnum", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "NumInteger": ["data", "NumInteger", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "NumRational": ["data", "NumRational", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "NumPositive": ["data", "NumPositive", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "NumNegative": ["data", "NumNegative", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "NumNonPositive": ["data", "NumNonPositive", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "NumNonNegative": ["data", "NumNonNegative", [], [], {
        "_plus": ["arrow", ["Number"], "Number"],
        "_times": ["arrow", ["Number"], "Number"],
        "_divide": ["arrow", ["Number"], "Number"],
        "_minus": ["arrow", ["Number"], "Number"],
        "_lessthan": ["arrow", ["Number"], "Boolean"],
        "_lessequal": ["arrow", ["Number"], "Boolean"],
        "_greaterthan": ["arrow", ["Number"], "Boolean"],
        "_greaterequal": ["arrow", ["Number"], "Boolean"]
      }],
      "String": ["data", "String", [], [], {
        "_plus": ["arrow", ["String"], "String"],
        "_lessthan": ["arrow", ["String"], "Boolean"],
        "_lessequal": ["arrow", ["String"], "Boolean"],
        "_greaterthan": ["arrow", ["String"], "Boolean"],
        "_greaterequal": ["arrow", ["String"], "Boolean"]
      }],
      "Table": ["data", "Table", [], [], {
        "length": ["arrow", [], "Number"]
      }],
      "Row": ["data", "Row", [], [], { }],
      "Function": ["data", "Function", [], [], {}],
      "Boolean": ["data", "Boolean", [], [], {}],
      "Object": ["data", "Object", [], [], {}],
      "Method": ["data", "Method", [], [], {}],
      "Nothing": ["data", "Nothing", [], [], {}],
      "RawArray": ["data", "RawArray", ["a"], [], {}]
    }
  },
  nativeRequires: [ ],
  theModule: function(runtime, namespace, uri /* intentionally blank */) {
    return runtime.globalModuleObject;
  }
})
