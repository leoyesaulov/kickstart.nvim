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
--           for extends/implements); d = default (interfaces only: md)
--   e.g. mts = protected static method, fpf = private final field, clsae = abstract class extends.
--
-- Snippets are context-aware (see `context`): each is listed only where it's valid, and member
-- snippets take the shape of their container. Statements (sout, fori, if, ...) only in method
-- bodies; members (m..., f..., ctor, get, ...) only in type bodies; types (cls..., intf, ...) at the
-- top level or nested in a type body. In an interface `m` is `void name();` (no body), `md`/`ms`/`mp`
-- have one, fields are constants and ctor/fgs are hidden; `ma` only in abstract classes and enums;
-- records get no instance fields or setters; enum constructors aren't public. When treesitter can't
-- tell where the cursor is, everything shows as in a plain class.
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

-- What kind of code the cursor is in, from treesitter: 'top' | 'class' | 'abstract' | 'enum' |
-- 'record' | 'interface' | 'annotation' | 'statement', or nil when the tree can't tell (no java
-- parser, or the code around the cursor doesn't parse).
local function class_body_kind(body)
  local decl = body:parent()
  local kind = decl and decl:type()
  if kind == 'record_declaration' then
    return 'record'
  elseif kind == 'class_declaration' then
    for child in decl:iter_children() do
      if child:type() == 'modifiers' and node_text(child):match '%f[%w_]abstract%f[^%w_]' then
        return 'abstract'
      end
    end
  end
  return 'class' -- also anonymous classes and enum-constant bodies
end

local container_kind = {
  block = 'statement', -- method bodies, lambdas, initializer blocks, switch cases
  constructor_body = 'statement',
  enum_body = 'enum',
  enum_body_declarations = 'enum',
  interface_body = 'interface',
  annotation_type_body = 'annotation',
}

-- Judged from the character just before the trigger word, so the half-typed trigger itself
-- (usually an ERROR node) doesn't matter. `start` = 0-based column where the trigger begins.
local function find_context(row, start)
  local ok, parser = pcall(vim.treesitter.get_parser, 0)
  if not (ok and parser) or parser:lang() ~= 'java' then
    return nil
  end
  pcall(function()
    parser:parse()
  end)
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ''
  local word_end = start + #line:sub(start + 1):match '^[%w_]*'
  local ok2, node = pcall(vim.treesitter.get_node, { pos = { row, math.max(start - 1, 0) } })
  if not ok2 then
    return nil
  end
  local broken = false
  while node do
    local sr, sc, er, ec = node:range()
    local kind = node:type()
    -- Skip the trigger word's own nodes (identifier, or an ERROR holding just it) at column 0.
    local own = sr == row and er == row and sc >= start and ec <= word_end
    if kind == 'class_body' then
      return class_body_kind(node)
    elseif container_kind[kind] then
      return container_kind[kind]
    elseif kind == 'program' then
      return not broken and 'top' or nil
    elseif kind == 'ERROR' and not own then
      broken = true
    end
    node = node:parent()
  end
end

-- blink asks every snippet's show_condition on each keystroke: parse once per buffer state.
local context_cache = {}

local function context(line_to_cursor)
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local start = #line_to_cursor:gsub('[%w_]*$', '')
  local key = table.concat({ buf, vim.api.nvim_buf_get_changedtick(buf), row, start }, ':')
  if context_cache.key ~= key then
    context_cache = { key = key, value = find_context(row, start) }
  end
  return context_cache.value
end

-- Condition: the cursor is in one of these contexts ('unknown' = treesitter couldn't tell).
local function when(...)
  local set = {}
  for _, name in ipairs { ... } do
    set[name] = true
  end
  return function(line_to_cursor)
    return set[context(line_to_cursor) or 'unknown'] == true
  end
end

local function both(a, b)
  return function(line_to_cursor)
    return a(line_to_cursor) and b(line_to_cursor)
  end
end

-- Where each group of snippets is listed. Unknown context behaves like a plain class body.
local in_statement = when('statement', 'unknown')
local in_type_body = when('class', 'abstract', 'enum', 'record', 'unknown') -- class-style members
local in_mutable_body = when('class', 'abstract', 'enum', 'unknown') -- instance fields, setters (not records)
local in_abstract_body = when('abstract', 'enum', 'unknown') -- abstract methods
local in_ctor_body = when('class', 'abstract', 'record', 'unknown') -- public constructors (not enums)
local in_enum = when 'enum'
local in_interface = when 'interface'
local in_annotation = when 'annotation'
local in_constant_body = when('interface', 'annotation') -- fields are implicit constants
local in_any_type_body = when('class', 'abstract', 'enum', 'record', 'interface', 'unknown') -- psvm, @Override
local in_type_position = when('top', 'class', 'abstract', 'enum', 'record', 'interface', 'unknown') -- (nested) types
local in_field_or_statement = when('statement', 'class', 'abstract', 'enum', 'record', 'unknown') -- al/hm/hs

-- `cond` (optional) decides both whether the snippet expands and whether blink lists it.
local function snip(trig, desc, body, cond)
  return s({ trig = trig, desc = desc, condition = cond, show_condition = cond }, body)
end

local getter = 'public <> get<>() {\n\treturn <>;\n}'
local setter = 'public void set<>(<> <>) {\n\tthis.<> = <>;\n}'

-- Every valid kind + access + mods combination (see the header): m, mt, mts, mta, fpf, ftsf, clsae, ...
-- One trigger can have a variant per container (class / interface / annotation); their
-- conditions never overlap, so at most one is listed.
local function decl_snippets()
  local out = {}
  local function add(trig, desc, template, nodes, cond)
    table.insert(out, snip(trig, desc, fmta(template, nodes), cond))
  end
  local function join(...)
    return vim.trim(table.concat({ ... }, ' '):gsub('%s+', ' '))
  end
  local function method_nodes(body)
    local nodes = { i(1, 'void'), i(2, 'name'), i(3) }
    if body then
      table.insert(nodes, i(0))
    end
    return nodes
  end

  for _, acc in ipairs { { '', 'public' }, { 'p', 'private' }, { 't', 'protected' } } do
    for _, mod in ipairs { { '', '' }, { 'a', 'abstract' }, { 's', 'static' }, { 'f', 'final' }, { 'sf', 'static final' } } do
      local trig, words = 'm' .. acc[1] .. mod[1], join(acc[2], mod[2])
      if mod[1] ~= 'a' then
        add(trig, words .. ' method', words .. ' <> <>(<>) {\n\t<>\n}', method_nodes(true), in_type_body)
      elseif acc[1] ~= 'p' then -- private abstract can't be overridden
        add(trig, words .. ' method', words .. ' <> <>(<>);', method_nodes(false), in_abstract_body)
      end
    end

    for _, mod in ipairs { { '', '' }, { 's', 'static' }, { 'f', 'final' }, { 'sf', 'static final' } } do
      local trig, words = 'f' .. acc[1] .. mod[1], join(acc[2], mod[2])
      local cond = mod[1]:find 's' and in_type_body or in_mutable_body -- records: static fields only
      if mod[1] == 'sf' then
        add(trig, words .. ' field', words .. ' <> <> = <>;', { i(1, 'Type'), i(2, 'NAME'), i(3) }, cond)
      else
        add(trig, words .. ' field', words .. ' <> <>;', { i(1, 'Type'), i(2, 'name') }, cond)
      end
    end
  end

  -- Interfaces: members are implicitly public, so the modifier is left out. Abstract methods
  -- have no body; static, private and default ones do. Fields are implicitly static final.
  for _, trig in ipairs { 'm', 'ma' } do
    add(trig, 'interface method (no body)', '<> <>(<>);', method_nodes(false), in_interface)
  end
  for _, mod in ipairs { { 's', 'static' }, { 'p', 'private' }, { 'ps', 'private static' }, { 'd', 'default' } } do
    add('m' .. mod[1], mod[2] .. ' interface method', mod[2] .. ' <> <>(<>) {\n\t<>\n}', method_nodes(true), in_interface)
  end
  -- Annotation elements take no parameters and can't be void.
  for _, trig in ipairs { 'm', 'ma' } do
    add(trig, 'annotation element', '<> <>();', { i(1, 'String'), i(2, 'name') }, in_annotation)
  end
  for _, trig in ipairs { 'f', 'fs', 'ff', 'fsf' } do
    add(trig, 'constant (implicitly public static final)', '<> <> = <>;', { i(1, 'Type'), i(2, 'NAME'), i(3) }, in_constant_body)
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
      local words = join('public', mod[2])
      add('cls' .. mod[1] .. ext[1], words .. ' class' .. ext[3], words .. ' class <>' .. ext[2] .. ' {\n\t<>\n}', nodes, in_type_position)
    end
  end
  return out
end

local snippets = {
  -- Print: so* = System.out, se* = System.err
  snip('sout', 'System.out.println', fmta('System.out.println(<>);', { i(1) }), in_statement),
  snip('souf', 'System.out.printf', fmta('System.out.printf("<>%n"<>);', { i(1), i(2) }), in_statement),
  snip('soutv', 'Print variable name and value', fmta('System.out.println("<> = " + <>);', { i(1, 'x'), rep(1) }), in_statement),
  snip('soutm', 'Print Class.method', fmta('System.out.println("<>.<>");', { f(classname), f(method_name) }), in_statement),
  snip('soutp', 'Print method parameters', fmta('System.out.println(<>);', { f(params_expr) }), in_statement),
  snip('serr', 'System.err.println', fmta('System.err.println(<>);', { i(1) }), in_statement),
  snip('serf', 'System.err.printf', fmta('System.err.printf("<>%n"<>);', { i(1), i(2) }), in_statement),

  -- Entry point
  snip('psvm', 'public static void main', fmta('public static void main(String[] args) {\n\t<>\n}', { i(0) }), in_any_type_body),
  snip('main', 'public static void main', fmta('public static void main(String[] args) {\n\t<>\n}', { i(0) }), in_any_type_body),

  -- Loops
  snip('fori', 'Indexed for loop', fmta('for (int <> = 0; <> << <>; <>++) {\n\t<>\n}', { i(1, 'i'), rep(1), i(2, 'n'), rep(1), i(0) }), in_statement),
  snip(
    'forr',
    'Reverse indexed for loop',
    fmta('for (int <> = <> - 1; <> >>= 0; <>--) {\n\t<>\n}', { i(1, 'i'), i(2, 'n'), rep(1), rep(1), i(0) }),
    in_statement
  ),
  snip('fore', 'Enhanced for-each loop', fmta('for (<> <> : <>) {\n\t<>\n}', { i(1, 'var'), i(2, 'item'), i(3, 'items'), i(0) }), in_statement),
  snip('wh', 'while loop', fmta('while (<>) {\n\t<>\n}', { i(1, 'true'), i(0) }), in_statement),
  snip('dowh', 'do-while loop', fmta('do {\n\t<>\n} while (<>);', { i(0), i(1, 'true') }), in_statement),

  -- Conditionals
  snip('if', 'if statement', fmta('if (<>) {\n\t<>\n}', { i(1), i(0) }), in_statement),
  snip('ife', 'if / else', fmta('if (<>) {\n\t<>\n} else {\n\t<>\n}', { i(1), i(2), i(0) }), in_statement),
  snip('ifn', 'if null', fmta('if (<> == null) {\n\t<>\n}', { i(1), i(0) }), in_statement),
  snip('ifnn', 'if not null', fmta('if (<> != null) {\n\t<>\n}', { i(1), i(0) }), in_statement),
  snip('elif', 'else if', fmta('else if (<>) {\n\t<>\n}', { i(1), i(0) }), in_statement),

  -- Switch
  snip('sw', 'switch statement (arrow form)', fmta('switch (<>) {\n\tcase <> ->> <>\n\tdefault ->> <>\n}', { i(1), i(2), i(3), i(0) }), in_statement),
  snip(
    'swe',
    'switch expression',
    fmta('var <> = switch (<>) {\n\tcase <> ->> <>;\n\tdefault ->> <>;\n};', { i(1, 'result'), i(2), i(3), i(4), i(0) }),
    in_statement
  ),

  -- Try
  snip('tryc', 'try / catch', fmta('try {\n\t<>\n} catch (<> e) {\n\t<>\n}', { i(1), i(2, 'Exception'), i(0) }), in_statement),
  snip('tryf', 'try / finally', fmta('try {\n\t<>\n} finally {\n\t<>\n}', { i(1), i(0) }), in_statement),
  snip(
    'trycf',
    'try / catch / finally',
    fmta('try {\n\t<>\n} catch (<> e) {\n\t<>\n} finally {\n\t<>\n}', { i(1), i(2, 'Exception'), i(3), i(0) }),
    in_statement
  ),
  snip('tryr', 'try-with-resources', fmta('try (<>) {\n\t<>\n}', { i(1), i(0) }), in_statement),

  -- Throw
  snip('thr', 'throw new Exception', fmta('throw new <>Exception(<>);', { i(1), i(2) }), in_statement),
  snip('thria', 'throw IllegalArgumentException', fmta('throw new IllegalArgumentException(<>);', { i(1) }), in_statement),
  snip('thris', 'throw IllegalStateException', fmta('throw new IllegalStateException(<>);', { i(1) }), in_statement),
  snip('thrus', 'throw UnsupportedOperation', fmta('throw new UnsupportedOperationException(<>);', { i(1) }), in_statement),

  -- Types (name from the file name); classes are generated, see decl_snippets
  snip('intf', 'public interface', fmta('public interface <> {\n\t<>\n}', { f(classname), i(0) }), in_type_position),
  snip('enm', 'public enum', fmta('public enum <> {\n\t<>\n}', { f(classname), i(0) }), in_type_position),
  snip('rec', 'public record', fmta('public record <>(<>) {\n\t<>\n}', { f(classname), i(1), i(0) }), in_type_position),

  -- Constructors (enum constructors can't be public)
  snip('ctor', 'No-arg constructor', fmta('public <>() {\n\t<>\n}', { f(classname), i(0) }), in_ctor_body),
  snip('ctor', 'No-arg enum constructor', fmta('<>() {\n\t<>\n}', { f(classname), i(0) }), in_enum),
  snip(
    'ctorp',
    'Constructor with one field',
    fmta('public <>(<> <>) {\n\tthis.<> = <>;<>\n}', { f(classname), i(1, 'Type'), i(2, 'name'), rep(2), rep(2), i(0) }),
    in_ctor_body
  ),
  snip(
    'ctorp',
    'Enum constructor with one field',
    fmta('<>(<> <>) {\n\tthis.<> = <>;<>\n}', { f(classname), i(1, 'Type'), i(2, 'name'), rep(2), rep(2), i(0) }),
    in_enum
  ),
  -- Fields the constructor doesn't take as parameters: `this.items = new ArrayList<>();`, `this.n = 0;`
  snip('fin', 'Initialise a field (new / default value)', { fin_body() }, in_ctor_with_fields),
  snip('fina', 'Initialise all remaining fields', { fina_body() }, in_ctor_with_fields),

  -- Accessors: type and name are typed once; getName/setName derive from the name.
  -- Records have no setters (fields are final); interfaces get the bodiless declarations.
  snip('get', 'Getter', fmta(getter, { i(1, 'Type'), cap(2), i(2, 'name') }), in_type_body),
  snip('get', 'Getter declaration', fmta('<> get<>();', { i(1, 'Type'), i(2, 'Name') }), in_interface),
  snip('is', 'Boolean getter', fmta('public boolean is<>() {\n\treturn <>;\n}', { cap(1), i(1, 'flag') }), in_type_body),
  snip('is', 'Boolean getter declaration', fmta('boolean is<>();', { i(1, 'Flag') }), in_interface),
  snip('set', 'Setter', fmta(setter, { cap(2), i(1, 'Type'), i(2, 'name'), rep(2), rep(2) }), in_mutable_body),
  snip('set', 'Setter declaration', fmta('void set<>(<> <>);', { cap(2), i(1, 'Type'), i(2, 'name') }), in_interface),
  snip(
    'gs',
    'Getter + setter',
    fmta(getter .. '\n\n' .. setter, { i(1, 'Type'), cap(2), i(2, 'name'), cap(2), rep(1), rep(2), rep(2), rep(2) }),
    in_mutable_body
  ),
  snip('gs', 'Getter + setter declarations', fmta('<> get<>();\n\nvoid set<>(<> <>);', { i(1, 'Type'), cap(2), cap(2), rep(1), i(2, 'name') }), in_interface),
  snip(
    'fgs',
    'Private field, getter, setter',
    fmta('private <> <>;\n\n' .. getter .. '\n\n' .. setter, { i(1, 'Type'), i(2, 'name'), rep(1), cap(2), rep(2), cap(2), rep(1), rep(2), rep(2), rep(2) }),
    in_mutable_body
  ),

  -- Collections: implementation initials (local variable or field)
  snip('al', 'List = new ArrayList', { t 'List<', i(1, 'String'), t '> ', i(2, 'list'), t ' = new ArrayList<>();' }, in_field_or_statement),
  snip('hm', 'Map = new HashMap', { t 'Map<', i(1, 'String'), t ', ', i(2, 'Integer'), t '> ', i(3, 'map'), t ' = new HashMap<>();' }, in_field_or_statement),
  snip('hs', 'Set = new HashSet', { t 'Set<', i(1, 'String'), t '> ', i(2, 'set'), t ' = new HashSet<>();' }, in_field_or_statement),

  -- Misc
  snip('ov', '@Override', t '@Override', in_any_type_body),
  snip('test', 'JUnit 5 test method', fmta('@Test\nvoid <>() {\n\t<>\n}', { i(1, 'name'), i(0) }), in_type_body),
  snip('test', 'JUnit 5 test method (interface)', fmta('@Test\ndefault void <>() {\n\t<>\n}', { i(1, 'name'), i(0) }), in_interface),
  snip('rnn', 'Objects.requireNonNull', fmta('Objects.requireNonNull(<>, "<>");', { i(1, 'x'), rep(1) }), in_statement),
  -- Statement position declares a variable; inside an argument list / after `=`, `return`, `->`
  -- only the bare `new Type(...)` expression is inserted (also in field initialisers).
  snip('new', 'new object', fmta('<> <> = new <>(<>);', { i(1, 'Object'), i(2, 'obj'), rep(1), i(3) }), both(not_expression, in_statement)),
  snip('new', 'new object (expression)', fmta('new <>(<>)', { i(1, 'Object'), i(2) }), in_expression),
  snip('scan', 'Scanner on System.in', t 'Scanner sc = new Scanner(System.in);', in_statement),
}

return vim.list_extend(snippets, decl_snippets())
