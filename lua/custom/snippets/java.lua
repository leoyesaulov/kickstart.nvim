-- Java snippets (LuaSnip, loaded by the from_lua loader in init.lua).
--
-- Naming scheme, in priority order:
--   1. Well-known IntelliJ abbreviations are kept as-is: sout, souf, soutv, psvm, fori, ...
--   2. Otherwise: family prefix + variant letter (try -> tryc/tryf/tryr, if -> ife/ifn/ifnn, ...).
--   3. A suffix letter means the same thing in every family:
--      f = format/finally, r = reverse/resources, e = else/enhanced, n = null, nn = not null.
--
-- Declarations (methods, fields, classes) are generated, not hand-written (see decl_snippets):
--   trigger = kind + access + mods
--   kind:   m = method, f = field, cls = class
--   access: (none) = public, p = private, t = protected      (classes: public only)
--   mods:   a = abstract, s = static, f = final, in Java order (classes: a/f, then e/i/ei
--           for extends/implements)
--   e.g. mts = protected static method, fpf = private final field, clsae = abstract class extends.
--
-- jdtls's own code templates (sysout, ifelse, class, ...) are filtered out of blink in init.lua;
-- the snippets here replace them. Its postfix templates (list.for, x.nnull) stay.
--
-- Field-aware generation (constructor from fields, getters/setters for existing fields,
-- toString, equals/hashCode) is jdtls's job: <leader>jg in a Java buffer. The exception is
-- fin/fina, which initialise the fields a constructor doesn't take as parameters.
--
-- Templates use fmta (`<>` placeholders) so Java braces need no escaping; the collection
-- snippets use plain nodes instead because generics would collide with `<>`.
local ls = require 'luasnip'
local s, sn, t, i, f, d = ls.snippet, ls.snippet_node, ls.text_node, ls.insert_node, ls.function_node, ls.dynamic_node
local fmta = require('luasnip.extras.fmt').fmta
local rep = require('luasnip.extras').rep

local function classname()
  return vim.fn.expand '%:t:r'
end

-- Capitalized copy of insert node `idx` (name -> Name), for getName/setName.
local function cap(idx)
  return f(function(args)
    local name = args[1][1] or ''
    return name:sub(1, 1):upper() .. name:sub(2)
  end, { idx })
end

-- Innermost method/constructor declaration around the cursor, via treesitter.
local function enclosing_method()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok then
    return nil
  end
  while node do
    local type = node:type()
    if type == 'method_declaration' or type == 'constructor_declaration' then
      return node
    end
    node = node:parent()
  end
end

local function method_name()
  local method = enclosing_method()
  local name = method and method:field('name')[1]
  return name and vim.treesitter.get_node_text(name, 0) or 'method'
end

-- `"a = " + a + ", b = " + b` for the enclosing method's parameters.
local function params_expr()
  local method = enclosing_method()
  local params = method and method:field('parameters')[1]
  local parts = {}
  if params then
    for param in params:iter_children() do
      local name = param:type() == 'formal_parameter' and param:field('name')[1]
      if name then
        local text = vim.treesitter.get_node_text(name, 0)
        table.insert(parts, string.format('"%s%s = " + %s', #parts > 0 and ', ' or '', text, text))
      end
    end
  end
  return #parts > 0 and table.concat(parts, ' + ') or '""'
end

-- True when the cursor is where an expression goes (`foo(new`, `x = new`, `return new`, `() -> new`)
-- rather than at the start of a statement. Works on text, since the tree is broken mid-typing.
local function in_expression(line_to_cursor)
  local before = line_to_cursor:gsub('[%w_]*$', ''):gsub('%s+$', '')
  if before == '' then
    -- Continuation line, e.g. an argument list split over lines: judge by the previous line.
    local prev = vim.fn.prevnonblank(vim.api.nvim_win_get_cursor(0)[1] - 1)
    if prev == 0 then
      return false
    end
    before = vim.fn.getline(prev):gsub('%s+$', '')
  end
  for _, kw in ipairs { 'return', 'throw', 'yield' } do
    if before:match('%f[%w_]' .. kw .. '$') then
      return true
    end
  end
  if before:match '^%s*case%f[^%w_].*:$' or before:match '^%s*default%s*:$' then
    return false
  end
  return before:match '[(,=%[?:+%-*/%%&|!<>^~]$' ~= nil
end

local function not_expression(line_to_cursor)
  return not in_expression(line_to_cursor)
end

-- fin / fina: initialise the fields a constructor doesn't take as parameters.
-- Interface -> implementation for `new`; any other type is instantiated as written.
local impl_for = {
  List = 'ArrayList',
  Collection = 'ArrayList',
  Iterable = 'ArrayList',
  Set = 'HashSet',
  SortedSet = 'TreeSet',
  NavigableSet = 'TreeSet',
  Map = 'HashMap',
  SortedMap = 'TreeMap',
  NavigableMap = 'TreeMap',
  Queue = 'ArrayDeque',
  Deque = 'ArrayDeque',
}

-- Types with no useful `new`: primitives, String and the boxed types get a default value instead.
local default_for = {
  int = '0',
  short = '0',
  byte = '0',
  long = '0L',
  float = '0f',
  double = '0.0',
  boolean = 'false',
  char = "'\\0'",
  String = '""',
  Integer = '0',
  Short = '0',
  Byte = '0',
  Long = '0L',
  Float = '0f',
  Double = '0.0',
  Boolean = 'false',
  Character = "'\\0'",
}

local function node_text(node)
  return vim.treesitter.get_node_text(node, 0)
end

-- How to initialise a field of this declared type (text only, so it outlives the tree):
-- { value = '0' } | { array = 'int', dims = 1 } | { impl = 'ArrayList', diamond = true }.
local function init_spec(type_node)
  local kind = type_node:type()
  if kind == 'array_type' then
    local dims = type_node:field('dimensions')[1]
    return { array = node_text(type_node:field('element')[1]), dims = dims and select(2, node_text(dims):gsub('%[', '')) or 1 }
  end
  local base = kind == 'generic_type' and type_node:named_child(0) or type_node
  local name = node_text(base)
  local last = name:match '([%w_$]+)$' or name
  if kind ~= 'generic_type' and default_for[last] then
    return { value = default_for[last] }
  end
  return { impl = impl_for[last] or name, diamond = kind == 'generic_type' }
end

-- Nodes for the right-hand side of `this.name = ...`.
local function init_nodes(spec)
  if spec.value then
    return { i(1, spec.value) }
  elseif spec.array then
    return { t('new ' .. spec.array .. '['), i(1, '0'), t(']' .. ('[]'):rep(spec.dims - 1)) }
  end
  return { t 'new ', i(1, spec.impl), t(spec.diamond and '<>(' or '('), i(2), t ')' }
end

local function enclosing_constructor()
  pcall(function()
    vim.treesitter.get_parser(0):parse()
  end)
  local method = enclosing_method()
  return method and method:type() == 'constructor_declaration' and method or nil
end

-- Instance fields of the constructor's class, in declaration order, plus the subset the
-- constructor still has to initialise: no `= ...` initialiser, not a parameter, not assigned yet.
local function ctor_fields(ctor)
  local all, todo, skip = {}, {}, {}
  local params = ctor:field('parameters')[1]
  for param in params and params:iter_children() or function() end do
    local name = param:type() == 'formal_parameter' and param:field('name')[1]
    if name then
      skip[node_text(name)] = true
    end
  end
  local function walk(node)
    if node:type() == 'assignment_expression' then
      local left = node:field('left')[1]
      if left:type() == 'identifier' then
        skip[node_text(left)] = true
      elseif left:type() == 'field_access' and node_text(left:field('object')[1]) == 'this' then
        skip[node_text(left:field('field')[1])] = true
      end
    end
    for child in node:iter_children() do
      walk(child)
    end
  end
  local body = ctor:field('body')[1]
  if body then
    walk(body)
  end

  for decl in ctor:parent():iter_children() do
    if decl:type() == 'field_declaration' then
      local static = false
      for child in decl:iter_children() do
        if child:type() == 'modifiers' and node_text(child):match '%f[%w_]static%f[^%w_]' then
          static = true
        end
      end
      local type_node = decl:field('type')[1]
      if not static and type_node then
        local spec = init_spec(type_node)
        for _, var in ipairs(decl:field 'declarator') do
          local name = node_text(var:field('name')[1])
          all[name] = spec
          if not var:field('value')[1] and not skip[name] then
            table.insert(todo, { name = name, spec = spec })
          end
        end
      end
    end
  end
  return all, todo
end

local function uninitialised_fields()
  local ok, ctor = pcall(enclosing_constructor)
  if not (ok and ctor) then
    return nil
  end
  local ok2, all, todo = pcall(ctor_fields, ctor)
  if ok2 then
    return all, todo
  end
end

local function in_ctor_with_fields(line_to_cursor)
  if in_expression(line_to_cursor) then
    return false
  end
  local _, todo = uninitialised_fields()
  return todo ~= nil and #todo > 0
end

-- `this.<field> = <init>;` for the first uninitialised field. Retyping the name and jumping on
-- re-derives the right-hand side from that field's declared type.
local function fin_body()
  return d(1, function()
    local all, todo = uninitialised_fields()
    all, todo = all or {}, todo or {}
    return sn(nil, {
      t 'this.',
      i(1, todo[1] and todo[1].name or 'name'),
      t ' = ',
      d(2, function(args)
        return sn(nil, init_nodes(all[args[1][1]] or { impl = 'Object' }))
      end, { 1 }),
      t ';',
    })
  end)
end

-- One `this.<field> = <init>;` line per uninitialised field.
local function fina_body()
  return d(1, function()
    local _, todo = uninitialised_fields()
    local nodes = {}
    for idx, field in ipairs(todo or {}) do
      if idx > 1 then
        table.insert(nodes, t { '', '' })
      end
      table.insert(nodes, t('this.' .. field.name .. ' = '))
      table.insert(nodes, sn(idx, init_nodes(field.spec)))
      table.insert(nodes, t ';')
    end
    return sn(nil, nodes)
  end)
end

-- `cond` (optional) decides both whether the snippet expands and whether blink lists it.
local function snip(trig, desc, body, cond)
  return s({ trig = trig, desc = desc, condition = cond, show_condition = cond }, body)
end

local getter = 'public <> get<>() {\n\treturn <>;\n}'
local setter = 'public void set<>(<> <>) {\n\tthis.<> = <>;\n}'

-- Every valid kind + access + mods combination (see the header): m, mt, mts, mta, fpf, ftsf, clsae, ...
local function decl_snippets()
  local out = {}
  local function add(trig, words, what, template, nodes)
    table.insert(out, snip(trig, words .. ' ' .. what, fmta(words .. ' ' .. template, nodes)))
  end
  local function join(...)
    return vim.trim(table.concat({ ... }, ' '):gsub('%s+', ' '))
  end

  for _, acc in ipairs { { '', 'public' }, { 'p', 'private' }, { 't', 'protected' } } do
    for _, mod in ipairs { { '', '' }, { 'a', 'abstract' }, { 's', 'static' }, { 'f', 'final' }, { 'sf', 'static final' } } do
      if not (acc[1] == 'p' and mod[1] == 'a') then -- private abstract can't be overridden
        local words = join(acc[2], mod[2])
        if mod[1] == 'a' then
          add('m' .. acc[1] .. mod[1], words, 'method', '<> <>(<>);', { i(1, 'void'), i(2, 'name'), i(3) })
        else
          add('m' .. acc[1] .. mod[1], words, 'method', '<> <>(<>) {\n\t<>\n}', { i(1, 'void'), i(2, 'name'), i(3), i(0) })
        end
      end
    end

    for _, mod in ipairs { { '', '' }, { 's', 'static' }, { 'f', 'final' }, { 'sf', 'static final' } } do
      local words = join(acc[2], mod[2])
      if mod[1] == 'sf' then
        add('f' .. acc[1] .. mod[1], words, 'field', '<> <> = <>;', { i(1, 'Type'), i(2, 'NAME'), i(3) })
      else
        add('f' .. acc[1] .. mod[1], words, 'field', '<> <>;', { i(1, 'Type'), i(2, 'name') })
      end
    end
  end

  -- Type the parent/interface name and pick it from jdtls's completions (<c-y> adds the import);
  -- then <leader>ji stubs the abstract methods.
  for _, mod in ipairs { { '', '' }, { 'a', 'abstract' }, { 'f', 'final' } } do
    for _, ext in ipairs {
      { '', '', '', {} },
      { 'e', ' extends <>', ' extends', { 'Parent' } },
      { 'i', ' implements <>', ' implements', { 'Interface' } },
      { 'ei', ' extends <> implements <>', ' extends + implements', { 'Parent', 'Interface' } },
    } do
      local nodes = { f(classname) }
      for idx, placeholder in ipairs(ext[4]) do
        table.insert(nodes, i(idx, placeholder))
      end
      table.insert(nodes, i(0))
      add('cls' .. mod[1] .. ext[1], join('public', mod[2]), 'class' .. ext[3], 'class <>' .. ext[2] .. ' {\n\t<>\n}', nodes)
    end
  end
  return out
end

local snippets = {
  -- Print: so* = System.out, se* = System.err
  snip('sout', 'System.out.println', fmta('System.out.println(<>);', { i(1) })),
  snip('souf', 'System.out.printf', fmta('System.out.printf("<>%n"<>);', { i(1), i(2) })),
  snip('soutv', 'Print variable name and value', fmta('System.out.println("<> = " + <>);', { i(1, 'x'), rep(1) })),
  snip('soutm', 'Print Class.method', fmta('System.out.println("<>.<>");', { f(classname), f(method_name) })),
  snip('soutp', 'Print method parameters', fmta('System.out.println(<>);', { f(params_expr) })),
  snip('serr', 'System.err.println', fmta('System.err.println(<>);', { i(1) })),
  snip('serf', 'System.err.printf', fmta('System.err.printf("<>%n"<>);', { i(1), i(2) })),

  -- Entry point
  snip('psvm', 'public static void main', fmta('public static void main(String[] args) {\n\t<>\n}', { i(0) })),
  snip('main', 'public static void main', fmta('public static void main(String[] args) {\n\t<>\n}', { i(0) })),

  -- Loops
  snip('fori', 'Indexed for loop', fmta('for (int <> = 0; <> << <>; <>++) {\n\t<>\n}', { i(1, 'i'), rep(1), i(2, 'n'), rep(1), i(0) })),
  snip('forr', 'Reverse indexed for loop', fmta('for (int <> = <> - 1; <> >>= 0; <>--) {\n\t<>\n}', { i(1, 'i'), i(2, 'n'), rep(1), rep(1), i(0) })),
  snip('fore', 'Enhanced for-each loop', fmta('for (<> <> : <>) {\n\t<>\n}', { i(1, 'var'), i(2, 'item'), i(3, 'items'), i(0) })),
  snip('wh', 'while loop', fmta('while (<>) {\n\t<>\n}', { i(1, 'true'), i(0) })),
  snip('dowh', 'do-while loop', fmta('do {\n\t<>\n} while (<>);', { i(0), i(1, 'true') })),

  -- Conditionals
  snip('if', 'if statement', fmta('if (<>) {\n\t<>\n}', { i(1), i(0) })),
  snip('ife', 'if / else', fmta('if (<>) {\n\t<>\n} else {\n\t<>\n}', { i(1), i(2), i(0) })),
  snip('ifn', 'if null', fmta('if (<> == null) {\n\t<>\n}', { i(1), i(0) })),
  snip('ifnn', 'if not null', fmta('if (<> != null) {\n\t<>\n}', { i(1), i(0) })),
  snip('elif', 'else if', fmta('else if (<>) {\n\t<>\n}', { i(1), i(0) })),

  -- Switch
  snip('sw', 'switch statement (arrow form)', fmta('switch (<>) {\n\tcase <> ->> <>\n\tdefault ->> <>\n}', { i(1), i(2), i(3), i(0) })),
  snip('swe', 'switch expression', fmta('var <> = switch (<>) {\n\tcase <> ->> <>;\n\tdefault ->> <>;\n};', { i(1, 'result'), i(2), i(3), i(4), i(0) })),

  -- Try
  snip('tryc', 'try / catch', fmta('try {\n\t<>\n} catch (<> e) {\n\t<>\n}', { i(1), i(2, 'Exception'), i(0) })),
  snip('tryf', 'try / finally', fmta('try {\n\t<>\n} finally {\n\t<>\n}', { i(1), i(0) })),
  snip('trycf', 'try / catch / finally', fmta('try {\n\t<>\n} catch (<> e) {\n\t<>\n} finally {\n\t<>\n}', { i(1), i(2, 'Exception'), i(3), i(0) })),
  snip('tryr', 'try-with-resources', fmta('try (<>) {\n\t<>\n}', { i(1), i(0) })),

  -- Throw
  snip('thr', 'throw new Exception', fmta('throw new <>Exception(<>);', { i(1), i(2) })),
  snip('thria', 'throw IllegalArgumentException', fmta('throw new IllegalArgumentException(<>);', { i(1) })),
  snip('thris', 'throw IllegalStateException', fmta('throw new IllegalStateException(<>);', { i(1) })),
  snip('thrus', 'throw UnsupportedOperation', fmta('throw new UnsupportedOperationException(<>);', { i(1) })),

  -- Types (name from the file name); classes are generated, see decl_snippets
  snip('intf', 'public interface', fmta('public interface <> {\n\t<>\n}', { f(classname), i(0) })),
  snip('enm', 'public enum', fmta('public enum <> {\n\t<>\n}', { f(classname), i(0) })),
  snip('rec', 'public record', fmta('public record <>(<>) {\n\t<>\n}', { f(classname), i(1), i(0) })),

  -- Constructors
  snip('ctor', 'No-arg constructor', fmta('public <>() {\n\t<>\n}', { f(classname), i(0) })),
  snip(
    'ctorp',
    'Constructor with one field',
    fmta('public <>(<> <>) {\n\tthis.<> = <>;<>\n}', { f(classname), i(1, 'Type'), i(2, 'name'), rep(2), rep(2), i(0) })
  ),
  -- Fields the constructor doesn't take as parameters: `this.items = new ArrayList<>();`, `this.n = 0;`
  snip('fin', 'Initialise a field (new / default value)', { fin_body() }, in_ctor_with_fields),
  snip('fina', 'Initialise all remaining fields', { fina_body() }, in_ctor_with_fields),

  -- Accessors: type and name are typed once; getName/setName derive from the name
  snip('get', 'Getter', fmta(getter, { i(1, 'Type'), cap(2), i(2, 'name') })),
  snip('is', 'Boolean getter', fmta('public boolean is<>() {\n\treturn <>;\n}', { cap(1), i(1, 'flag') })),
  snip('set', 'Setter', fmta(setter, { cap(2), i(1, 'Type'), i(2, 'name'), rep(2), rep(2) })),
  snip('gs', 'Getter + setter', fmta(getter .. '\n\n' .. setter, { i(1, 'Type'), cap(2), i(2, 'name'), cap(2), rep(1), rep(2), rep(2), rep(2) })),
  snip(
    'fgs',
    'Private field, getter, setter',
    fmta('private <> <>;\n\n' .. getter .. '\n\n' .. setter, { i(1, 'Type'), i(2, 'name'), rep(1), cap(2), rep(2), cap(2), rep(1), rep(2), rep(2), rep(2) })
  ),

  -- Collections: implementation initials
  snip('al', 'List = new ArrayList', { t 'List<', i(1, 'String'), t '> ', i(2, 'list'), t ' = new ArrayList<>();' }),
  snip('hm', 'Map = new HashMap', { t 'Map<', i(1, 'String'), t ', ', i(2, 'Integer'), t '> ', i(3, 'map'), t ' = new HashMap<>();' }),
  snip('hs', 'Set = new HashSet', { t 'Set<', i(1, 'String'), t '> ', i(2, 'set'), t ' = new HashSet<>();' }),

  -- Misc
  snip('ov', '@Override', t '@Override'),
  snip('test', 'JUnit 5 test method', fmta('@Test\nvoid <>() {\n\t<>\n}', { i(1, 'name'), i(0) })),
  snip('rnn', 'Objects.requireNonNull', fmta('Objects.requireNonNull(<>, "<>");', { i(1, 'x'), rep(1) })),
  -- Statement position declares a variable; inside an argument list / after `=`, `return`, `->`
  -- only the bare `new Type(...)` expression is inserted.
  snip('new', 'new object', fmta('<> <> = new <>(<>);', { i(1, 'Object'), i(2, 'obj'), rep(1), i(3) }), not_expression),
  snip('new', 'new object (expression)', fmta('new <>(<>)', { i(1, 'Object'), i(2) }), in_expression),
  snip('scan', 'Scanner on System.in', t 'Scanner sc = new Scanner(System.in);'),
}

return vim.list_extend(snippets, decl_snippets())
