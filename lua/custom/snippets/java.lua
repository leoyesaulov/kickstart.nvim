-- Java snippets (LuaSnip, loaded by the from_lua loader in init.lua).
--
-- Naming scheme, in priority order:
--   1. Well-known IntelliJ abbreviations are kept as-is: sout, souf, soutv, psvm, fori, psf, ...
--   2. Otherwise: family prefix + variant letter (try -> tryc/tryf/tryr, if -> ife/ifn/ifnn, ...).
--   3. A suffix letter means the same thing in every family:
--      f = format/finally, r = reverse/resources, e = else/enhanced, n = null, nn = not null.
--
-- Field-aware generation (constructor from fields, getters/setters for existing fields,
-- toString, equals/hashCode) is jdtls's job: <leader>jg in a Java buffer.
--
-- Templates use fmta (`<>` placeholders) so Java braces need no escaping; the collection
-- snippets use plain nodes instead because generics would collide with `<>`.
local ls = require 'luasnip'
local s, t, i, f = ls.snippet, ls.text_node, ls.insert_node, ls.function_node
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

local function snip(trig, desc, body)
  return s({ trig = trig, desc = desc }, body)
end

local getter = 'public <> get<>() {\n\treturn <>;\n}'
local setter = 'public void set<>(<> <>) {\n\tthis.<> = <>;\n}'

return {
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
  snip('ife', 'if / else', fmta('if (<>) {\n\t<>\n} else {\n\t<>\n}', { i(1), i(2), i(0) })),
  snip('ifn', 'if null', fmta('if (<> == null) {\n\t<>\n}', { i(1), i(0) })),
  snip('ifnn', 'if not null', fmta('if (<> != null) {\n\t<>\n}', { i(1), i(0) })),
  snip('elif', 'else if', fmta('else if (<>) {\n\t<>\n}', { i(1), i(0) })),

  -- Switch
  snip('sw', 'switch statement (arrow form)', fmta('switch (<>) {\n\tcase <> ->> <>\n\tdefault ->> <>\n}', { i(1), i(2), i(3), i(0) })),
  snip(
    'swe',
    'switch expression',
    fmta('var <> = switch (<>) {\n\tcase <> ->> <>;\n\tdefault ->> <>;\n};', { i(1, 'result'), i(2), i(3), i(4), i(0) })
  ),

  -- Try
  snip('tryc', 'try / catch', fmta('try {\n\t<>\n} catch (<> e) {\n\t<>\n}', { i(1), i(2, 'Exception'), i(0) })),
  snip('tryf', 'try / finally', fmta('try {\n\t<>\n} finally {\n\t<>\n}', { i(1), i(0) })),
  snip(
    'trycf',
    'try / catch / finally',
    fmta('try {\n\t<>\n} catch (<> e) {\n\t<>\n} finally {\n\t<>\n}', { i(1), i(2, 'Exception'), i(3), i(0) })
  ),
  snip('tryr', 'try-with-resources', fmta('try (<>) {\n\t<>\n}', { i(1), i(0) })),

  -- Throw
  snip('thr', 'throw new Exception', fmta('throw new <>Exception(<>);', { i(1), i(2) })),
  snip('thria', 'throw IllegalArgumentException', fmta('throw new IllegalArgumentException(<>);', { i(1) })),
  snip('thris', 'throw IllegalStateException', fmta('throw new IllegalStateException(<>);', { i(1) })),
  snip('thrus', 'throw UnsupportedOperationException', fmta('throw new UnsupportedOperationException(<>);', { i(1) })),

  -- Types (name from the file name)
  snip('cls', 'public class', fmta('public class <> {\n\t<>\n}', { f(classname), i(0) })),
  snip('intf', 'public interface', fmta('public interface <> {\n\t<>\n}', { f(classname), i(0) })),
  snip('enm', 'public enum', fmta('public enum <> {\n\t<>\n}', { f(classname), i(0) })),
  snip('rec', 'public record', fmta('public record <>(<>) {\n\t<>\n}', { f(classname), i(1), i(0) })),

  -- Constructors
  snip('ctor', 'No-arg constructor', fmta('public <>() {\n\t<>\n}', { f(classname), i(0) })),
  snip(
    'ctorp',
    'Constructor with one field parameter',
    fmta('public <>(<> <>) {\n\tthis.<> = <>;<>\n}', { f(classname), i(1, 'Type'), i(2, 'name'), rep(2), rep(2), i(0) })
  ),

  -- Fields / constants
  snip('prv', 'private field', fmta('private <> <>;', { i(1, 'Type'), i(2, 'name') })),
  snip('prf', 'private final field', fmta('private final <> <>;', { i(1, 'Type'), i(2, 'name') })),
  snip('psf', 'public static final', fmta('public static final <> <> = <>;', { i(1, 'Type'), i(2, 'NAME'), i(3) })),
  snip('prsf', 'private static final', fmta('private static final <> <> = <>;', { i(1, 'Type'), i(2, 'NAME'), i(3) })),

  -- Accessors: type and name are typed once; getName/setName derive from the name
  snip('get', 'Getter', fmta(getter, { i(1, 'Type'), cap(2), i(2, 'name') })),
  snip('is', 'Boolean getter', fmta('public boolean is<>() {\n\treturn <>;\n}', { cap(1), i(1, 'flag') })),
  snip('set', 'Setter', fmta(setter, { cap(2), i(1, 'Type'), i(2, 'name'), rep(2), rep(2) })),
  snip('gs', 'Getter + setter', fmta(getter .. '\n\n' .. setter, { i(1, 'Type'), cap(2), i(2, 'name'), cap(2), rep(1), rep(2), rep(2), rep(2) })),
  snip(
    'fgs',
    'Private field + getter + setter',
    fmta('private <> <>;\n\n' .. getter .. '\n\n' .. setter, { i(1, 'Type'), i(2, 'name'), rep(1), cap(2), rep(2), cap(2), rep(1), rep(2), rep(2), rep(2) })
  ),

  -- Methods
  snip('m', 'public method', fmta('public <> <>(<>) {\n\t<>\n}', { i(1, 'void'), i(2, 'name'), i(3), i(0) })),
  snip('mp', 'private method', fmta('private <> <>(<>) {\n\t<>\n}', { i(1, 'void'), i(2, 'name'), i(3), i(0) })),
  snip('ms', 'public static method', fmta('public static <> <>(<>) {\n\t<>\n}', { i(1, 'void'), i(2, 'name'), i(3), i(0) })),

  -- Collections: implementation initials
  snip('al', 'List = new ArrayList', { t 'List<', i(1, 'String'), t '> ', i(2, 'list'), t ' = new ArrayList<>();' }),
  snip('hm', 'Map = new HashMap', { t 'Map<', i(1, 'String'), t ', ', i(2, 'Integer'), t '> ', i(3, 'map'), t ' = new HashMap<>();' }),
  snip('hs', 'Set = new HashSet', { t 'Set<', i(1, 'String'), t '> ', i(2, 'set'), t ' = new HashSet<>();' }),

  -- Misc
  snip('ov', '@Override', t '@Override'),
  snip('test', 'JUnit 5 test method', fmta('@Test\nvoid <>() {\n\t<>\n}', { i(1, 'name'), i(0) })),
  snip('rnn', 'Objects.requireNonNull', fmta('Objects.requireNonNull(<>, "<>");', { i(1, 'x'), rep(1) })),
  snip('scan', 'Scanner on System.in', t 'Scanner sc = new Scanner(System.in);'),
}
